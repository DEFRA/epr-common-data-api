IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_ProducerPaycalParameters_r9]')
) DROP VIEW [dbo].[v_ProducerPaycalParameters_r9];

GO

CREATE VIEW [dbo].[v_ProducerPaycalParameters_r9] AS WITH 
    OrganisationDetailsCTE AS (
        SELECT 
            cfm.OrganisationId as OrganisationExternalId
			,cd.Organisation_Id AS OrganisationId
			,cd.FileName
			,cfm.FileId
			,cfm.RegistrationSetId
            ,CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace
            ,CASE
				UPPER(organisation_size)
				WHEN 'L' THEN 'large'
				WHEN 'S' THEN 'small'
				ELSE organisation_size
			 END AS ProducerSize
            ,cd.Organisation_Size AS OrganisationSize
			,CASE UPPER(cd.home_nation_code)
                WHEN 'EN' THEN 1
                WHEN 'NI' THEN 2
                WHEN 'SC' THEN 3
                WHEN 'WS' THEN 4
                WHEN 'WA' THEN 4
            END AS NationId
        FROM
            [rpd].[CompanyDetails] cd
			inner join rpd.cosmos_file_metadata cfm on cfm.FileName = cd.FileName
        WHERE cd.Subsidiary_Id IS NULL
    )
    ,SubsidiaryCountsCTE
    AS
    (
        SELECT
			cd.FileName
            ,COUNT(DISTINCT subsidiary_id) AS NumberOfSubsidiaries
            ,COUNT(CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries
        FROM
            rpd.companydetails cd
        WHERE cd.Subsidiary_Id IS NOT NULL
        AND cd.leaver_date IS NULL
        GROUP BY cd.FileName
    )
	,OrganisationPaycalDetailsCTE AS (
		SELECT 
		   OrganisationExternalId
		   ,OrganisationId
		   ,od.[FileName]
		   ,od.FileId
		   ,RegistrationSetId
		   ,CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace
		   ,OrganisationSize
		   ,ProducerSize
		   ,NationId
		   ,ISNULL(NumberOfSubsidiaries,0) as NumberOfSubsidiaries
		   ,ISNULL(OnlineMarketPlaceSubsidiaries,0) as OnlineMarketPlaceSubsidiaries
		FROM OrganisationDetailsCTE od
		left join SubsidiaryCountsCTE sc on sc.FileName = od.FileName
    )
SELECT
    *
FROM
    OrganisationPaycalDetailsCTE;
GO
