-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetProducerDetailsByOrganisationId]'))
DROP PROCEDURE [dbo].[sp_GetProducerDetailsByOrganisationId];
GO

CREATE PROCEDURE dbo.sp_GetProducerDetailsByOrganisationId
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
		AND metadata.ComplianceSchemeId IS NUll
    ORDER BY 
        metadata.Created DESC
),
LatestSubmission AS (
    SELECT TOP 1 
        organisationid,
        appreferencenumber,
        Created
	FROM     [rpd].[Submissions] sub
	INNER JOIN   [rpd].[Organisations] org  ON sub.organisationid = org.externalid
	WHERE org.referenceNumber = @organisationId  AND sub.SubmissionType = 'Registration'
    ORDER BY Created DESC
),
SubsidiaryDetails AS (
    SELECT 
        CD.organisation_id, 
        COUNT(*) AS NumberOfSubsidiaries,
		COUNT(CASE WHEN  CD.subsidiary_id IS NOT NULL AND cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 END) AS NumberOfSubsidiariesBeingOnlineMarketPlace
    FROM  
        [rpd].[CompanyDetails] CD
    WHERE 
        CD.organisation_id = @organisationId
        AND EXISTS (
            SELECT 1
            FROM LatestFile LF
            WHERE LTRIM(RTRIM(CD.[filename])) = LF.LatestFileName
        )
        AND CD.subsidiary_id IS NOT NULL
    GROUP BY 
        CD.organisation_id
),
OrganisationDetails AS (
    SELECT 
        CD.organisation_id, 
        CASE WHEN  cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1  ELSE 0  END AS IsOnlineMarketPlace,
		 cd.organisation_size 
    FROM  
        [rpd].[CompanyDetails] CD
    WHERE 
        CD.organisation_id = @organisationId
        AND EXISTS (
            SELECT 1
            FROM LatestFile LF
            WHERE LTRIM(RTRIM(CD.[filename])) = LF.LatestFileName
        )
        AND CD.subsidiary_id IS  NULL
    GROUP BY 
        CD.organisation_id,
		CD.packaging_activity_om,
		CD.organisation_size 
) 

SELECT sc.NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id AS OrganisationId,
    cd.organisation_size AS ProducerSize,
    sub.appreferencenumber AS ApplicationReferenceNumber,
    ISNull( sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries,
    N.NationCode AS Regulator,
	CAST(cd.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketplace
FROM 
    OrganisationDetails cd    
	INNER JOIN [rpd].[Organisations] org ON org.referenceNumber = cd.organisation_id
    LEFT JOIN [rpd].[Nations] N ON N.Id = org.NationId
    INNER JOIN LatestSubmission sub ON sub.organisationid = org.externalid
    LEFT JOIN SubsidiaryDetails sc ON sc.organisation_id = cd.organisation_id
WHERE 
    cd.organisation_id = @organisationId
END

GO 