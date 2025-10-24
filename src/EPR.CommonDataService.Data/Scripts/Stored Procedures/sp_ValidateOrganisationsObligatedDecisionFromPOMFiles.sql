IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles]'))
    DROP PROCEDURE [dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles];
GO

CREATE PROC [dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles]
(
    @OrganisationIds NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    
	IF OBJECT_ID('tempdb..#DpOrganisationIdTable') IS NOT NULL
        DROP TABLE #DpOrganisationIdTable;

    IF OBJECT_ID('tempdb..#SubOrganisationIdTable') IS NOT NULL
        DROP TABLE #SubOrganisationIdTable;

    DECLARE @Delimiter CHAR(1) = ',';
    
    SELECT  DISTINCT CD.organisation_id AS OrganisationId
    INTO    #DpOrganisationIdTable
    FROM    rpd.CompanyDetails CD 
            INNER JOIN (SELECT TRY_CAST(value AS NVARCHAR(10)) AS OrgId FROM STRING_SPLIT(@OrganisationIds, @Delimiter)) I
                                ON CD.organisation_id = I.OrgId OR CD.subsidiary_id = I.OrgId AND I.OrgId IS NOT NULL
    WHERE   CD.subsidiary_id IS NULL

    SELECT  CD.subsidiary_id AS OrganisationId
    INTO    #SubOrganisationIdTable
    FROM    rpd.CompanyDetails AS CD
    WHERE   EXISTS (SELECT 1 FROM #DpOrganisationIdTable DIT WHERE DIT.OrganisationId = CD.organisation_id)
            AND CD.subsidiary_id IS NOT NULL
    GROUP BY CD.subsidiary_id

    -- Variables to hold the final results
    DECLARE @DpOrgList  NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), @Delimiter) FROM #DpOrganisationIdTable);
    DECLARE @SubOrgList NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(OrganisationId AS NVARCHAR(MAX)), @Delimiter) FROM #SubOrganisationIdTable);

    -- Call the child procedure
    EXEC dbo.sp_ProcessOrganisationsToRetrieveObligationDecision @DpOrgIds = @DpOrgList, @SubOrgIds = @SubOrgList;
END;
GO