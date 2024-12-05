-- Dropping stored procedure if it exists
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
LatestSubmission AS (
    SELECT TOP 1 
        organisationid,
        Created
	FROM     [rpd].[Submissions] sub
	INNER JOIN   [rpd].[Organisations] org  ON sub.organisationid = org.externalid
	WHERE org.referenceNumber = @organisationId  AND sub.SubmissionType = 'Registration'
    ORDER BY Created DESC
),
SubsidiaryCount AS (
    SELECT 
        CD.organisation_id, 
        COUNT(*) AS NumberOfSubsidiaries
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
)
SELECT 
    COUNT(CASE WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 END) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    cd.organisation_id AS MemberId,
    CASE 
        WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1
        ELSE 0
    END AS IsOnlineMarketplace,
    cd.organisation_size AS MemberType,
    sc.NumberOfSubsidiaries
FROM 
    [rpd].[CompanyDetails] cd 
    INNER JOIN [rpd].[Organisations] org ON org.referenceNumber = cd.organisation_id
    INNER JOIN LatestFile LF ON LF.LatestFileName = cd.filename
    LEFT JOIN LatestSubmission sub ON sub.organisationid = org.externalid
    INNER JOIN SubsidiaryCount sc ON sc.organisation_id = cd.organisation_id
	INNER JOIN [dbo].[v_ComplianceSchemeMembers] CS ON CS.ReferenceNumber = cd.organisation_id
WHERE 
    cd.organisation_id = @organisationId
GROUP BY 
    cd.packaging_activity_om, 
    cd.organisation_id,
    cd.organisation_size,
    sc.NumberOfSubsidiaries;
END;

GO