-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetApprovedSubmissions]'))
DROP PROCEDURE [dbo].[sp_GetApprovedSubmissions];
GO

-- Drop unused stored procedures
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataV2]'))
DROP PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataV2];
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataIncludingPartialV3]'))
DROP PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataIncludingPartialV3];
GO

CREATE PROC [dbo].[sp_GetApprovedSubmissions] @ApprovedAfter [DATETIME2],@Periods [VARCHAR](MAX),@IncludePackagingTypes [VARCHAR](MAX),@IncludePackagingMaterials [VARCHAR](MAX),@IncludeOrganisationSize [VARCHAR](MAX) AS
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

        -- Clean up any pre-existing temp tables
        IF OBJECT_ID('tempdb..#ApprovedSubmissions') IS NOT NULL DROP TABLE #ApprovedSubmissions;
        IF OBJECT_ID('tempdb..#FileIdss') IS NOT NULL DROP TABLE #FileIdss;
        IF OBJECT_ID('tempdb..#FileNames') IS NOT NULL DROP TABLE #FileNames;
        IF OBJECT_ID('tempdb..#MaxCreated') IS NOT NULL DROP TABLE #MaxCreated;
        IF OBJECT_ID('tempdb..#PeriodYearTable') IS NOT NULL DROP TABLE #PeriodYearTable;
        IF OBJECT_ID('tempdb..#IncludePackagingTypesTable') IS NOT NULL DROP TABLE #IncludePackagingTypesTable;
        IF OBJECT_ID('tempdb..#IncludePackagingMaterialsTable') IS NOT NULL DROP TABLE #IncludePackagingMaterialsTable;
        IF OBJECT_ID('tempdb..#PartialPeriodYearTableP2') IS NOT NULL DROP TABLE #PartialPeriodYearTableP2;
        IF OBJECT_ID('tempdb..#PartialPeriodYearTableP3') IS NOT NULL DROP TABLE #PartialPeriodYearTableP3;
        IF OBJECT_ID('tempdb..#FilteredByApproveAfterYear') IS NOT NULL DROP TABLE #FilteredByApproveAfterYear;
        IF OBJECT_ID('tempdb..#FilteredOrgIdsForH1H2') IS NOT NULL DROP TABLE #FilteredOrgIdsForH1H2;
        IF OBJECT_ID('tempdb..#FilteredApprovedSubmissions') IS NOT NULL DROP TABLE #FilteredApprovedSubmissions;
        IF OBJECT_ID('tempdb..#AllPeriods') IS NOT NULL DROP TABLE #AllPeriods;
        IF OBJECT_ID('tempdb..#LatestDates') IS NOT NULL DROP TABLE #LatestDates;
        IF OBJECT_ID('tempdb..#AggregatedWeightsForDuplicates') IS NOT NULL DROP TABLE #AggregatedWeightsForDuplicates;
        IF OBJECT_ID('tempdb..#AggregatedMaterials') IS NOT NULL DROP TABLE #AggregatedMaterials;
        IF OBJECT_ID('tempdb..#IncludeOrganisationSizeTable') IS NOT NULL DROP TABLE #IncludeOrganisationSizeTable;


        -- Get start date for the current year
        DECLARE @StartDate DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);

        -- Create temporary tables
        CREATE TABLE #PeriodYearTable (Period VARCHAR(10));
        CREATE TABLE #IncludePackagingTypesTable (PackagingType VARCHAR(10));
        CREATE TABLE #IncludePackagingMaterialsTable (PackagingMaterials VARCHAR(10));
        CREATE TABLE #IncludeOrganisationSizeTable (OrganisationSize VARCHAR(10));

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

        WITH CTE_Split_IncludeOrganisation AS (
        SELECT value AS OrganisationSize FROM STRING_SPLIT(@IncludeOrganisationSize, @Delimiter)
        )
        INSERT INTO #IncludeOrganisationSizeTable (OrganisationSize)
        SELECT OrganisationSize FROM CTE_Split_IncludeOrganisation;

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
        
        --Get approved pom files by year
        SELECT 
        p.submission_period AS SubmissionPeriod,
        p.packaging_material AS PackagingMaterial,
            CASE
                WHEN p.subsidiary_id IS NULL THEN CAST(o.ExternalId AS uniqueidentifier)
                ELSE CAST(o2.ExternalId AS uniqueidentifier)
            END AS OrganisationId,
        f.Created AS Created,
        p.packaging_material_weight as weight,
        p.transitional_packaging_units as TransitionalPackaging,
        p.organisation_id AS SixDigitOrgId,
        p.packaging_type as PackType
        INTO #FilteredByApproveAfterYear
        FROM #FileNames f
        JOIN [rpd].[Pom] p ON p.[FileName] = f.[FileName]
        JOIN [rpd].[Organisations] o ON p.organisation_id = o.ReferenceNumber
        left JOIN [rpd].[Organisations] o2 ON p.subsidiary_id = o2.ReferenceNumber
        WHERE LEFT(p.submission_period, 4) = @PeriodYear 
        AND p.organisation_size IN (SELECT * FROM #IncludeOrganisationSizeTable); 


        --Filter organisation ID that have H1 and H2 
        SELECT DISTINCT FA.OrganisationId
        INTO #FilteredOrgIdsForH1H2
        FROM #FilteredByApproveAfterYear FA
        WHERE FA.OrganisationId IN (
            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE submissionPeriod IN (SELECT Period FROM #PeriodYearTable)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT submissionPeriod) = (SELECT COUNT(*) FROM #PeriodYearTable)

            UNION

            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE submissionPeriod IN (SELECT Period FROM #PartialPeriodYearTableP2)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT submissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP2)

            UNION

            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE submissionPeriod IN (SELECT Period FROM #PartialPeriodYearTableP3)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT submissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP3)
        );


        --Use H1H2 organisation ids to filter approved submission POM files, also exclude unwanted packaging materials and packaging types
        SELECT f.OrganisationId, f.Created, f.PackagingMaterial, f.PackType, f.SixDigitOrgId, f.SubmissionPeriod, f.weight, f.TransitionalPackaging
        INTO #FilteredApprovedSubmissions
        FROM #FilteredByApproveAfterYear f
        JOIN #FilteredOrgIdsForH1H2 h1h2 ON f.OrganisationId = h1h2.OrganisationId
        WHERE f.PackagingMaterial IN (SELECT * FROM #IncludePackagingMaterialsTable)
        AND f.PackType IN (SELECT * FROM #IncludePackagingTypesTable); 


        --Get all Periods including partial periods
        SELECT DISTINCT Period
        INTO #AllPeriods
        FROM (
            SELECT Period FROM #PeriodYearTable
            UNION
            SELECT Period FROM #PartialPeriodYearTableP2
            UNION
            SELECT Period FROM #PartialPeriodYearTableP3
        ) AS Combined;

        --remove all invalid periods
        DELETE FROM #FilteredApprovedSubmissions
        WHERE NOT EXISTS (
            SELECT 1 
            FROM #AllPeriods ap
            WHERE ap.Period = #FilteredApprovedSubmissions.SubmissionPeriod
        );


        -- Step 1: Filter the latest duplicate OrganisationId, SubmissionPeriod, and PackagingMaterial
        SELECT 
            SubmissionPeriod,
            PackagingMaterial, 
            OrganisationId, 
            MAX(Created) AS LatestDate
        INTO 
            #LatestDates
        FROM 
            #FilteredApprovedSubmissions
        GROUP BY 
            SubmissionPeriod, 
            PackagingMaterial,
            OrganisationId;



        -- Step 2: Aggregate weight for each unique combination of OrganisationId, SubmissionPeriod, and PackagingMaterial
        SELECT 
            a.SubmissionPeriod, 
            a.PackagingMaterial, 
            a.OrganisationId,
            ld.LatestDate,
            SUM(a.Weight) AS Weight,
            SUM(a.TransitionalPackaging) AS TransitionalPackaging,
            a.SixDigitOrgId AS SixDigitOrgId
        INTO
            #AggregatedWeightsForDuplicates            
        FROM 
            #FilteredApprovedSubmissions AS a
        JOIN 
            #LatestDates AS ld
        ON 
            a.PackagingMaterial = ld.PackagingMaterial
            AND a.SubmissionPeriod = ld.SubmissionPeriod
            AND a.OrganisationId = ld.OrganisationId
            AND a.Created = ld.LatestDate
        GROUP BY 
            a.SubmissionPeriod, 
            a.PackagingMaterial, 
            a.OrganisationId, 
            ld.LatestDate,
            a.SixDigitOrgId;


        -- Get Real organisation Id and also get the data that has data after approved date
        SELECT DISTINCT
            CAST(f.SubmissionId AS uniqueidentifier) AS SubmissionId,
            p.submission_period AS SubmissionPeriod,
            p.packaging_material AS PackagingMaterial,
            m.Weight AS PackagingMaterialWeight,
            m.TransitionalPackaging AS TransitionalPackaging,
            m.OrganisationId AS OrganisationId
        INTO #AggregatedMaterials
        FROM #FileNames f
        JOIN [rpd].[Pom] p 
            ON p.[FileName] = f.[FileName]
        JOIN #AggregatedWeightsForDuplicates m 
            ON p.submission_period = m.SubmissionPeriod
            AND p.packaging_material = m.PackagingMaterial
            AND p.organisation_id = m.SixDigitOrgId
            AND f.Created = m.LatestDate
        JOIN [rpd].[Organisations] o 
            ON p.organisation_id = o.ReferenceNumber
        WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter


        -- Update PackagingMaterialWeight for records with SubmissionPeriod '2024-P2' or '2024-P3' - which is partial data and round to the nearest whole number
        UPDATE #AggregatedMaterials
        SET PackagingMaterialWeight =
            CASE 
                WHEN SubmissionPeriod = @PartialPeriod THEN ROUND(((PackagingMaterialWeight/@NumberOfDaysInReportingPeriod) * @NumberOfDaysInWholePeriod), 0)
                WHEN SubmissionPeriod = @PartialPeriodP3 THEN ROUND(((PackagingMaterialWeight/@NumberOfDaysInReportingPeriodP3) * @NumberOfDaysInWholePeriod), 0)
                ELSE 1 -- No adjustment for other periods
            END
        WHERE SubmissionPeriod IN (@PartialPeriod, @PartialPeriodP3);


        --Need  to minus transitional packaging


        -- Aggregate duplicate materials weight for duplicate materials for org id
        SELECT 
            @PeriodYear AS SubmissionPeriod,
            PackagingMaterial,
            CAST(
                CASE 
                    WHEN SUM(TransitionalPackaging) IS NULL 
                    THEN ROUND(SUM(PackagingMaterialWeight) / 1000, 0)
                    ELSE ROUND((SUM(PackagingMaterialWeight) - COALESCE(SUM(TransitionalPackaging), 0)) / 1000, 0)
                END AS INT
            ) AS PackagingMaterialWeight, 
            OrganisationId
        FROM 
            #AggregatedMaterials
        GROUP BY 
            OrganisationId, 
            PackagingMaterial;

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
