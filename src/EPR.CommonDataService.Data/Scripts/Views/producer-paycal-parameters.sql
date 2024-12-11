IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_ProducerPaycalParameters]')
) DROP VIEW [dbo].[v_ProducerPaycalParameters];

GO

CREATE VIEW [dbo].v_ProducerPaycalParameters 
as 
WITH 
    SubsidiaryCountsCTE
    AS
    (
        SELECT
            organisation_id AS OrganisationReference
            ,COUNT(DISTINCT subsidiary_id) AS NumberOfSubsidiaries
        FROM
            rpd.companydetails cd
        WHERE organisation_id IS NOT NULL
        GROUP BY organisation_id
    )
	,OnlineMarketSubsidiaryCountCTE
    AS
    (
        SELECT
            organisation_id AS OrganisationReference
            ,COUNT(DISTINCT subsidiary_id) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            rpd.companydetails cd
        WHERE subsidiary_id IS NOT NULL
            AND UPPER(packaging_activity_om) IN ('PRIMARY', 'SECONDARY')
        GROUP BY organisation_id
    )
	,SubsidiaryAndMarketPlaceCountsCTE
    AS
    (
        SELECT
            sc.OrganisationReference
            ,ISNULL(sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries
            ,ISNULL(ms.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) as NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            SubsidiaryCountsCTE AS sc 
            LEFT OUTER JOIN OnlineMarketSubsidiaryCountCTE AS ms ON sc.OrganisationReference = ms.OrganisationReference
    )
	,MostRecentOrganisationSizeCTE
    AS
    (
        select a.* from 
		(SELECT
            DISTINCT
            organisation_id	as OrganisationReference
            ,CASE
				UPPER(organisation_size)
				WHEN 'L' THEN 'large'
				WHEN 'S' THEN 'small'
				ELSE organisation_size
			END AS OrganisationSize
			,CASE UPPER(packaging_activity_om)
				WHEN 'SECONDARY' THEN 1
				WHEN 'PRIMARY' THEN 1
				ELSE 0
			END AS IsOnlineMarketPlace        
			,ROW_NUMBER() OVER (
				PARTITION BY organisation_id
				ORDER BY cd.load_ts DESC
			) AS RowNum
        FROM
            rpd.CompanyDetails cd
        WHERE organisation_id IS NOT NULL AND subsidiary_id IS NULL ) as a
		where a.Rownum = 1
    )
    ,OrganisationMarketPlaceInformationCTE
    AS
    (
        SELECT
            o.ExternalId
            ,smp.OrganisationReference
            ,OrganisationSize AS ProducerSize
            ,IsOnlineMarketplace
            ,ISNULL(smp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
            ,ISNULL(smp.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            SubsidiaryAndMarketPlaceCountsCTE AS smp
            LEFT JOIN MostRecentOrganisationSizeCTE mros ON mros.OrganisationReference = smp.OrganisationReference
            LEFT JOIN rpd.Organisations o ON o.ReferenceNumber = smp.OrganisationReference
    )
SELECT
    *
FROM
    OrganisationMarketPlaceInformationCTE ;
GO
