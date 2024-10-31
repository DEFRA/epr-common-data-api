SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomData] @ApprovedAfter [DATETIME2],@Periods [VARCHAR](MAX) AS
BEGIN

    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..#ApprovedSubmissions') IS NOT NULL
        DROP TABLE #ApprovedSubmissions;

    IF OBJECT_ID('tempdb..#FileIds') IS NOT NULL
        DROP TABLE #FileIds;

    IF OBJECT_ID('tempdb..#FileNames') IS NOT NULL
        DROP TABLE #FileNames;

    IF OBJECT_ID('tempdb..#MaxCreated') IS NOT NULL
        DROP TABLE #MaxCreated;
		
	IF OBJECT_ID('tempdb..#PeriodYearTable') IS NOT NULL
		DROP TABLE #PeriodYearTable;	
		
	--Get start date from approved after date which will be used to get all data from the start of the year
	DECLARE @Year VARCHAR(4) = CAST(YEAR(@ApprovedAfter) AS VARCHAR(4));
	DECLARE @StartDate DATETIME2 = CAST(@Year + '-01-01' AS DATETIME2);	
	
	
	--This script results in a temporary table, #PeriodYearTable, populated with each period value prefixed by the specified year (e.g., 2024-P1, 2024-P4).
	CREATE TABLE #PeriodYearTable (Period VARCHAR(10));
	DECLARE @Delimiter CHAR(1) = ',';
	DECLARE @Pos INT;
	DECLARE @Token VARCHAR(10);
	DECLARE @PeriodValue VARCHAR(10);  -- Variable to hold the concatenated value

	SET @Periods = @Periods + ','; -- Add trailing comma for parsing
	SET @Pos = CHARINDEX(@Delimiter, @Periods);

	WHILE @Pos > 0
	BEGIN
		SET @Token = LTRIM(RTRIM(SUBSTRING(@Periods, 1, @Pos - 1))); -- Get the token
		SET @PeriodValue = @Year + '-' + @Token;  -- Concatenate into a single variable
		INSERT INTO #PeriodYearTable (Period) VALUES (@PeriodValue);  -- Insert the variable

		SET @Periods = SUBSTRING(@Periods, @Pos + 1, LEN(@Periods)); -- Update the string for the next iteration
		SET @Pos = CHARINDEX(@Delimiter, @Periods); -- Find the next delimiter
	END
	
	--get approved submissions from the start of the year
	SELECT SubmissionId, Created
    INTO #ApprovedSubmissions
    FROM [rpd].[SubmissionEvents]
    WHERE TRY_CAST([Created] AS datetime2) > @StartDate AND Decision = 'Accepted';
	

	--get most recent file id for approved submissions
    SELECT s.SubmissionId, se.FileId, se.Created as SubmissionApprovedDate, s.Created
    INTO #FileIdss
    FROM #ApprovedSubmissions s
    CROSS APPLY (
        SELECT TOP 1 se.FileId, se.Created
        FROM [rpd].[SubmissionEvents] se
        WHERE se.SubmissionId = s.SubmissionId
          AND se.FileId IS NOT NULL
        ORDER BY se.Created DESC
    ) se;
	
	--get filenames for fileid
	SELECT f.SubmissionId, fm.[FileName], f.Created
    INTO #FileNames
    FROM #FileIdss f
    JOIN [rpd].[cosmos_file_metadata] fm ON f.FileId = fm.FileId;
	
    --get latest approved submission pom details where submission period is the same year as startdate filter
    SELECT 
    p.submission_period AS SubmissionPeriod,
    p.packaging_material AS PackagingMaterial,
    p.organisation_id AS OrganisationId,
    MAX(f.Created) AS MaxCreated
    INTO #MaxCreated
    FROM #FileNames f
    JOIN [rpd].[Pom] p ON p.[FileName] = f.[FileName]
    WHERE LEFT(p.submission_period, 4) = @Year
    GROUP BY 
        p.submission_period,
        p.packaging_material,
        p.organisation_id;
		
	
    --gets duplicate materials for organisation id
	WITH Duplicates AS (
		SELECT OrganisationId, PackagingMaterial
		FROM #MaxCreated
		GROUP BY OrganisationId, PackagingMaterial
		HAVING COUNT(*) = 2
	),
	--gets all other information for each duplicate
	DuplicateMaterials AS (
		SELECT MC.OrganisationId, MC.PackagingMaterial, MC.MaxCreated, MC.SubmissionPeriod
		FROM #MaxCreated AS MC
		JOIN Duplicates AS D
		ON MC.OrganisationId = D.OrganisationId
		AND MC.PackagingMaterial = D.PackagingMaterial
	)
	--validate that duplicate materials for organisation have all the periods required to be valid
	SELECT dm.OrganisationId, dm.PackagingMaterial, dm.MaxCreated, p.period
	INTO #ValidDuplicateMaterials
	FROM #PeriodYearTable AS p
	JOIN DuplicateMaterials AS dm
	ON p.period = dm.SubmissionPeriod



    --aggregate material weight for each submission for each org id also aggregat PC and FC
    SELECT 
    CAST(f.SubmissionId AS uniqueidentifier) AS SubmissionId,
    p.submission_period AS SubmissionPeriod,
    CASE 
        WHEN p.packaging_material IN ('PC', 'FC') THEN 'PC'
        ELSE p.packaging_material
    END AS PackagingMaterial,
    SUM(p.packaging_material_weight) AS PackagingMaterialWeight,
    CAST(o.ExternalId AS uniqueidentifier) AS OrganisationId
    INTO #AggregatedMaterials
    FROM #FileNames f
    JOIN [rpd].[Pom] p 
    ON p.[FileName] = f.[FileName]
    JOIN #ValidDuplicateMaterials m 
    ON p.submission_period = m.[Period]
    AND p.packaging_material = m.PackagingMaterial
    AND p.organisation_id = m.OrganisationId
    AND f.Created = m.MaxCreated
    JOIN [rpd].[Organisations] o ON p.organisation_id = o.ReferenceNumber
    WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter
    GROUP BY 
    f.SubmissionId,
    p.submission_period,
    CASE 
        WHEN p.packaging_material IN ('PC', 'FC') THEN 'PC'
        ELSE p.packaging_material
    END,
    o.ExternalId;

	
	
	--aggregate duplicate materials weight for duplicate materials for org id
	SELECT 
	@Year AS SubmissionPeriod,  -- Hardcoded variable
	PackagingMaterial AS PackagingMaterial,
	SUM(PackagingMaterialWeight) AS PackagingMaterialWeight,
	OrganisationId
	FROM 
	#AggregatedMaterials
	GROUP BY 
	OrganisationId, 
	PackagingMaterial;


	DROP TABLE #ApprovedSubmissions;
	DROP TABLE #FileNames;
	DROP TABLE #MaxCreated;
	DROP TABLE #FileIdss;
	DROP TABLE #PeriodYearTable;
	DROP TABLE #ValidDuplicateMaterials;
	DROP TABLE #AggregatedMaterials;
END
GO
