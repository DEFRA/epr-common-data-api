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
		AND metadata.ComplianceSchemeId IS NOT NUll
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
),
OnlineMarketPlace AS (
    SELECT 
        CD.organisation_id, 
        CASE WHEN  cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
		 cd.organisation_size as MemberType
    FROM  
        [rpd].[CompanyDetails] CD
    WHERE EXISTS (
            SELECT 1
            FROM LatestFile LF
            WHERE LTRIM(RTRIM(CD.[filename])) = LF.LatestFileName
        )
        AND CD.subsidiary_id IS NULL
    GROUP BY 
        CD.organisation_id,
		cd.organisation_size,
		CD.packaging_activity_om
) 
SELECT COUNT(CASE WHEN  CD.subsidiary_id IS NOT NULL AND cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 ELSE 0 END) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id AS MemberId,
    OMP.MemberType,
    ISNull( sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries,
	CAST(OMP.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketplace
FROM LatestFile LF
INNER JOIN [rpd].[CompanyDetails] cd ON Trim(cd.[filename]) = Trim(LF.LatestFileName)
LEFT JOIN SubsidiaryCount sc ON sc.organisation_id = cd.organisation_id
LEFT JOIN OnlineMarketPlace OMP ON OMP.organisation_id = cd.organisation_id

GROUP BY 
    cd.organisation_id,
	OMP.IsOnlineMarketPlace,
	OMP.MemberType,
    sc.NumberOfSubsidiaries;

END;

GO