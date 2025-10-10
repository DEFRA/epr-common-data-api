IF EXISTS (SELECT 1 FROM sys.procedures
            WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetRegistrationFeeCalculationDetails]'))
DROP PROCEDURE [dbo].[sp_GetRegistrationFeeCalculationDetails];
GO

CREATE PROC [dbo].[sp_GetRegistrationFeeCalculationDetails] @fileId [varchar](40) AS
/*
	Updated by 596714 and 610862
*/
BEGIN
SET NOCOUNT ON;

       DECLARE @fileName as varchar(40);
    
    SELECT 
        @fileName = [FileName]
    FROM 
        [rpd].[cosmos_file_metadata] metadata
    WHERE 
        FileId = @fileId;

    ;WITH
	OrganisationDetails AS (
        SELECT 
            cd.Organisation_Id AS OrganisationId,
            CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
            cd.Organisation_Size AS OrganisationSize,
            CASE UPPER(cd.home_nation_code)
                WHEN 'EN' THEN 1
                WHEN 'NI' THEN 2
                WHEN 'SC' THEN 3
                WHEN 'WS' THEN 4
                WHEN 'WA' THEN 4
            END AS NationId,
            CASE WHEN cd.joiner_date IS NOT NULL THEN 1 ELSE 0 END AS IsNewJoiner, 
			cd.subsidiary_id  as SubsidiaryId, 
			cd.Packaging_Activity_OM as Packaging_Activity_OM
        FROM
            [rpd].[CompanyDetails] cd
        WHERE
            TRIM(cd.FileName) = @fileName
 
    ),
	SubsidiaryCount AS

	(
	(select OrganisationID, count(*) as subsidiarycounter,COUNT(CASE WHEN od.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries from OrganisationDetails od  where SubsidiaryId IS NOT NULL group by OrganisationID)
	)


    SELECT
        od.OrganisationId AS OrganisationId,
        od.OrganisationSize AS OrganisationSize,
		isnull(sc.subsidiarycounter,0) as NumberOfSubsidiaries,
		ISNULL(sc.OnlineMarketPlaceSubsidiaries, 0)as NumberOfSubsidiariesBeingOnlineMarketPlace,     
	    CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace,
        CAST(od.IsNewJoiner AS BIT) AS IsNewJoiner,
        NationId
    FROM
        OrganisationDetails od left join SubsidiaryCount sc on od.OrganisationID=sc.OrganisationID
		where SubsidiaryId is null;


END;

GO
