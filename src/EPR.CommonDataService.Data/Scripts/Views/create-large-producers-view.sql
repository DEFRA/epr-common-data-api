SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP VIEW IF EXISTS [apps].[v_Large_Producers]
GO

-- Environmental regulator	Reporting year	Org name	Trading name	Companies House number 	Org ID	Subsidiary ID	Address line 1 	Address line 2 	Address line 3	Address line 4 	Town	County	Postcode	Compliance scheme	Compliance scheme regulator
CREATE VIEW [apps].[v_Large_Producers] AS
SELECT *
FROM (
    SELECT DISTINCT
    Pom.organisation_id AS 'RPD_Organisation_ID'
    , Pom.submission_period
    , cs.Name AS 'Compliance_scheme'
    -- COALESCE ALL COMPANY DETAILS FIELDS
    , COALESCE( CompanyDetails.companies_house_number, producer.CompaniesHouseNumber) AS 'Companies_House_number'
    , COALESCE( CompanyDetails.subsidiary_id, Pom.subsidiary_id) AS 'Subsidiary_ID'
    , COALESCE( CompanyDetails.organisation_name, producer.Name ) AS 'Organisation_name'
    , COALESCE( CompanyDetails.Trading_Name, producer.TradingName ) AS 'Trading_name'
    , COALESCE( CompanyDetails.registered_addr_line1, (
            TRIM(producer.BuildingNumber) + ' ' +
            TRIM(producer.BuildingName)
        )
    ) AS 'Address_line_1'
    , COALESCE( CompanyDetails.registered_addr_line2, producer.Street ) AS 'Address_line_2'
    , 'Address_line_3' = ''
    , 'Address_line_4' = ''
    , COALESCE( CompanyDetails.registered_city, producer.Town ) AS 'Town'
    , COALESCE( CompanyDetails.registered_addr_county, producer.County) AS 'County'
    , COALESCE( CompanyDetails.registered_addr_country, producer.Country ) AS 'Country'
    , COALESCE( CompanyDetails.registered_addr_postcode, producer.Postcode ) AS 'Postcode'
    , producernation.Name AS ProducerNation
    , producernation.Id AS ProducerNationId
    , csnation.Name AS ComplianceSchemeNation
    , csnation.Id AS ComplianceSchemeNationId
    , producer.ReferenceNumber AS ProducerId
    , (CASE producernation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
        ELSE 'Environment Agency (England)'
      END) As 'Environmental_regulator'
    , (CASE csnation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
        ELSE 'Environment Agency (England)'
      END) As 'Compliance_scheme_regulator'
    , 'Reporting_year' = '2023'
    --, 'POM_START' AS StartPoint
   
    FROM [rpd].[Pom]
   
LEFT JOIN (
    SELECT CompanyDetails.*
    FROM [rpd].[CompanyDetails]
    JOIN [dbo].[v_registration_latest] rl ON CompanyDetails.organisation_id = rl.organisation_id
) CompanyDetails ON Pom.Organisation_id = CompanyDetails.organisation_id
    LEFT JOIN rpd.cosmos_file_metadata meta
        ON Pom.FileName = meta.FileName
    LEFT JOIN rpd.ComplianceSchemes cs
        ON meta.ComplianceSchemeId = cs.ExternalId
    LEFT JOIN rpd.Organisations producer
        ON Pom.organisation_id = producer.ReferenceNumber
    JOIN rpd.Nations producernation   ---> 'LEFT JOIN instead of JOIN to take data even if enrolment data doesn't exist' (donot use it)
        ON producer.NationId = producernation.Id
    LEFT JOIN rpd.Nations csnation
        ON cs.NationId = csnation.Id
 
    WHERE organisation_size = 'L'
       AND (cs.IsDeleted = 0 or cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
) pom_start
 
UNION
 
SELECT * FROM (
    SELECT DISTINCT
    CompanyDetails.organisation_id AS 'RPD_Organisation_ID'
    , Pom.submission_period
    , cs.Name AS 'Compliance_scheme'
    -- COALESCE ALL COMPANY DETAILS FIELDS
    , COALESCE( CompanyDetails.companies_house_number, producer.CompaniesHouseNumber) AS 'Companies_House_number'
    , COALESCE( CompanyDetails.subsidiary_id, Pom.subsidiary_id) AS 'Subsidiary_ID'
    , COALESCE( CompanyDetails.organisation_name, producer.Name ) AS 'Organisation_name'
    , COALESCE( CompanyDetails.Trading_Name, producer.TradingName ) AS 'Trading_name'
    , COALESCE( CompanyDetails.registered_addr_line1, (
            TRIM(producer.BuildingNumber) + ' ' +
            TRIM(producer.BuildingName)
        )
    )  AS 'Address_line_1'
    , COALESCE( CompanyDetails.registered_addr_line2, producer.Street ) AS 'Address_line_2'
    , 'Address_line_3' = ''
    , 'Address_line_4' = ''
    , COALESCE( CompanyDetails.registered_city, producer.Town ) AS 'Town'
    , COALESCE( CompanyDetails.registered_addr_county, producer.County) AS 'County'
    , COALESCE( CompanyDetails.registered_addr_country, producer.Country ) AS 'Country'
    , COALESCE( CompanyDetails.registered_addr_postcode, producer.Postcode ) AS 'Postcode'
    , producernation.Name AS ProducerNation
    , producernation.Id AS ProducerNationId
    , csnation.Name AS ComplianceSchemeNation
    , csnation.Id AS ComplianceSchemeNationId
    , producer.ReferenceNumber AS ProducerId
    , (CASE producernation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
        ELSE 'Environment Agency (England)'
      END) As 'Environmental_regulator'
    , (CASE csnation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
        ELSE 'Environment Agency (England)'
      END) As 'Compliance_scheme_regulator'
    , 'Reporting_year' = '2023'
    --, 'REG_START' AS StartPoint
   
    FROM [rpd].[CompanyDetails]
   
    LEFT JOIN [rpd].[Pom]
        ON Pom.Organisation_id = CompanyDetails.organisation_id
    LEFT JOIN rpd.cosmos_file_metadata meta
        ON Pom.FileName = meta.FileName
    LEFT JOIN rpd.ComplianceSchemes cs
        ON meta.ComplianceSchemeId = cs.ExternalId
    LEFT JOIN rpd.Organisations producer
        ON Pom.organisation_id = producer.ReferenceNumber
    LEFT JOIN rpd.Nations producernation  ---> 'LEFT JOIN instead of JOIN to take data even if enrolment data doesn't exist' (should use it)
        ON producer.NationId = producernation.Id
    LEFT JOIN rpd.Nations csnation
        ON cs.NationId = csnation.Id
    JOIN [dbo].[v_registration_latest] rl
        ON CompanyDetails.organisation_id = rl.organisation_id

    WHERE (organisation_size = 'L' OR organisation_size IS NULL) ---> When only POM is submitted organisation_size will be NULL
    AND (cs.IsDeleted = 0 OR cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
) reg_start

-- The ORDER BY clause is not valid in views
-- ORDER BY 'Companies House Number', subsidiary_id 
GO
