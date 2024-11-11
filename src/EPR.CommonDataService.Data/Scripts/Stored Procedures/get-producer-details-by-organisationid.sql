-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_GetProducerDetailsByOrganisationId]'))
DROP PROCEDURE [apps].[sp_GetProducerDetailsByOrganisationId];
GO

CREATE PROCEDURE apps.sp_GetProducerDetailsByOrganisationId
    @organisationId INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH SubsidiaryCount AS (
    SELECT 
        organisation_id, 
        COUNT(*) AS NumberOfSubsidiaries
    FROM 
        rpd.companyDetails
    WHERE 
        organisation_id = @organisationId 
        AND subsidiary_id IS NULL
    GROUP BY 
        organisation_id
)

SELECT 
    COUNT(cd.packaging_activity_om) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id,
    CASE 
        WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS IsOnlineMarketplace,
    pom.organisation_size AS 'ProducerSize',
    '' AS ApplicationReferenceNumber,
    sc.NumberOfSubsidiaries
FROM 
    rpd.companyDetails cd
    INNER JOIN rpd.Organisations org 
        ON org.referenceNumber = cd.organisation_id
    LEFT JOIN dbo.t_POM pom 
        ON pom.organisation_id = org.referenceNumber
    LEFT JOIN dbo.t_POM_Submissions tps 
        ON tps.organisation_id = cd.organisation_id
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
    sc.NumberOfSubsidiaries;
    
END;

GO