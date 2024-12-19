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
            TRIM(metadata.FileName) AS LatestFileName
        FROM 
            [rpd].[cosmos_file_metadata] metadata
        INNER JOIN 
            [rpd].[Organisations] org ON org.ExternalId = metadata.OrganisationId
        WHERE 
            org.ReferenceNumber = @organisationId
            AND metadata.FileType = 'CompanyDetails'
            AND metadata.IsSubmitted = 1
            AND metadata.SubmissionType = 'Registration'
            AND metadata.ComplianceSchemeId IS NULL
        ORDER BY 
            metadata.Created DESC
    ),
    LatestSubmission AS (
        SELECT TOP 1 
            sub.OrganisationId,
            sub.AppReferenceNumber,
            sub.Created
        FROM 
            [rpd].[Submissions] sub
        INNER JOIN [rpd].[Organisations] org ON sub.OrganisationId = org.ExternalId
        WHERE 
            org.ReferenceNumber = @organisationId
            AND sub.SubmissionType = 'Registration'
        ORDER BY 
            sub.Created DESC
    ),
    SubsidiaryDetails AS (
        SELECT 
            cd.Organisation_Id AS OrganisationId, 
            COUNT(*) AS TotalSubsidiaries,
            COUNT(CASE WHEN cd.Subsidiary_Id IS NOT NULL AND cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries
        FROM  
            [rpd].[CompanyDetails] cd
        WHERE 
            cd.Organisation_Id = @organisationId
            AND EXISTS (
                SELECT 1
                FROM LatestFile lf
                WHERE TRIM(cd.FileName) = lf.LatestFileName
            )
            AND cd.Subsidiary_Id IS NOT NULL
        GROUP BY 
            cd.Organisation_Id
    ),
    OrganisationDetails AS (
        SELECT 
            cd.Organisation_Id AS OrganisationId,
            CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
            cd.Organisation_Size AS ProducerSize
        FROM  
            [rpd].[CompanyDetails] cd
        WHERE 
            cd.Organisation_Id = @organisationId
            AND EXISTS (
                SELECT 1
                FROM LatestFile lf
                WHERE TRIM(cd.FileName) = lf.LatestFileName
            )
            AND cd.Subsidiary_Id IS NULL
    )
    SELECT 
        ISNULL(sd.OnlineMarketPlaceSubsidiaries, 0)  AS NumberOfSubsidiariesBeingOnlineMarketPlace,
        od.OrganisationId,
        od.ProducerSize,
        ls.AppReferenceNumber AS ApplicationReferenceNumber,
        ISNULL(sd.TotalSubsidiaries, 0) AS NumberOfSubsidiaries,
        n.NationCode AS Regulator,
        CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace
    FROM 
        OrganisationDetails od
    INNER JOIN [rpd].[Organisations] org ON org.ReferenceNumber = od.OrganisationId
    LEFT JOIN  [rpd].[Nations] n ON n.Id = org.NationId
    INNER JOIN LatestSubmission ls ON ls.OrganisationId = org.ExternalId
    LEFT JOIN SubsidiaryDetails sd ON sd.OrganisationId = od.OrganisationId
    WHERE 
        od.OrganisationId = @organisationId;
END
GO 