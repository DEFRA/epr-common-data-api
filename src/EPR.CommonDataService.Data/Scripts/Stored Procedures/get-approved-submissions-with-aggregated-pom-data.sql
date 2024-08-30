IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData]'))
BEGIN
    DROP PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData]
END
GO

CREATE PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData]
    @ApprovedAfter DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    WITH ApprovedSubmissions AS
    (
        SELECT SubmissionId
        FROM [rpd].[SubmissionEvents]
        WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter
          AND Decision = 'Accepted'
    ),
    FileIds AS
    (
        SELECT s.SubmissionId, se.FileId
        FROM ApprovedSubmissions s
        CROSS APPLY
        (
            SELECT TOP 1 FileId
            FROM [rpd].[SubmissionEvents] se
            WHERE se.SubmissionId = s.SubmissionId
              AND se.FileId IS NOT NULL
            ORDER BY se.Created DESC
        ) se
    ),
    FileNames AS
    (
        SELECT f.SubmissionId, fm.[FileName]
        FROM FileIds f
        JOIN [rpd].[cosmos_file_metadata] fm ON f.FileId = fm.FileId
    )
    SELECT 
        CAST(f.SubmissionId AS uniqueidentifier) AS SubmissionId,
        p.submission_period AS SubmissionPeriod,
        p.packaging_material AS PackagingMaterial,
        SUM(p.packaging_material_weight) AS PackagingMaterialWeight,
        p.organisation_id AS OrganisationId
    FROM FileNames f
    JOIN [rpd].[Pom] p ON p.[FileName] = f.[FileName]
    WHERE LEFT(p.submission_period, 4) = CAST(YEAR(@ApprovedAfter) AS VARCHAR(4))
    GROUP BY 
        f.SubmissionId,
        p.submission_period,
        p.packaging_material,
        p.organisation_id;
END
GO
