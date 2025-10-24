IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile]'))
    DROP PROCEDURE [dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile];
GO

CREATE PROC [dbo].[sp_ValidateOrganisationsObligatedDecisionFromRegistrationFile] 
(
    @FileIds NVARCHAR(MAX) 
)
AS
BEGIN
    SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#DpOrganisationIdTable') IS NOT NULL
        DROP TABLE #DpOrganisationIdTable;
    IF OBJECT_ID('tempdb..#SubOrganisationIdTable') IS NOT NULL
        DROP TABLE #SubOrganisationIdTable;

    DECLARE @Delimiter CHAR(1) = ',';

    SELECT  CD.organisation_id AS OrganisationId
    INTO    #DpOrganisationIdTable
    FROM    rpd.SubmissionEvents AS SE
            INNER JOIN rpd.cosmos_file_metadata AS CFM ON CFM.FileId = SE.FileId
            INNER JOIN rpd.CompanyDetails AS CD ON CD.[FileName] = CFM.[FileName]
            INNER JOIN (SELECT value AS FileId FROM STRING_SPLIT(@FileIds, @Delimiter)) F ON F.FileId = SE.FileId
    WHERE   CD.subsidiary_id IS NULL
    GROUP BY CD.organisation_id;

    SELECT  CD.subsidiary_id AS OrganisationId
    INTO    #SubOrganisationIdTable
    FROM    rpd.CompanyDetails AS CD
            INNER JOIN #DpOrganisationIdTable DID ON DID.OrganisationId = CD.organisation_id
    WHERE   CD.subsidiary_id IS NOT NULL
    GROUP BY CD.subsidiary_id;

    -- Variables to hold the two final CSV results
    DECLARE @DpOrgList NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), @Delimiter) FROM #DpOrganisationIdTable);
    DECLARE @SubOrgList NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), @Delimiter) FROM #SubOrganisationIdTable);

    -- Call the child procedure
    EXEC dbo.sp_ProcessOrganisationsToRetrieveObligationDecision @DpOrgIds = @DpOrgList, @SubOrgIds = @SubOrgList;
END;
GO