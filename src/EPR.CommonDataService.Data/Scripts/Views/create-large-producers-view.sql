SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP VIEW IF EXISTS [apps].[v_Large_Producers]
GO

CREATE VIEW [apps].[v_Large_Producers]
AS SELECT DISTINCT *
FROM (
    SELECT DISTINCT
    Pom.organisation_id AS 'RPD_Organisation_ID'
    , '' AS 'submission_period'
    , cs.Name AS 'Compliance_scheme'
    -- COALESCE ALL COMPANY DETAILS FIELDS
    , COALESCE( producer.CompaniesHouseNumber, CompanyDetails.companies_house_number) AS 'Companies_House_number'
    , COALESCE(NULLIF(CompanyDetails.subsidiary_id, ''), NULLIF(Pom.subsidiary_id, ''), '') AS 'Subsidiary_ID'
    , COALESCE( producer.Name, CompanyDetails.organisation_name ) AS 'Organisation_name'
    , COALESCE( producer.TradingName, CompanyDetails.Trading_Name ) AS 'Trading_name'
    , COALESCE( (
            TRIM(producer.BuildingName) + ' ' +
            TRIM(producer.BuildingNumber) 
        ), CompanyDetails.registered_addr_line1
    ) AS 'Address_line_1'
    , COALESCE(producer.Street, CompanyDetails.registered_addr_line2) AS 'Address_line_2'
    , 'Address_line_3' = ''
    , 'Address_line_4' = ''
    , COALESCE( producer.Town, CompanyDetails.registered_city) AS 'Town'
    , producer.County AS 'County'
    , COALESCE( producer.Country, CompanyDetails.registered_addr_country) AS 'Country'
    , COALESCE( producer.Postcode, CompanyDetails.registered_addr_postcode) AS 'Postcode'
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
      END) As 'Environmental_regulator'
    , (CASE csnation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
      END) As 'Compliance_scheme_regulator'
    , 'Reporting_year' = '2023'
    --, 'POM_START' AS StartPoint
    --, e_status.EnrolmentStatuses_EnrolmentStatus as e_status
    FROM [rpd].[Pom]
 
    LEFT JOIN (
        SELECT CompanyDetails.*
        FROM [rpd].[CompanyDetails]
        JOIN [dbo].[v_registration_latest] rl
            ON CompanyDetails.organisation_id = rl.organisation_id
    ) CompanyDetails
        ON Pom.Organisation_id = CompanyDetails.organisation_id
    INNER JOIN apps.get_latest_pom_file_submitted meta
        ON Pom.FileName = meta.FileName
    LEFT JOIN rpd.ComplianceSchemes cs
        ON meta.ComplianceSchemeId = cs.ExternalId
    JOIN rpd.Organisations producer
        ON Pom.organisation_id = producer.ReferenceNumber
    JOIN rpd.Nations producernation   ---> 'LEFT JOIN instead of JOIN to take data even if enrolment data doesn't exist' (donot use it)
        ON producer.NationId = producernation.Id
    LEFT JOIN rpd.Nations csnation
        ON cs.NationId = csnation.Id
    JOIN (SELECT FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus
          FROM t_rpd_data_SECURITY_FIX
          GROUP BY FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus) e_status
        ON e_status.FromOrganisation_ReferenceNumber = pom.organisation_id
    WHERE organisation_size = 'L'
       AND (cs.IsDeleted = 0 OR cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
       AND (producer.isdeleted = 0 OR producer.isdeleted IS NULL)
       AND e_status.EnrolmentStatuses_EnrolmentStatus <> 'Rejected'
       AND (producer.IsComplianceScheme = 0 OR producer.IsComplianceScheme IS NULL)
) pom_start
 
UNION
 
SELECT DISTINCT * FROM (
    SELECT DISTINCT
    CompanyDetails.organisation_id AS 'RPD_Organisation_ID'
    , '' AS 'submission_period'
    , cs.Name AS 'Compliance_scheme'
    -- COALESCE ALL COMPANY DETAILS FIELDS
    , COALESCE( producer.CompaniesHouseNumber, CompanyDetails.companies_house_number) AS 'Companies_House_number'
    , COALESCE( CompanyDetails.subsidiary_id, '') AS 'Subsidiary_ID'
    , COALESCE( producer.Name, CompanyDetails.organisation_name ) AS 'Organisation_name'
    , COALESCE( producer.TradingName, CompanyDetails.Trading_Name ) AS 'Trading_name'
    , COALESCE( (
            TRIM(producer.BuildingName) + ' ' +
            TRIM(producer.BuildingNumber) 
        ), CompanyDetails.registered_addr_line1
    ) AS 'Address_line_1'
    , COALESCE(producer.Street, CompanyDetails.registered_addr_line2) AS 'Address_line_2'
    , 'Address_line_3' = ''
    , 'Address_line_4' = ''
    , COALESCE( producer.Town, CompanyDetails.registered_city) AS 'Town'
    , producer.County AS 'County'
    , COALESCE( producer.Country, CompanyDetails.registered_addr_country) AS 'Country'
    , COALESCE( producer.Postcode, CompanyDetails.registered_addr_postcode) AS 'Postcode'
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
      END) As 'Environmental_regulator'
    , (CASE csnation.Id
        WHEN 1 THEN 'Environment Agency (England)'
        WHEN 2 THEN 'Northern Ireland Environment Agency'
        WHEN 3 THEN 'Scottish Environment Protection Agency'
        WHEN 4 THEN 'Natural Resources Wales'
      END) As 'Compliance_scheme_regulator'
    , 'Reporting_year' = '2023'
    --, 'REG_START' AS StartPoint
    -- , e_status.EnrolmentStatuses_EnrolmentStatus as e_status
    FROM [rpd].[CompanyDetails]
 
    INNER JOIN apps.get_latest_org_file_submitted meta
        ON [CompanyDetails].FileName = meta.FileName
    LEFT JOIN rpd.ComplianceSchemes cs
        ON meta.ComplianceSchemeId = cs.ExternalId
    JOIN rpd.Organisations producer
        ON [CompanyDetails].organisation_id = producer.ReferenceNumber
    LEFT JOIN rpd.Nations producernation  ---> 'LEFT JOIN instead of JOIN to take data even if enrolment data doesn't exist' (should use it)
        ON producer.NationId = producernation.Id
    LEFT JOIN rpd.Nations csnation
        ON cs.NationId = csnation.Id
    JOIN [dbo].[v_registration_latest] rl
        ON CompanyDetails.organisation_id = rl.organisation_id AND rl.created = meta.created
    JOIN (SELECT FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus
          FROM t_rpd_data_SECURITY_FIX
          GROUP BY FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus) e_status
        ON e_status.FromOrganisation_ReferenceNumber = CompanyDetails.organisation_id
 
     WHERE (cs.IsDeleted = 0 OR cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
          AND (producer.isdeleted = 0 OR producer.isdeleted IS NULL)
          AND e_status.EnrolmentStatuses_EnrolmentStatus <> 'Rejected'
) reg_start;
GO
