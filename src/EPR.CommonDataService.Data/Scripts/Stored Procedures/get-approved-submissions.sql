-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissions]'))
DROP PROCEDURE [rpd].[sp_GetApprovedSubmissions];
GO

CREATE PROC [rpd].[sp_GetApprovedSubmissions] @ApprovedAfter [DATETIME2],@Periods [VARCHAR](MAX),@IncludePackagingTypes [VARCHAR](MAX),@IncludePackagingMaterials [VARCHAR](MAX) AS
BEGIN

    -- Check if there are any approved submissions after the specified date
    IF EXISTS (
        SELECT 1
        FROM [rpd].[SubmissionEvents]
        WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter
        AND Decision = 'Accepted'
    )
    BEGIN
        SET NOCOUNT ON;
        IF OBJECT_ID('tempdb..#ApprovedSubmissions') IS NOT NULL
            DROP TABLE #ApprovedSubmissions;

        IF OBJECT_ID('tempdb..#FileIdss') IS NOT NULL
            DROP TABLE #FileIdss;

        IF OBJECT_ID('tempdb..#FileNames') IS NOT NULL
            DROP TABLE #FileNames;

        IF OBJECT_ID('tempdb..#MaxCreated') IS NOT NULL
            DROP TABLE #MaxCreated;
            
        IF OBJECT_ID('tempdb..#PeriodYearTable') IS NOT NULL
            DROP TABLE #PeriodYearTable;	

        IF OBJECT_ID('tempdb..#DuplicateMaterials') IS NOT NULL
        DROP TABLE #DuplicateMaterials;	   

        -- Get start date for the current year
        DECLARE @StartDate DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);

        -- Create temporary tables
        CREATE TABLE #PeriodYearTable (Period VARCHAR(10));
        CREATE TABLE #IncludePackagingTypesTable (PackagingType VARCHAR(10));
        CREATE TABLE #IncludePackagingMaterialsTable (PackagingMaterials VARCHAR(10));

        -- Generic procedure to split a delimited string and insert into a given table
        DECLARE @Delimiter CHAR(1) = ',';

        WITH CTE_Split AS (
        SELECT value AS Period FROM STRING_SPLIT(@Periods, @Delimiter)
        )
        INSERT INTO #PeriodYearTable (Period)
        SELECT Period FROM CTE_Split;

        WITH CTE_Split_IncludePT AS (
        SELECT value AS PackagingType FROM STRING_SPLIT(@IncludePackagingTypes, @Delimiter)
        )
        INSERT INTO #IncludePackagingTypesTable (PackagingType)
        SELECT PackagingType FROM CTE_Split_IncludePT;

        WITH CTE_Split_Include AS (
        SELECT value AS PackagingMaterials FROM STRING_SPLIT(@IncludePackagingMaterials, @Delimiter)
        )
        INSERT INTO #IncludePackagingMaterialsTable (PackagingMaterials)
        SELECT PackagingMaterials FROM CTE_Split_Include;


        DECLARE @PeriodYear VARCHAR(4);
        -- Get the year from the first period
        SET @PeriodYear = (SELECT TOP 1 LEFT(Period, 4) FROM #PeriodYearTable);


        --This script results in a temp table, populated with each period value prefixed by the specified year (e.g., 2024-P2, 2024-P4) for a partial scenario
        DECLARE @PartialPeriod VARCHAR(10) = '2024-P2'; 
        DECLARE @NumberOfDaysInReportingPeriod INT = 91;
        DECLARE @NumberOfDaysInWholePeriod INT = 182;
        CREATE TABLE #PartialPeriodYearTableP2 (Period VARCHAR(10));
        INSERT INTO #PartialPeriodYearTableP2 (Period) VALUES (@PartialPeriod);
        INSERT INTO #PartialPeriodYearTableP2 (Period) VALUES ('2024-P4');

        --This script results in a temp table, populated with each period value prefixed by the specified year (e.g., 2024-P3, 2024-P4) for a partial scenario
        DECLARE @PartialPeriodP3 VARCHAR(10) = '2024-P3'; 
        DECLARE @NumberOfDaysInReportingPeriodP3 INT = 61;
        CREATE TABLE #PartialPeriodYearTableP3 (Period VARCHAR(10));
        INSERT INTO #PartialPeriodYearTableP3 (Period) VALUES (@PartialPeriodP3);
        INSERT INTO #PartialPeriodYearTableP3 (Period) VALUES ('2024-P4');
        
        --get approved submissions from the start of the year
        SELECT DISTINCT SubmissionId, Max(Created) As Created 
        INTO #ApprovedSubmissions
        FROM [rpd].[SubmissionEvents] WHERE TRY_CAST([Created] AS datetime2) > @StartDate AND Decision = 'Accepted'
        GROUP BY SubmissionId;

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
        SELECT f.SubmissionId, fm.[FileName], f.Created, fm.ComplianceSchemeId
        INTO #FileNames
        FROM #FileIdss f
        JOIN [rpd].[cosmos_file_metadata] fm ON f.FileId = fm.FileId;
        
        -- Get Organisation Id for Compliance Scheme and producer but keep original 6 digit orgId column -(SixDigitOrgId)
        SELECT fn.SubmissionId, fn.FileName, fn.Created, fn.ComplianceSchemeId,
            CASE 
                WHEN fn.ComplianceSchemeId IS NULL THEN NULL
                ELSE org.ExternalId
            END AS ComplianceOrgId
        INTO #EnhancedFileNames
        FROM #FileNames fn
        LEFT JOIN [rpd].[ComplianceSchemes] cs
        ON fn.ComplianceSchemeId = cs.ExternalId
        LEFT JOIN [rpd].[Organisations] org
        ON cs.CompaniesHouseNumber = org.CompaniesHouseNumber;

        SELECT 
        p.submission_period AS SubmissionPeriod,
        p.packaging_material AS PackagingMaterial,
            CASE
                WHEN p.subsidiary_id IS NULL THEN CAST(o.ExternalId AS uniqueidentifier)
                ELSE CAST(o2.ExternalId AS uniqueidentifier)
            END AS OrganisationId,
        f.Created AS Created,
        p.packaging_material_weight as weight,
        p.organisation_id AS SixDigitOrgId,
        p.packaging_type as PackType
        INTO #FilteredByApproveAfterYear
        FROM #FileNames f
        JOIN [rpd].[Pom] p ON p.[FileName] = f.[FileName]
        JOIN [rpd].[Organisations] o ON p.organisation_id = o.ReferenceNumber
        left JOIN [rpd].[Organisations] o2 ON p.subsidiary_id = o2.ReferenceNumber
        WHERE LEFT(p.submission_period, 4) = @PeriodYear 
        AND p.packaging_material IN (SELECT * FROM #IncludePackagingMaterialsTable)
        AND p.packaging_type IN (SELECT * FROM #IncludePackagingTypesTable); 


        -- Step 1: Filter the latest duplicate OrganisationId, SubmissionPeriod, and PackagingMaterial
        SELECT 
            SubmissionPeriod,
            CASE 
                WHEN PackagingMaterial IN ('PC', 'FC') THEN 'PC'
                ELSE PackagingMaterial
            END AS PackagingMaterial, 
            OrganisationId, 
            MAX(Created) AS LatestDate
        INTO 
            #LatestDates
        FROM 
            #FilteredByApproveAfterYear
        GROUP BY 
            SubmissionPeriod, 
            CASE 
                WHEN PackagingMaterial IN ('PC', 'FC') THEN 'PC'
                ELSE PackagingMaterial
            END,
            OrganisationId;

        -- Step 2: Aggregate weight for each unique combination of OrganisationId, SubmissionPeriod, and PackagingMaterial (with "PC" and "FC" treated as "PC")
        SELECT 
            a.SubmissionPeriod, 
            CASE 
                WHEN a.PackagingMaterial IN ('PC', 'FC') THEN 'PC'
                ELSE a.PackagingMaterial
            END AS PackagingMaterial, 
            a.OrganisationId,
            ld.LatestDate,
            SUM(a.Weight) AS Weight,
            a.SixDigitOrgId AS SixDigitOrgId
        INTO
            #AggregatedWeightsForDuplicates
        FROM 
            #FilteredByApproveAfterYear AS a
        JOIN 
            #LatestDates AS ld
        ON 
            CASE 
                WHEN a.PackagingMaterial IN ('PC', 'FC') THEN 'PC'
                ELSE a.PackagingMaterial
            END = ld.PackagingMaterial
            AND a.SubmissionPeriod = ld.SubmissionPeriod
            AND a.OrganisationId = ld.OrganisationId
            AND a.Created = ld.LatestDate
        GROUP BY 
            a.SubmissionPeriod, 
            CASE 
                WHEN a.PackagingMaterial IN ('PC', 'FC') THEN 'PC'
                ELSE a.PackagingMaterial
            END, 
            a.OrganisationId, 
            ld.LatestDate,
            a.SixDigitOrgId;

        -- Step 1: Identify duplicate materials based on #PeriodYearTable
        SELECT OrganisationId, PackagingMaterial
        INTO #DuplicateMaterials
        FROM #AggregatedWeightsForDuplicates
        WHERE SubmissionPeriod IN (SELECT period FROM #PeriodYearTable)
        GROUP BY OrganisationId, PackagingMaterial
        HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PeriodYearTable);

        -- Step 2: Insert valid records into #ValidDuplicateMaterials based on #DuplicateMaterials
        SELECT mc.OrganisationId, mc.PackagingMaterial, mc.LatestDate, mc.SubmissionPeriod, mc.Weight, mc.SixDigitOrgId
        INTO #ValidDuplicateMaterials
        FROM #AggregatedWeightsForDuplicates AS mc
        JOIN #DuplicateMaterials AS dm
        ON mc.OrganisationId = dm.OrganisationId
        AND mc.PackagingMaterial = dm.PackagingMaterial
        WHERE mc.SubmissionPeriod IN (SELECT period FROM #PeriodYearTable);

        -- Step 1: Identify Partial duplicate materials based on #PartialPeriodYearTableP2 and #PartialPeriodYearTableP3 and combine them
        SELECT OrganisationId, PackagingMaterial, TotalWeight AS Weight
        INTO #PartialDuplicateMaterials
        FROM (
            SELECT OrganisationId, PackagingMaterial, SUM (Weight) AS TotalWeight
            FROM #AggregatedWeightsForDuplicates
            WHERE SubmissionPeriod IN (SELECT period FROM #PartialPeriodYearTableP2)
            GROUP BY OrganisationId, PackagingMaterial
            HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP2)

            UNION

            SELECT OrganisationId, PackagingMaterial, SUM (Weight) AS TotalWeight
            FROM #AggregatedWeightsForDuplicates
            WHERE SubmissionPeriod IN (SELECT period FROM #PartialPeriodYearTableP3)
            GROUP BY OrganisationId, PackagingMaterial
            HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP3)
        ) CombinedData;

        -- Step 3: Insert valid partial records into #ValidDuplicateMaterials based on #PartialDuplicateMaterials so now should contain full years data and partial data
        INSERT INTO #ValidDuplicateMaterials (OrganisationId, PackagingMaterial, LatestDate, SubmissionPeriod, Weight, SixDigitOrgId)
        SELECT mc.OrganisationId, mc.PackagingMaterial, mc.LatestDate, mc.SubmissionPeriod, mc.Weight, mc.SixDigitOrgId
        FROM #AggregatedWeightsForDuplicates AS mc
        JOIN #PartialDuplicateMaterials AS dm
        ON mc.OrganisationId = dm.OrganisationId
        AND mc.PackagingMaterial = dm.PackagingMaterial;

        -- Get Real organisation Id and also get the data that has data after approved date
        SELECT DISTINCT
            CAST(f.SubmissionId AS uniqueidentifier) AS SubmissionId,
            p.submission_period AS SubmissionPeriod,
            p.packaging_material AS PackagingMaterial,
            m.Weight AS PackagingMaterialWeight,
            m.OrganisationId AS OrganisationId
        INTO #AggregatedMaterials
        FROM #FileNames f
        JOIN [rpd].[Pom] p 
            ON p.[FileName] = f.[FileName]
        JOIN #ValidDuplicateMaterials m 
            ON p.submission_period = m.SubmissionPeriod
            AND p.packaging_material = m.PackagingMaterial
            AND p.organisation_id = m.SixDigitOrgId
            AND f.Created = m.LatestDate
        JOIN [rpd].[Organisations] o 
            ON p.organisation_id = o.ReferenceNumber
        WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter

        -- Update PackagingMaterialWeight for records with SubmissionPeriod '2024-P2' or '2024-P3' - which is partial data and round to the nearest whole number
        UPDATE #AggregatedMaterials
        SET PackagingMaterialWeight = ROUND(
            PackagingMaterialWeight * 
            CASE 
                WHEN SubmissionPeriod = @PartialPeriod THEN (CAST(@NumberOfDaysInWholePeriod AS FLOAT) / @NumberOfDaysInReportingPeriod)
                WHEN SubmissionPeriod = @PartialPeriodP3 THEN (CAST(@NumberOfDaysInWholePeriod AS FLOAT) / @NumberOfDaysInReportingPeriodP3)
                ELSE 1 -- No adjustment for other periods
            END, 0) -- Round to 0 decimal places
        WHERE SubmissionPeriod IN (@PartialPeriod, @PartialPeriodP3);



        --aggregate duplicate materials weight for duplicate materials for org id
        SELECT 
        @PeriodYear AS SubmissionPeriod,  -- Hardcoded variable
        PackagingMaterial AS PackagingMaterial,
        ROUND(SUM(PackagingMaterialWeight) / 1000.0, 0) AS PackagingMaterialWeight,
        OrganisationId
        FROM 
        #AggregatedMaterials
        GROUP BY 
        OrganisationId, 
        PackagingMaterial;


        DROP TABLE #ApprovedSubmissions;
        DROP TABLE #FileNames;
        DROP TABLE #FileIdss;
        DROP TABLE #PeriodYearTable;
        DROP TABLE #PartialPeriodYearTableP2;
        DROP TABLE #PartialPeriodYearTableP3;
        DROP TABLE #LatestDates;
        DROP TABLE #AggregatedWeightsForDuplicates;
        DROP TABLE #FilteredByApproveAfterYear;
        DROP TABLE #DuplicateMaterials;
        DROP TABLE #PartialDuplicateMaterials;
        DROP TABLE #ValidDuplicateMaterials;
        DROP TABLE #AggregatedMaterials;
        DROP TABLE #EnhancedFileNames;
        DROP TABLE #ExcludePackagingTypesTable;
        DROP TABLE #IncludePackagingMaterialsTable;


    END
    ELSE
    BEGIN
        -- Return an empty result set with the expected schema
        SELECT 
            CAST(NULL AS VARCHAR(10)) AS SubmissionPeriod,
            CAST(NULL AS VARCHAR(50)) AS PackagingMaterial,
            CAST(NULL AS FLOAT) AS PackagingMaterialWeight,
            CAST(NULL AS UNIQUEIDENTIFIER) AS OrganisationId
        WHERE 1 = 0; -- Ensures no rows are returned
    END
END
GO

