IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_ProducerPaycalParameters]')
) DROP VIEW [dbo].[v_ProducerPaycalParameters];

GO

CREATE VIEW [dbo].v_ProducerPaycalParameters 
as 
	WITH SubsidiaryCountsCTE AS (
        SELECT o.organisation_id as OrganisationReference,
            ISNULL(s.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
        FROM (
                SELECT DISTINCT organisation_id
                FROM rpd.companyDetails
                where organisation_id is not null
            ) o
            LEFT JOIN (
                SELECT organisation_id,
                    COUNT(*) AS NumberOfSubsidiaries
                FROM rpd.companyDetails
                WHERE subsidiary_id IS NOT NULL
                    and organisation_id IS NOT NULL
                GROUP BY organisation_id
            ) s ON o.organisation_id = s.organisation_id
    ),
    OnlineMarketSubsidiaryCountCTE as (
        SELECT o.organisation_id as OrganisationReference,
            ISNULL(s.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM (
                SELECT DISTINCT organisation_id
                FROM rpd.companyDetails
                where organisation_id is not null
            ) o
            LEFT JOIN (
                SELECT organisation_id,
                    COUNT(*) AS NumberOfSubsidiariesBeingOnlineMarketPlace
                FROM rpd.companyDetails
                WHERE packaging_activity_om IN ('Primary', 'Secondary')
                GROUP BY organisation_id
            ) s ON o.organisation_id = s.organisation_id
    ),
    SubsidiaryAndMarketPlaceCountsCTE as (
        SELECT ms.OrganisationReference,
            sc.NumberOfSubsidiaries,
            ms.NumberOfSubsidiariesBeingOnlineMarketPlace
        from OnlineMarketSubsidiaryCountCTE as ms
            inner join SubsidiaryCountsCTE as sc on sc.OrganisationReference = ms.OrganisationReference
    ),
    OrganisationSizesCTE as (
        SELECT DISTINCT organisation_id,
            CASE
                organisation_size
                WHEN 'L' then 'large'
                WHEN 'S' then 'small'
                else organisation_size
            END as organisation_size,
            ROW_NUMBER() OVER (
                PARTITION BY organisation_id
                ORDER BY cd.load_ts DESC -- mark latest submissionEvent synced from cosmos
            ) as RowNum
        from rpd.CompanyDetails cd
        where organisation_id is not null
    ),
    MostRecentOrganisationSizeCTE as (
        SELECT distinct organisation_id as OrganisationReference,
            organisation_size as OrganisationSize
        from OrganisationSizesCTE cd
        where RowNum = 1
    ),
    OrganisationMarketPlaceInformationCTE AS (
        SELECT 
			o.ExternalId,
			smp.OrganisationReference,
            OrganisationSize AS ProducerSize,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM rpd.companyDetails
                    WHERE organisation_id = smp.OrganisationReference
                        AND packaging_activity_om IN ('Primary', 'Secondary')
                ) THEN CAST(1 AS BIT)
                ELSE CAST(0 AS BIT)
            END AS IsOnlineMarketplace,
            ISNULL(smp.NumberOfSubsidiaries, 0) as NumberOfSubsidiaries,
            ISNULL(smp.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) as NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM SubsidiaryAndMarketPlaceCountsCTE as smp
            left join MostRecentOrganisationSizeCTE mros ON mros.OrganisationReference = smp.OrganisationReference
		LEFT JOIN rpd.Organisations o on o.ReferenceNumber = smp.OrganisationReference
	)
select *
from OrganisationMarketPlaceInformationCTE
go

select * from dbo.v_ProducerPaycalParameters;
