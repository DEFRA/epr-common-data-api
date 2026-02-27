IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_ProducerPaycalParameters]')
) DROP VIEW [dbo].[v_ProducerPaycalParameters];

GO

CREATE VIEW [dbo].[v_ProducerPaycalParameters] AS WITH
    SubsidiaryCountsCTE
    AS
    (
        SELECT
            organisation_id AS OrganisationReference
			,FileName
            ,COUNT(DISTINCT subsidiary_id) AS NumberOfSubsidiaries
        FROM
            rpd.companydetails cd
        WHERE organisation_id IS NOT NULL
        GROUP BY organisation_id, FileName
    )
	,OnlineMarketSubsidiaryCountCTE
    AS
    (
        SELECT
            organisation_id AS OrganisationReference
			,FileName
            ,COUNT(DISTINCT subsidiary_id) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            rpd.companydetails cd
        WHERE subsidiary_id IS NOT NULL
            AND UPPER(packaging_activity_om) IN ('PRIMARY', 'SECONDARY')
        GROUP BY organisation_id, FileName
    )
	,SubsidiaryAndMarketPlaceCountsCTE
    AS
    (
        SELECT
            sc.OrganisationReference
			,sc.FileName
            ,ISNULL(sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries
            ,ISNULL(ms.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) as NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            SubsidiaryCountsCTE AS sc
            LEFT OUTER JOIN OnlineMarketSubsidiaryCountCTE AS ms
				ON sc.OrganisationReference = ms.OrganisationReference
				AND sc.FileName = ms.FileName
    )
	,MostRecentOrganisationSizeCTE
    AS
    (
        select a.* from
		(SELECT
            DISTINCT
            organisation_id	as OrganisationReference
			,FileName
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
				PARTITION BY organisation_id, FileName
				ORDER BY cd.load_ts DESC
			) AS RowNum
        FROM
            rpd.CompanyDetails cd
        WHERE organisation_id IS NOT NULL AND subsidiary_id IS NULL
		) as a
		where a.Rownum = 1
    )
    ,OrganisationMarketPlaceInformationCTE
    AS
    (
        SELECT
            smp.FileName
			,o.ExternalId
            ,smp.OrganisationReference
            ,OrganisationSize AS ProducerSize
            ,IsOnlineMarketplace
            ,ISNULL(smp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
            ,ISNULL(smp.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            SubsidiaryAndMarketPlaceCountsCTE AS smp
            LEFT JOIN MostRecentOrganisationSizeCTE mros
				ON mros.OrganisationReference = smp.OrganisationReference
				AND mros.FileName = smp.FileName
            LEFT JOIN rpd.Organisations o ON o.ReferenceNumber = smp.OrganisationReference
    )
SELECT
    *
FROM
    OrganisationMarketPlaceInformationCTE
WHERE ProducerSize is not null;
GO
