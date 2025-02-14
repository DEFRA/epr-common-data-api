IF EXISTS (SELECT 1 FROM sys.procedures
            WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetFeeCalculationDetails]'))
DROP PROCEDURE [dbo].[sp_GetFeeCalculationDetails];
GO

CREATE PROC [dbo].[sp_GetFeeCalculationDetails] @fileId [varchar](40) AS
BEGIN
SET NOCOUNT ON;

    DECLARE @fileName as varchar(40);
    
    SELECT 
        @fileName = [FileName]
    FROM 
        [rpd].[cosmos_file_metadata] metadata
    Where 
        FileId = @fileId;

    ;WITH SubsidiaryDetails AS (
        SELECT 
            cd.Organisation_Id AS OrganisationId,
            COUNT(*) AS TotalSubsidiaries,
            COUNT(CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries
        FROM
            [rpd].[CompanyDetails] cd
        WHERE
            TRIM(cd.FileName) = @fileName
            AND cd.Subsidiary_Id IS NOT NULL
        GROUP BY 
            cd.Organisation_Id
    )
    , OrganisationDetails AS (
        SELECT 
            cd.Organisation_Id AS OrganisationId,
            CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
            cd.Organisation_Size AS OrganisationSize,
            CASE UPPER(cd.home_nation_code)
                WHEN 'EN' THEN 1
                WHEN 'NI' THEN 2
                WHEN 'SC' THEN 3
                WHEN 'WS' THEN 4
                WHEN 'WA' THEN 4
            END AS NationId
        FROM
            [rpd].[CompanyDetails] cd
        WHERE
            TRIM(cd.FileName) = @fileName
            AND cd.Subsidiary_Id IS NULL
    )
    SELECT
        od.OrganisationId AS OrganisationId,
        od.OrganisationSize AS OrganisationSize,
        ISNULL(sd.TotalSubsidiaries, 0) AS NumberOfSubsidiaries,
        ISNULL(sd.OnlineMarketPlaceSubsidiaries, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
        CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace,
        NationId
    FROM
        OrganisationDetails od
    LEFT JOIN
        SubsidiaryDetails sd ON sd.OrganisationId = od.OrganisationId

END;

GO