IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_ProcessOrganisationsToRetrieveObligationDecision]'))
    DROP PROCEDURE [dbo].[sp_ProcessOrganisationsToRetrieveObligationDecision];
GO

CREATE PROC dbo.sp_ProcessOrganisationsToRetrieveObligationDecision 
(
    @DpOrgIds   NVARCHAR(MAX),
    @SubOrgIds  NVARCHAR(MAX) 
)
AS
BEGIN
    SET NOCOUNT ON;    
    
    IF OBJECT_ID('tempdb..#DpOrganisationIdTable') IS NOT NULL
        DROP TABLE #DpOrganisationIdTable;
    IF OBJECT_ID('tempdb..#SubOrganisationIdTable') IS NOT NULL
        DROP TABLE #SubOrganisationIdTable;
    IF OBJECT_ID('tempdb..#LatestRegistrations') IS NOT NULL
        DROP TABLE #LatestRegistrations;
    IF OBJECT_ID('tempdb..#OrganisationsObligation') IS NOT NULL
        DROP TABLE #OrganisationsObligation;
    IF OBJECT_ID('tempdb..#OrganisationsObligationAfterDecision') IS NOT NULL
        DROP TABLE #OrganisationsObligationAfterDecision;
    IF OBJECT_ID('tempdb..#OrganisationsObligationAfterInheritance') IS NOT NULL
        DROP TABLE #OrganisationsObligationAfterInheritance; 

    /* ============================================================
        STEP 1: INSERT INPUT LIST ID's INTO TEMP TABLE's
    ============================================================ */
    DECLARE @Delimiter CHAR(1) = ',';

    SELECT TRY_CAST(value AS NVARCHAR) AS OrganisationId INTO #DpOrganisationIdTable FROM STRING_SPLIT(@DpOrgIds, @Delimiter)
    SELECT TRY_CAST(value AS NVARCHAR) AS OrganisationId INTO #SubOrganisationIdTable FROM STRING_SPLIT(@SubOrgIds, @Delimiter)

    /* ============================================================
        STEP 2: TAKE ALL LATEST REGISTRATIONS FOR DPs AND SUBs
        -- Build latest registration records (direct + sub)
        -- to capture most recent Accepted/Granted decisions
        -- for both DirectRegistrant and Subsidiary orgs
    ============================================================ */
    SELECT  OrganisationId, SubmitterId, LeaverCode, OrganisationType, ParentOrganisationId, DecisionDate
    INTO    #LatestRegistrations
    FROM    (SELECT  CAST(CASE WHEN CD.subsidiary_id IS NULL THEN CAST(CD.organisation_id AS NVARCHAR(50)) ELSE CD.subsidiary_id END AS NVARCHAR(50)) AS OrganisationId,
                    COALESCE(CFM.ComplianceSchemeId, O.ExternalId) AS SubmitterId,
                    CD.leaver_code AS LeaverCode,
                    CASE WHEN CD.subsidiary_id IS NULL THEN 'DirectRegistrant' ELSE 'Subsidiary' END AS OrganisationType,
                    CASE WHEN CD.subsidiary_id IS NULL THEN NULL ELSE CAST(CD.organisation_id AS NVARCHAR(50)) END AS ParentOrganisationId,
                    SE.Created AS DecisionDate,
                    ----------------------------------------------------------------
                    -- rn: Rank rows per Organisation + Submitter by newest decision
                    ----------------------------------------------------------------
                    ROW_NUMBER() OVER (PARTITION BY CASE WHEN CD.subsidiary_id IS NULL THEN CAST(CD.organisation_id AS NVARCHAR(50)) ELSE CD.subsidiary_id END,
                                                        COALESCE(CFM.ComplianceSchemeId, O.ExternalId) ORDER BY SE.Created DESC ) AS rn
             FROM    rpd.CompanyDetails CD
                    INNER JOIN rpd.cosmos_file_metadata CFM ON CFM.FileName = CD.FileName
                    INNER JOIN rpd.SubmissionEvents SE ON SE.FileId = CFM.FileId
                    INNER JOIN rpd.Organisations O ON O.ReferenceNumber = CD.organisation_id
             WHERE
                    ((CD.subsidiary_id IS NULL AND EXISTS (SELECT 1 FROM #DpOrganisationIdTable DpID WHERE DpID.OrganisationId = CD.organisation_id))
                    OR
                    (CD.subsidiary_id IS NOT NULL AND EXISTS (SELECT 1 FROM #SubOrganisationIdTable SubID WHERE SubID.OrganisationId = CD.subsidiary_id)))
                    AND CD.organisation_size = 'L'
                    AND SE.Decision IN ('Accepted', 'Granted')
                    AND CFM.FileTYpe = 'CompanyDetails'
                    AND CFM.SubmissionPeriod LIKE '%2024'
                    --AND CFM.SubmissionPeriod LIKE '%' + CAST(YEAR(GETDATE()) AS VARCHAR(4))
                ) AS CombinedRegistrations
    WHERE   rn = 1;

    /* ============================================================
        STEP 3: JOIN WITH OBLIGATION FLAG
    ============================================================ */
    SELECT  LR.*,
            CASE WHEN LR.LeaverCode IS NULL THEN NULL
                 WHEN LR.LeaverCode NOT IN (SELECT DISTINCT Code FROM [rpd].CodeStatusConfigs) THEN -1 -- Invalid
                 ELSE vOCI.IsObligated
            END AS IsObligated
    INTO    #OrganisationsObligation
    FROM    #LatestRegistrations AS LR
            LEFT JOIN [dbo].[v_ObligationCalculations_IsObligated] vOCI ON vOCI.Code = LR.LeaverCode;

    /* ============================================================
        STEP 4: SUMMARISE ISOBLIGATED COUNTS BY ORGANISATIONID
    ============================================================ */
    WITH ObligationFlagSummary AS (
        SELECT  OrganisationId,
                COUNT(*) AS TotalCount,
                SUM(CASE WHEN IsObligated = 1 THEN 1 ELSE 0 END) AS ObligatedCount,
                SUM(CASE WHEN IsObligated = 0 THEN 1 ELSE 0 END) AS NotObligatedCount,
                SUM(CASE WHEN IsObligated = -1 THEN 1 ELSE 0 END) AS InvalidCount,
                SUM(CASE WHEN IsObligated IS NULL THEN 1 ELSE 0 END) AS NullCount
        FROM    #OrganisationsObligation
        GROUP BY OrganisationId
    )

    /* ============================================================
        STEP 5: ADD ISOBLIGATED DECISION COLUMN
    ============================================================ */
    -- Add IsObligatedAfterDecision column by checking IsObligated count based on organisation id
    -- 1  = Obligated
    -- 0  = Not Obligated
    -- -1 = Invalid Leaver Code
    -- -2 = Cannot Determine Error
    SELECT  OO.OrganisationId,
            OO.SubmitterId,
            OO.LeaverCode,
            OO.OrganisationType,
            OO.ParentOrganisationId,
            OO.IsObligated,
            CASE    -- Explicit invalid flag on record itself
                    WHEN OO.IsObligated = -1 THEN -1
                    -- Org has multiple records, and *all* records are invalid then conclude all error
                    WHEN OFS.TotalCount > 1 AND OFS.InvalidCount = OFS.TotalCount THEN -1
                    -- Org has multiple records, and *all* records NULL then conclude all error
                    WHEN OFS.TotalCount > 1 AND OFS.NullCount = OFS.TotalCount THEN -2
                    -- Org has multiple records, and *multiple* 'Obligated' flags then conclude all cannot detemine
                    WHEN OFS.TotalCount > 1 AND OFS.ObligatedCount > 1 THEN -2
                    -- Org has multiple records, exactly one 'Obligated' then mark only that as obligated
                    WHEN OFS.TotalCount > 1 AND OFS.ObligatedCount = 1 THEN CASE WHEN OO.IsObligated = 1 THEN 1 ELSE 0  END
                    -- Org has multiple records, multiple 'Not Obligated' + exactly 1 NULL then mark the NULL is actually the 'Obligated' one
                    WHEN OFS.TotalCount > 1 AND OFS.NotObligatedCount > 1 AND OFS.NullCount = 1 THEN CASE WHEN OO.IsObligated IS NULL THEN 1 ELSE 0 END
                    -- Org has multiple records, exactly 1 'Not Obligated' and more than one NULL then treat NULLs as error
                    WHEN OFS.TotalCount > 1 AND OFS.NotObligatedCount = 1 AND OFS.NullCount > 1 THEN -2
                    -- Org has only one record then treat as 'Obligated' if true or NULL else Not Obligated
                    WHEN OFS.TotalCount = 1 THEN CASE WHEN OO.IsObligated = 1 OR OO.IsObligated IS NULL THEN 1 ELSE 0 END
                    ELSE 0 END AS IsObligatedAfterDecision,
            CASE    WHEN (OO.IsObligated = -1 OR (OFS.TotalCount > 1 AND OFS.InvalidCount = OFS.TotalCount)) THEN 'Invalid Leaver Code'
                    WHEN ((OFS.TotalCount > 1 AND OFS.NullCount = OFS.TotalCount) 
                            OR (OFS.TotalCount > 1 AND OFS.ObligatedCount > 1) 
                            OR (OFS.TotalCount > 1 AND OFS.NotObligatedCount = 1 AND OFS.NullCount > 1)) 
                            THEN 'Cannot Determine | Error'
                    WHEN ((OFS.TotalCount > 1 AND OFS.ObligatedCount = 1 AND OO.IsObligated = 1)
                            OR (OFS.TotalCount > 1 AND OFS.NotObligatedCount > 1 AND OFS.NullCount = 1 AND OO.IsObligated IS NULL)
                            OR (OFS.TotalCount = 1 AND (OO.IsObligated = 1 OR OO.IsObligated IS NULL))) 
                            THEN 'Obligated'
                    ELSE 'Not Obligated' END AS IsObligatedAfterDecisionDescription
    INTO    #OrganisationsObligationAfterDecision
    FROM    #OrganisationsObligation OO
            INNER JOIN ObligationFlagSummary OFS ON OO.OrganisationId = OFS.OrganisationId;

    /* ===================================================================================
        STEP 6: INHERIT PARENT DP DECISION TO SUBSIDIARY WHEN DP DECISION IS 0, -1, -2
    =================================================================================== */
    -- Create a new temp table with extra columns
    SELECT  *,
            CAST(IsObligatedAfterDecision AS INT) AS IsObligatedAfterInheritance,
            CAST(IsObligatedAfterDecisionDescription AS NVARCHAR(500)) AS IsObligatedAfterInheritanceDescription
    INTO    #OrganisationsObligationAfterInheritance
    FROM    #OrganisationsObligationAfterDecision;

    -- Update sub-orgs (Subsidiary) with parent DirectRegistrant decision
    UPDATE  OOAI
    SET     OOAI.IsObligatedAfterInheritance = COALESCE(P.DpDecision, OOAI.IsObligatedAfterInheritance),
            OOAI.IsObligatedAfterInheritanceDescription = COALESCE(P.DpDescription + ' - Inherited from parent', OOAI.IsObligatedAfterInheritanceDescription)
    FROM    #OrganisationsObligationAfterInheritance OOAI
            LEFT JOIN ( -- Filter parent DirectRegistrant orgs with Decision <> 1
                        SELECT  OrganisationId AS DpOrganisationId,
                                SubmitterId AS DpSubmitterId,
                                IsObligatedAfterDecision AS DpDecision,
                                IsObligatedAfterDecisionDescription AS DpDescription
                        FROM    #OrganisationsObligationAfterDecision
                        WHERE   OrganisationType = 'DirectRegistrant'
                                AND IsObligatedAfterDecision IN (0, -1, -2)
                    ) P ON OOAI.ParentOrganisationId = P.DpOrganisationId AND OOAI.SubmitterId = P.DpSubmitterId
    WHERE   OOAI.OrganisationType = 'Subsidiary'
            AND OOAI.IsObligatedAfterInheritance <> P.DpDecision;

    /* ===================================================================================
        STEP 7: FINAL OUTPUT
    =================================================================================== */
    SELECT  OrganisationId,
            OrganisationType,
            SubmitterId,
            ParentOrganisationId,
            LeaverCode,
            IsObligatedAfterInheritance AS IsObligated,
            IsObligatedAfterInheritanceDescription AS IsObligatedDescription
    FROM #OrganisationsObligationAfterInheritance
    ORDER BY OrganisationType, OrganisationId, SubmitterId;
END;
GO