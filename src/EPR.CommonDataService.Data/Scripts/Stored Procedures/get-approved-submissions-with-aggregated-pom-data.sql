IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData]'))
BEGIN
    DROP PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData]
END
GO

CREATE PROC [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData] @ApprovedAfter [DATETIME2] AS
BEGIN
    IF OBJECT_ID('tempdb..#ApprovedSubmissions') IS NOT NULL
        DROP TABLE #ApprovedSubmissions;

    IF OBJECT_ID('tempdb..#FileIds') IS NOT NULL
        DROP TABLE #FileIds;

    IF OBJECT_ID('tempdb..#FileNames') IS NOT NULL
        DROP TABLE #FileNames;

    IF OBJECT_ID('tempdb..#MaxCreated') IS NOT NULL
        DROP TABLE #MaxCreated;


    SELECT SubmissionId
    INTO #ApprovedSubmissions
    FROM [rpd].[SubmissionEvents]
    WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter
      AND Decision = 'Accepted';


    SELECT s.SubmissionId, se.FileId, se.Created
    INTO #FileIds
    FROM #ApprovedSubmissions s
    CROSS APPLY (
        SELECT TOP 1 se.FileId, se.Created
        FROM [rpd].[SubmissionEvents] se
        WHERE se.SubmissionId = s.SubmissionId
          AND se.FileId IS NOT NULL
        ORDER BY se.Created DESC
    ) se;


    SELECT f.SubmissionId, fm.[FileName], f.Created
    INTO #FileNames
    FROM #FileIds f
    JOIN [rpd].[cosmos_file_metadata] fm ON f.FileId = fm.FileId;


    SELECT 
        p.submission_period AS SubmissionPeriod,
        p.packaging_material AS PackagingMaterial,
        p.organisation_id AS OrganisationId,
        MAX(f.Created) AS MaxCreated
    INTO #MaxCreated
    FROM #FileNames f
    JOIN [rpd].[Pom] p ON p.[FileName] = f.[FileName]
    WHERE LEFT(p.submission_period, 4) = CAST(YEAR(@ApprovedAfter) AS VARCHAR(4))
    GROUP BY 
        p.submission_period,
        p.packaging_material,
        p.organisation_id;

SELECT 
    CAST(f.SubmissionId AS uniqueidentifier) AS SubmissionId,
    p.submission_period AS SubmissionPeriod,
    p.packaging_material AS PackagingMaterial,
    SUM(p.packaging_material_weight) AS PackagingMaterialWeight,
    p.organisation_id AS OrganisationId
FROM #FileNames f
JOIN [rpd].[Pom] p 
  ON p.[FileName] = f.[FileName]
JOIN #MaxCreated m 
  ON p.submission_period = m.SubmissionPeriod
 AND p.packaging_material = m.PackagingMaterial
 AND p.organisation_id = m.OrganisationId
 AND f.Created = m.MaxCreated
WHERE LEFT(p.submission_period, 4) = CAST(YEAR(@ApprovedAfter) AS VARCHAR(4))
GROUP BY 
    f.SubmissionId,
    p.submission_period,
    p.packaging_material,
    p.organisation_id;


    DROP TABLE #ApprovedSubmissions;
    DROP TABLE #FileIds;
    DROP TABLE #FileNames;
    DROP TABLE #MaxCreated;
END
GO