IF EXISTS (SELECT
    1
FROM
    sys.procedures
WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetCsoMemberDetails]'))
DROP PROCEDURE [dbo].[sp_GetCsoMemberDetails];
GO

CREATE PROC [dbo].[sp_GetCsoMemberDetails] @organisationId [INT], @complianceSchemeId nvarchar(50) AS
BEGIN
SET NOCOUNT ON;

WITH LatestFile AS (
    SELECT TOP 1
        TRIM(metadata.FileName) AS LatestFileName, metadata.*
    FROM 
        [rpd].[cosmos_file_metadata] metadata
    INNER JOIN 
        [rpd].[Organisations] org ON org.ExternalId = metadata.OrganisationId
    WHERE 
        org.ReferenceNumber = @organisationId
        AND metadata.FileType = 'CompanyDetails'
        AND metadata.IsSubmitted = 1
        AND metadata.SubmissionType = 'Registration'
        AND metadata.ComplianceSchemeId = @complianceSchemeId
    ORDER BY 
        metadata.Created DESC
)
,SubsidiaryDetails AS (
    SELECT 
        cd.Organisation_Id AS OrganisationId, 
        COUNT(*) AS TotalSubsidiaries,
        COUNT(CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries
    FROM 
        [rpd].[CompanyDetails] cd
    WHERE 
        EXISTS (
            SELECT 1
            FROM LatestFile lf
            WHERE TRIM(cd.FileName) = lf.LatestFileName
        )
        AND cd.Subsidiary_Id IS NOT NULL
    GROUP BY 
        cd.Organisation_Id
)
,OrganisationDetails AS (
    SELECT 
        cd.Organisation_Id AS OrganisationId,
        CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
        cd.Organisation_Size AS MemberType
    FROM  
        [rpd].[CompanyDetails] cd
    WHERE 
        EXISTS (
            SELECT 1
            FROM LatestFile lf
            WHERE TRIM(cd.FileName) = lf.LatestFileName
        )
        AND cd.Subsidiary_Id IS NULL
)
SELECT  
    od.OrganisationId AS MemberId,
    od.MemberType,
    ISNULL(sd.TotalSubsidiaries, 0) AS NumberOfSubsidiaries,
    ISNULL(sd.OnlineMarketPlaceSubsidiaries, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
    CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace
FROM 
    OrganisationDetails od
LEFT JOIN 
    SubsidiaryDetails sd ON sd.OrganisationId = od.OrganisationId;


END;

GO


