IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles]'))
DROP PROCEDURE [dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles];
GO

CREATE PROC [dbo].[sp_ValidateOrganisationsObligatedDecisionFromPOMFiles] @ParamList [NVARCHAR](MAX) AS
BEGIN
    SET NOCOUNT ON;	

    -- Drop temp table if it exists
    IF OBJECT_ID('tempdb..#OrgAndSubIdsList') IS NOT NULL
        DROP TABLE #OrgAndSubIdsList;

    -- Create temp table to hold parsed values
    CREATE TABLE #OrgAndSubIdsList (
        ParamId NVARCHAR(10)
    );

    -- Split the input string and insert valid integers
    INSERT INTO #OrgAndSubIdsList (ParamId)
		SELECT TRY_CAST(value AS NVARCHAR)
    FROM STRING_SPLIT(@ParamList, ',')
    WHERE TRY_CAST(value AS NVARCHAR) IS NOT NULL;

    -- Return the result set 
	IF OBJECT_ID('tempdb..#DpOrganisationIdTable') IS NOT NULL DROP TABLE #DpOrganisationIdTable;
    CREATE TABLE #DpOrganisationIdTable (OrganisationId NVARCHAR(10));

    IF OBJECT_ID('tempdb..#SubOrganisationIdTable') IS NOT NULL DROP TABLE #SubOrganisationIdTable;
    CREATE TABLE #SubOrganisationIdTable (OrganisationId NVARCHAR(10));

	INSERT INTO #DpOrganisationIdTable (OrganisationId)
		SELECT Distinct CD.organisation_id as OrganisationId
	FROM [rpd].[CompanyDetails] CD 
		INNER JOIN #OrgAndSubIdsList ids ON CD.organisation_id = ids.ParamId OR CD.subsidiary_id = CAST(ids.ParamId AS NVARCHAR)
	WHERE CD.subsidiary_id IS NULL

	INSERT INTO #SubOrganisationIdTable (OrganisationId)
		SELECT CD.subsidiary_id AS OrganisationId
	FROM rpd.CompanyDetails AS CD
    WHERE
        EXISTS (SELECT 1 FROM #DpOrganisationIdTable DIT WHERE DIT.OrganisationId = CD.organisation_id)
        AND CD.subsidiary_id IS NOT NULL
    GROUP BY CD.subsidiary_id

	  -- Variables to hold the final results
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