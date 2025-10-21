IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile]'))
DROP PROCEDURE [dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile];
GO

CREATE PROC [dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile] @FileIds [NVARCHAR](MAX) AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#FileIdTable') IS NOT NULL
        DROP TABLE #FileIdTable;
    CREATE TABLE #FileIdTable (FileId NVARCHAR(40));
    
    DECLARE @Delimiter CHAR(1) = ',';
        
    WITH Split_FileIds AS (
        SELECT value AS FileId FROM STRING_SPLIT(@FileIds, @Delimiter)
    )
    INSERT INTO #FileIdTable (FileId)
    SELECT FileId FROM Split_FileIds;

    IF OBJECT_ID('tempdb..#DpOrganisationIdTable') IS NOT NULL
        DROP TABLE #DpOrganisationIdTable;
    CREATE TABLE #DpOrganisationIdTable (OrganisationId NVARCHAR(10));

    IF OBJECT_ID('tempdb..#SubOrganisationIdTable') IS NOT NULL
        DROP TABLE #SubOrganisationIdTable;
    CREATE TABLE #SubOrganisationIdTable (OrganisationId NVARCHAR(10));

    INSERT INTO #DpOrganisationIdTable (OrganisationId)
    SELECT CD.organisation_id
    FROM rpd.SubmissionEvents AS SE
    INNER JOIN rpd.cosmos_file_metadata AS CFM ON CFM.FileId = SE.FileId
    INNER JOIN rpd.CompanyDetails AS CD ON CD.FileName = CFM.FileName
    INNER JOIN #FileIdTable F ON F.FileId = SE.FileId
    WHERE
        CD.subsidiary_id IS NULL
    GROUP BY
        CD.organisation_id;

    INSERT INTO #SubOrganisationIdTable (OrganisationId)
    SELECT CD.subsidiary_id
    FROM rpd.CompanyDetails AS CD
    INNER JOIN #DpOrganisationIdTable DID ON DID.OrganisationId = CD.organisation_id
    WHERE
        CD.subsidiary_id IS NOT NULL
    GROUP BY
        CD.subsidiary_id;

    -- Variables to hold the two final CSV results
    DECLARE @DpOrgList NVARCHAR(MAX);
    DECLARE @SubOrgList NVARCHAR(MAX);
    
    SELECT @DpOrgList = STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), ',')
    FROM #DpOrganisationIdTable;

    SELECT @SubOrgList = STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), ',')
    FROM #SubOrganisationIdTable;

    -- Call the child procedure
    EXEC dbo.sp_ProcessOrganisationsToRetrieveObligationDecision
        @DpOrgIds = @DpOrgList,
        @SubOrgIds = @SubOrgList;
END;
GO