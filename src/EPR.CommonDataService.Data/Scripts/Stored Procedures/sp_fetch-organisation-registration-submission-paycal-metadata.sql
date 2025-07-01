IF EXISTS (SELECT 1 FROM SYS.PROCEDURES WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata]'))
    DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata] 
	@BeforeProducerSubmits [BIT], 
	@SubmissionId [NVARCHAR](50), 
	@FileId [NVARCHAR](50) 
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @targetFileId NVARCHAR(50);
    DECLARE @targetSubmissionId NVARCHAR(50);

    DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
    DECLARE @SubmissionPeriod NVARCHAR(100);
    DECLARE @CSOReferenceNumber NVARCHAR(100);
    DECLARE @ComplianceSchemeId NVARCHAR(50);
    DECLARE @IsComplianceScheme BIT;

    DECLARE @FirstSubmittedOn DATETIME2(7);
    DECLARE @SubmittedOn DATETIME2(7);
    DECLARE @CancelledOn DATETIME2(7);
    DECLARE @RegistrationDecisionDate DATETIME2(7);

    IF OBJECT_ID('tempdb..#PaycalParams') IS NOT NULL
    DROP TABLE #PaycalParams;

    CREATE TABLE #PaycalParams
    (
        SubmissionId NVARCHAR(50),
        IsCSO BIT,
        CSOReference NVARCHAR(50),
        CSOExternalId UNIQUEIDENTIFIER,
        ComplianceSchemeId UNIQUEIDENTIFIER,
        SubmissionPeriod NVARCHAR(50),
        ReferenceNumber INT,
        ExternalId NVARCHAR(50),
        OrganisationName NVARCHAR(250),
        IsOriginal BIT,
        IsNewJoiner BIT,
        RelevantYear INT,
        SubmittedDate DATETIME2(7),
        EarliestSubmissionDate DATETIME2(7),
        OrganisationSize CHAR,
        LeaverCode NVARCHAR(20),
        LeaverDate NVARCHAR(20),
        JoinerDate NVARCHAR(20),
        OrganisationChangeReason NVARCHAR(20),
        IsOnlineMarketPlace BIT,
        NumberOfSubsidiaries INT,
        NumberOfSubsidiariesBeingOnlineMarketPlace INT,    
        FileName UNIQUEIDENTIFIER,
        FileId UNIQUEIDENTIFIER
    );

    IF (@FileId IS NOT NULL AND @SubmissionId IS NULL)
    BEGIN
        SET @targetFileId  = @FileId;
        SELECT @targetSubmissionId = se.SubmissionId
        FROM rpd.SubmissionEvents se
        WHERE se.FileId = @FileId 
        AND se.Type = 'Submitted'
    END

    IF (@SubmissionId IS NOT NULL)
    BEGIN
        SET @targetSubmissionId = @SubmissionId;
    END
    if @SubmissionId IS NULL AND @FileId IS NULL
    BEGIN
        SELECT * FROM #PaycalParams
        WHERE 1 = 0;
    END
    ELSE
    BEGIN
        -- For the given submission id, get the metadata of the submission and the FileId
        -- for that submission
        -- there is either a file that has no RegistrationApplicationSubmitted event
        -- or ones that do have that event
        -- For Producers - they need a FileId that is not yet Submitted, so the paycal metadata
        -- can be extracted for that file
        -- and for regulators - it is required that they see ONLY those files that have a RegistrationApplicationSubmitted event
        -- this block extracts the targetFileId according to this logic

        SELECT TOP 1 @targetFileId = upload.FileId,
                    @SubmittedOn = COALESCE(
                        (
                            SELECT MAX(submitted.Created)
                            FROM rpd.SubmissionEvents submitted
                            WHERE submitted.SubmissionId = upload.SubmissionId
                            AND submitted.Type = 'RegistrationApplicationSubmitted'
                            AND submitted.Created > upload.Created
                        ),
                        upload.Created
                    )
                    ,@FirstSubmittedOn = COALESCE(
                        (
                            SELECT MIN(submitted.Created)
                            FROM rpd.SubmissionEvents submitted
                            WHERE submitted.SubmissionId = upload.SubmissionId
                            AND submitted.Type = 'RegistrationApplicationSubmitted'
                            AND submitted.Created > upload.Created
                        ),
                        upload.Created
                    )
                    ,@RegistrationDecisionDate = (
                        SELECT MAX(sub.Created)
                        FROM rpd.SubmissionEvents sub
                        WHERE sub.SubmissionId = upload.SubmissionId
                            AND sub.Type = 'RegulatorRegistrationDecision'
                            AND ISNULL(sub.IsResubmission,0) = 0
                            AND sub.Decision = 'Accepted'
                            AND sub.RegistrationReferenceNumber IS NOT NULL
                    )
                    ,@CancelledOn = (
                        SELECT Min(sub.Created)
                        from rpd.SubmissionEvents sub
                        WHERE sub.SubmissionId = upload.SubmissionId
                            AND sub.Type = 'RegulatorRegistrationDecision'
                            AND sub.Decision = 'Cancelled'
                    )
        FROM rpd.SubmissionEvents upload
        WHERE upload.SubmissionId = @targetSubmissionId
        AND upload.Type = 'Submitted'
        AND ((@FileId IS NULL) OR (upload.FileId = @FileId))
        AND (
                (ISNULL(@BeforeProducerSubmits,0) = 1 AND NOT EXISTS (
                    SELECT 1
                    FROM rpd.SubmissionEvents submitted
                    WHERE submitted.SubmissionId = upload.SubmissionId
                    AND submitted.Type = 'RegistrationApplicationSubmitted'
                    AND submitted.Created > upload.Created
                ))
                OR
                ((ISNULL(@BeforeProducerSubmits,0) = 0 OR @FileId IS NULL) AND EXISTS (
                    SELECT 1
                    FROM rpd.SubmissionEvents submitted
                    WHERE submitted.SubmissionId = upload.SubmissionId
                    AND submitted.Type = 'RegistrationApplicationSubmitted'
                    AND submitted.Created > upload.Created
                ))
            )
        ORDER BY upload.Created DESC;

        -- Get Submission Meta-data - registrationdates, ComplianceScheme status etc
        SELECT
            @OrganisationUUIDForSubmission = O.ExternalId 
            ,@CSOReferenceNumber = O.ReferenceNumber 
            ,@IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
            ,@ComplianceSchemeId = S.ComplianceSchemeId
            ,@SubmissionPeriod = S.SubmissionPeriod
        FROM
            [rpd].[Submissions] AS S
            INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
        WHERE S.SubmissionId = @targetSubmissionId;

        IF (@targetFileId IS NOT NULL) 
        BEGIN
            IF @IsComplianceScheme = 1
            BEGIN
                WITH ComplianceSchemeMembersCTE AS (
                    SELECT csm.*
                        ,@SubmittedOn AS SubmittedOn
                        ,CASE WHEN @RegistrationDecisionDate IS NULL THEN 1
                                WHEN csm.EarliestSubmissionDate <= @RegistrationDecisionDate AND csm.joiner_date IS NULL THEN 1
                                WHEN csm.joiner_date IS NULL THEN 1
                                ELSE 0 END
                            AS IsOriginal
                        ,CASE WHEN @RegistrationDecisionDate IS NULL THEN 0
                                WHEN csm.EarliestSubmissionDate <= @RegistrationDecisionDate THEN 0
                                WHEN (csm.EarliestSubmissionDate > @RegistrationDecisionDate AND csm.joiner_date IS NOT NULL) THEN 1
                                WHEN (csm.EarliestSubmissionDate > @RegistrationDecisionDate AND csm.joiner_date IS NULL) THEN 0
                            END AS IsNewJoiner
                    FROM dbo.v_ComplianceSchemeMembers_resub csm
                    WHERE csm.FileId = @targetFileId
                )
                ,CompliancePaycalCTE
                AS
                (
                    SELECT
                        CSOReference
                        ,csm.CSOExternalId
                        ,csm.ComplianceSchemeId
                        ,csm.ReferenceNumber
                        ,csm.ExternalId
                        ,csm.submissionperiod
                        ,csm.OrganisationName
                        ,csm.RelevantYear
                        ,csm.SubmittedDate
                        ,csm.EarliestSubmissionDate
                        ,csm.IsOriginal
                        ,csm.IsNewJoiner
                        ,ppp.ProducerSize
                        ,csm.leaver_code
                        ,csm.leaver_date
                        ,csm.joiner_date
                        ,csm.organisation_change_reason
                        ,csm.FileId
                        ,csm.FileName
                        ,ppp.IsOnlineMarketPlace
                        ,ppp.NumberOfSubsidiaries
                        ,ppp.OnlineMarketPlaceSubsidiaries AS NumberOfSubsidiariesBeingOnlineMarketPlace
                    FROM
                        ComplianceSchemeMembersCTE csm
                        INNER JOIN dbo.t_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
                                    AND ppp.FileName = csm.FileName
                )
                INSERT INTO #PaycalParams (
                    SubmissionId,
                    IsCSO, CSOReference, CSOExternalId, ComplianceSchemeId, SubmissionPeriod, 
                    ReferenceNumber, ExternalId,
                    OrganisationName, IsOriginal, IsNewJoiner, 
                    RelevantYear, SubmittedDate, EarliestSubmissionDate,
                    OrganisationSize, LeaverCode, LeaverDate, JoinerDate, OrganisationChangeReason,
                    IsOnlineMarketPlace, NumberOfSubsidiaries, NumberOfSubsidiariesBeingOnlineMarketPlace,
                    FileName, FileId )
                SELECT  CAST(@targetSubmissionId AS UNIQUEIDENTIFIER) AS SubmissionId,
                        CAST(1 AS BIT) AS IsCSO
                        ,CSOReference
                        ,CAST(CSOExternalId AS UNIQUEIDENTIFIER) AS CSOExternalId
                        ,CAST(ComplianceSchemeId AS UNIQUEIDENTIFIER) AS ComplianceSchemeId
                        ,submissionperiod
                        ,ReferenceNumber
                        ,ExternalId
                        ,CAST(OrganisationName AS NVARCHAR(250)) AS OrganisationName
                        ,CAST(IsOriginal AS BIT) AS IsOriginal
                        ,CAST(IsNewJoiner AS BIT) AS IsNewJoiner
                        ,CAST(RelevantYear AS INT) AS RelevantYear
                        ,CAST(SubmittedDate AS DATETIME2(7)) AS SubmittedDate
                        ,CAST(EarliestSubmissionDate AS DATETIME2(7)) AS EarliestSubmissionDate
                        ,CAST(CASE WHEN ProducerSize = 'small' THEN 'S'
                            WHEN ProducerSize = 'large' THEN 'L'
                            ELSE NULL
                        END AS CHAR) AS ProducerSize
                        ,CAST(leaver_code AS NVARCHAR(20)) AS LeaverCode
                        ,CAST(leaver_date AS NVARCHAR(20)) AS LeaverDate
                        ,CAST(joiner_date AS NVARCHAR(20)) AS JoinerDate
                        ,CAST(organisation_change_reason AS NVARCHAR(20)) AS OrganisationChangeReason
                        ,CAST(IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace
                        ,CAST(NumberOfSubsidiaries AS INT) AS NumberOfSubsidiaries
                        ,CAST(NumberOfSubsidiariesBeingOnlineMarketPlace AS INT) AS NumberOfSubsidiariesBeingOnlineMarketPlace
                        ,CAST(FileName AS UNIQUEIDENTIFIER) AS FileName
                        ,CAST(FileId AS UNIQUEIDENTIFIER) AS FileId
                FROM CompliancePaycalCTE
            END
            
            IF @IsComplianceScheme = 0
            BEGIN
                WITH ProducerPaycalParametersCTE AS (
                    SELECT o.Name AS OrgName,
                        OrganisationExternalId,
                        OrganisationId AS OrgRefNum,
                        FileName,
                        FileId,
                        RegistrationSetId,
                        IsOnlineMarketPlace,
                        NumberOfSubsidiaries,
                        OnlineMarketPlaceSubsidiaries,
                        OrganisationSize,
                        ProducerSize,
                        ppp.NationId
                    FROM dbo.t_ProducerPaycalParameters_resub ppp
                    INNER JOIN rpd.Organisations o ON o.ExternalId = ppp.OrganisationExternalId
                    WHERE ppp.FileId = @targetFileId
                )
                INSERT INTO #PaycalParams (
                    SubmissionId,
                    IsCSO, CSOReference, CSOExternalId, ComplianceSchemeId, SubmissionPeriod, 
                    ReferenceNumber, ExternalId,
                    OrganisationName, RelevantYear, SubmittedDate, EarliestSubmissionDate,
                    OrganisationSize, LeaverCode, LeaverDate, JoinerDate, OrganisationChangeReason,
                    IsOnlineMarketPlace, NumberOfSubsidiaries, NumberOfSubsidiariesBeingOnlineMarketPlace,
                    FileName, FileId )
                SELECT  CAST(@targetSubmissionId AS UNIQUEIDENTIFIER) AS SubmissionId,
                        CAST(0 AS BIT) AS IsCSO, NULL AS CSOReference, NULL AS CSOExternalId, NULL AS ComplianceSchemeId, @SubmissionPeriod AS SubmissionPeriod,
                        OrgRefNum AS ReferenceNumber, OrganisationExternalId AS ExternalId,
                        CAST(OrgName AS NVARCHAR(250)) AS OrganisationName, CONVERT(INT, RIGHT(RTRIM(@SubmissionPeriod), 4)) AS RelevantYear, CAST(@SubmittedOn AS DATETIME2(7)) AS SubmittedDate, CAST(@FirstSubmittedOn AS DATETIME2(7)) AS EarliestSubmissionDate,
                        CAST(OrganisationSize AS CHAR) AS OrganisationSize, NULL AS LeaverCode, NULL AS LeaverDate, NULL AS JoinerDate, NULL AS OrganisationChangeReason,
                        CAST(IsOnlineMarketplace AS BIT) AS IsOnlineMarketplace, CAST(NumberOfSubsidiaries AS INT) AS NumberOfSubsidiaries, CAST(OnlineMarketPlaceSubsidiaries AS INT) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
                        CAST(FileName AS UNIQUEIDENTIFIER) AS FileName, CAST(FileId AS UNIQUEIDENTIFIER) AS FileId
                FROM ProducerPaycalParametersCTE
            END
        END
        ELSE
        BEGIN
            PRINT 'no file id';
        END
        SELECT * FROM #PaycalParams;
    END
END
GO