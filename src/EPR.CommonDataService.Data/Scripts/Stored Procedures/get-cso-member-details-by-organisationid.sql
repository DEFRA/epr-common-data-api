﻿-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetCsoMemberDetailsByOrganisationId]'))
DROP PROCEDURE [dbo].[sp_GetCsoMemberDetailsByOrganisationId];
GO

CREATE PROCEDURE dbo.sp_GetCsoMemberDetailsByOrganisationId
    @organisationId INT
AS
BEGIN
    SET NOCOUNT ON;

WITH LatestFile AS (
    SELECT TOP 1
        LTRIM(RTRIM([FileName])) AS LatestFileName
    FROM 
        [rpd].[cosmos_file_metadata] metadata 
    INNER JOIN [rpd].[Organisations] ORG ON ORG.ExternalId = metadata.OrganisationId
    WHERE 
        ORG.referenceNumber = @organisationId
        AND metadata.FileType = 'CompanyDetails'
        AND metadata.isSubmitted = 1
        AND metadata.SubmissionType = 'Registration'
    ORDER BY 
        metadata.Created DESC
),
SubsidiaryCount AS (
    SELECT 
        CD.organisation_id, 
        COUNT(*) AS NumberOfSubsidiaries
    FROM 
        [rpd].[CompanyDetails] CD
    WHERE 
        EXISTS (
            SELECT 1
            FROM LatestFile LF
            WHERE LTRIM(RTRIM(CD.[filename])) = LF.LatestFileName
        )
        AND CD.subsidiary_id IS NOT NULL
    GROUP BY 
        CD.organisation_id
)
SELECT  COUNT(CASE WHEN  CD.subsidiary_id IS NOT NULL AND cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 END) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id AS MemberId,
    CAST(
        CASE 
            WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1
            ELSE 0
        END AS BIT
    ) AS IsOnlineMarketplace,
    cd.organisation_size AS MemberType,
     ISNull( sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries
FROM LatestFile LF
INNER JOIN [rpd].[CompanyDetails] cd ON Trim(cd.[filename]) = Trim(LF.LatestFileName)
LEFT JOIN SubsidiaryCount sc ON sc.organisation_id = cd.organisation_id
GROUP BY 
    cd.packaging_activity_om, 
    cd.organisation_id,
    cd.organisation_size,
    sc.NumberOfSubsidiaries;

END;

GO