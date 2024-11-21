﻿-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_GetProducerDetailsByOrganisationId]'))
DROP PROCEDURE [apps].[sp_GetProducerDetailsByOrganisationId];
GO

CREATE PROCEDURE apps.sp_GetProducerDetailsByOrganisationId
    @organisationId INT
AS
BEGIN
    SET NOCOUNT ON;

WITH LatestFile AS (
    SELECT TOP 1
        LTRIM(RTRIM([FileName])) AS LatestFileName
    FROM 
        [rpd].[cosmos_file_metadata] metadata INNER JOIN [rpd].[Organisations] ORG ON ORG.referenceNumber = metadata.OrganisationId
    WHERE 
        ORG.Id = @organisationId
    ORDER BY 
        CAST(Created AS DATETIME) DESC
),
SubsidiaryCount AS (
    SELECT 
        CD.organisation_id, 
        COUNT(*) AS NumberOfSubsidiaries
    FROM 
        [rpd].[CompanyDetails] CD INNER JOIN [rpd].[Organisations] ORG ON ORG.referenceNumber = CD.organisation_id
    CROSS JOIN LatestFile LF -- Use the latest file name
    WHERE 
        CD.organisation_id = @organisationId
        AND LTRIM(RTRIM(CD.[filename])) = LF.LatestFileName -- Match file name with the latest
        AND CD.subsidiary_id IS NOT NULL
    GROUP BY 
        CD.organisation_id
)
SELECT 
    COUNT(CASE WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 END) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id,
    CASE 
        WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS IsOnlineMarketplace,
    pom.organisation_size AS ProducerSize,
    '' AS ApplicationReferenceNumber,
    sc.NumberOfSubsidiaries,
    N.NationCode AS Regulator
FROM 
    rpd.companyDetails cd
    INNER JOIN rpd.Organisations org 
        ON org.referenceNumber = cd.organisation_id
    LEFT JOIN dbo.t_POM pom 
        ON pom.organisation_id = org.referenceNumber
    JOIN [rpd].[Nations] N 
        ON N.Id = org.NationId
    INNER JOIN rpd.Submissions sub 
        ON sub.organisationid = org.externalid
    LEFT JOIN SubsidiaryCount sc 
        ON sc.organisation_id = cd.organisation_id
WHERE 
    cd.organisation_id = @organisationId
GROUP BY 
    cd.packaging_activity_om, 
    cd.organisation_id,
    pom.organisation_size,
    N.NationCode,
    sc.NumberOfSubsidiaries;

    
END;

GO