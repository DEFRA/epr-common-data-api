-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetApprovedSubmissions]'))
DROP PROCEDURE [dbo].[sp_GetApprovedSubmissions];

-- Drop unused stored procedures
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataV2]'))
DROP PROCEDURE [rpd].[sp_GetApprovedSubmissionsWithAggregatedPomDataV2];
GO


CREATE PROC [dbo].[sp_GetApprovedSubmissions] @ApprovedAfter [DATETIME2],@Periods [VARCHAR](MAX),@IncludePackagingTypes [VARCHAR](MAX),@IncludePackagingMaterials [VARCHAR](MAX),@IncludeOrganisationSize [VARCHAR](MAX) AS
BEGIN

		DECLARE @start_dt datetime;
	DECLARE @batch_id INT;
	DECLARE @cnt int;

	select @batch_id  = ISNULL(max(batch_id),0)+1 from [dbo].[batch_log]
	set @start_dt = getdate();

-- Check if there are any approved submissions after the specified date
    IF EXISTS (
        SELECT 1
        FROM [rpd].[SubmissionEvents]
        WHERE TRY_CAST([Created] AS datetime2) >= @ApprovedAfter
        AND Decision = 'Accepted'
    )
    BEGIN
        SET NOCOUNT ON;

        -- Clean up temp tables
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
        IF OBJECT_ID('tempdb..#ValidOrganisations') IS NOT NULL DROP TABLE #ValidOrganisations;

        -- Get start date based on reporting packaging data rules
        DECLARE @StartDate DATETIME2 = DATEADD(MONTH, -7, DATEFROMPARTS(YEAR(GETDATE()), 1, 1));

        -- Declare parent type
        DECLARE @DirectRegistrantType NVARCHAR(50) = 'DirectRegistrant';
        DECLARE @ComplianceSchemeType NVARCHAR(50) = 'ComplianceScheme';


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

        -- This script results in a temp table, populated with each period value prefixed by the specified year (e.g., 2024-P2, 2024-P4) for a partial scenario
        DECLARE @PartialPeriod VARCHAR(10) = '2024-P2'; 
        DECLARE @NumberOfDaysInReportingPeriod INT = 91;
        DECLARE @NumberOfDaysInWholePeriod INT = 182;
        CREATE TABLE #PartialPeriodYearTableP2 (Period VARCHAR(10));
        INSERT INTO #PartialPeriodYearTableP2 (Period) VALUES (@PartialPeriod);
        INSERT INTO #PartialPeriodYearTableP2 (Period) VALUES ('2024-P4');

        -- This script results in a temp table, populated with each period value prefixed by the specified year (e.g., 2024-P3, 2024-P4) for a partial scenario
        DECLARE @PartialPeriodP3 VARCHAR(10) = '2024-P3'; 
        DECLARE @NumberOfDaysInReportingPeriodP3 INT = 61;
        CREATE TABLE #PartialPeriodYearTableP3 (Period VARCHAR(10));
        INSERT INTO #PartialPeriodYearTableP3 (Period) VALUES (@PartialPeriodP3);
        INSERT INTO #PartialPeriodYearTableP3 (Period) VALUES ('2024-P4');


        -- Step 1: Filter SubmissionEvents and cast
        WITH CleanedSubmissionEvents AS (
            SELECT
                SubmissionId,
                FileId,
                TRY_CAST(Created AS datetime2) AS Created,
                Decision
            FROM [rpd].[SubmissionEvents]
            WHERE TRY_CAST(Created AS datetime2) IS NOT NULL
        ),

        -- Step 2: Get latest approved submission per SubmissionId
        ApprovedSubmissions AS (
            SELECT 
                SubmissionId, 
                MAX(Created) AS Created
            FROM CleanedSubmissionEvents
            WHERE Created >= @StartDate
            AND Decision = 'Accepted'
            GROUP BY SubmissionId
        ),

        -- Step 3: Rank accepted files per submission by Created date
        RankedApprovedFiles AS (
            SELECT 
                se.SubmissionId,
                se.FileId,
                se.Created AS SubmissionApprovedDate,
                ROW_NUMBER() OVER (
                    PARTITION BY se.SubmissionId 
                    ORDER BY se.Created DESC
                ) AS rn
            FROM CleanedSubmissionEvents se
            WHERE se.FileId IS NOT NULL
            AND se.Decision = 'Accepted'
        )

        -- Step 4: Output latest file metadata per approved submission
        SELECT 
            a.SubmissionId,
            r.FileId,
            r.SubmissionApprovedDate,
            a.Created AS Created,
            fm.FileName,
            fm.Created AS FileCreated,
            fm.ComplianceSchemeId
        INTO #FileIdss
        FROM ApprovedSubmissions a
        JOIN RankedApprovedFiles r
            ON a.SubmissionId = r.SubmissionId
        JOIN [rpd].[cosmos_file_metadata] fm
            ON r.FileId = fm.FileId
        WHERE r.rn = 1;

        -- Step 5: Filter Pom data
        WITH FilteredPom AS (
            SELECT 
                p.[FileName],
                p.submission_period,
                p.packaging_material,
                p.packaging_material_weight,
                p.transitional_packaging_units,
                p.organisation_id,
                p.subsidiary_id,
                p.packaging_type
            FROM [rpd].[Pom] p
            WHERE LEFT(p.submission_period, 4) = @PeriodYear
            AND p.organisation_size IN (SELECT OrganisationSize FROM #IncludeOrganisationSizeTable)
        )

        -- Step 6: Get organisation numbers and compliance info
        SELECT 
            p.submission_period AS SubmissionPeriod,
            p.packaging_material AS PackagingMaterial,
            CASE
                WHEN NULLIF(TRIM(p.subsidiary_id), '') IS NULL THEN CAST(o.ExternalId AS UNIQUEIDENTIFIER)
                ELSE CAST(o2.ExternalId AS UNIQUEIDENTIFIER)
            END AS OrganisationId,
            f.Created AS Created,
            p.packaging_material_weight AS Weight,
            p.transitional_packaging_units AS TransitionalPackaging,
            p.organisation_id AS SixDigitOrgId,
            p.packaging_type AS PackType,
            CASE
                WHEN NULLIF(TRIM(f.ComplianceSchemeId), '') IS NULL THEN CAST(o.ExternalId AS UNIQUEIDENTIFIER)
                ELSE f.ComplianceSchemeId
            END AS SubmitterId,
            CASE
                WHEN NULLIF(TRIM(f.ComplianceSchemeId), '') IS NULL THEN @DirectRegistrantType
                ELSE @ComplianceSchemeType
            END AS SubmitterType
        INTO #FilteredByApproveAfterYear
        FROM #FileIdss f
        INNER JOIN FilteredPom p 
            ON f.FileName = p.FileName
        INNER JOIN [rpd].[Organisations] o 
            ON p.organisation_id = o.ReferenceNumber
        LEFT JOIN [rpd].[Organisations] o2 
            ON NULLIF(TRIM(p.subsidiary_id), '') = o2.ReferenceNumber;


     -- Step 7: Identify eligible organisations per period group
        WITH 
        PeriodGroup1 AS (
            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE SubmissionPeriod IN (SELECT Period FROM #PeriodYearTable)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PeriodYearTable)
        ),
        PeriodGroup2 AS (
            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE SubmissionPeriod IN (SELECT Period FROM #PartialPeriodYearTableP2)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP2)
        ),
        PeriodGroup3 AS (
            SELECT OrganisationId
            FROM #FilteredByApproveAfterYear
            WHERE SubmissionPeriod IN (SELECT Period FROM #PartialPeriodYearTableP3)
            GROUP BY OrganisationId
            HAVING COUNT(DISTINCT SubmissionPeriod) = (SELECT COUNT(*) FROM #PartialPeriodYearTableP3)
        ),
        AllQualifiedOrgs AS (
            SELECT DISTINCT OrganisationId FROM PeriodGroup1
            UNION
            SELECT OrganisationId FROM PeriodGroup2
            UNION
            SELECT OrganisationId FROM PeriodGroup3
        ),

        -- rank submitters per organisation and prefer the one that has both periods
        RankedSubmitters AS (
            SELECT 
                f.OrganisationId,
                f.SubmitterId,
                COUNT(DISTINCT f.SubmissionPeriod) AS PeriodCount
            FROM #FilteredByApproveAfterYear f
            INNER JOIN AllQualifiedOrgs q
                ON f.OrganisationId = q.OrganisationId
            GROUP BY f.OrganisationId, f.SubmitterId
        ),
        PreferredSubmitter AS (
            SELECT OrganisationId, SubmitterId
            FROM RankedSubmitters
            WHERE PeriodCount = 2  
        ),

        -- Step 8: Apply packaging material/type filters
        FilteredApprovedSubmissions AS (
            SELECT 
                f.OrganisationId,
                f.Created,
                f.PackagingMaterial,
                f.PackType,
                f.SixDigitOrgId,
                f.SubmissionPeriod,
                f.Weight,
                f.TransitionalPackaging,
                f.SubmitterId,
                f.SubmitterType
            FROM #FilteredByApproveAfterYear f
            INNER JOIN PreferredSubmitter ps  
                ON f.OrganisationId = ps.OrganisationId
               AND f.SubmitterId    = ps.SubmitterId
            WHERE f.PackagingMaterial IN (SELECT * FROM #IncludePackagingMaterialsTable)
            AND f.PackType IN (SELECT * FROM #IncludePackagingTypesTable)
        )

        -- Step 9: Save filtered results
        SELECT *
        INTO #FilteredApprovedSubmissions
        FROM FilteredApprovedSubmissions;

        -- Step 10: Build all relevant periods
        WITH AllPeriods AS (
            SELECT Period FROM #PeriodYearTable
            UNION
            SELECT Period FROM #PartialPeriodYearTableP2
            UNION
            SELECT Period FROM #PartialPeriodYearTableP3
        ),
        FilteredValidSubmissions AS (
            SELECT *
            FROM #FilteredApprovedSubmissions f
            WHERE EXISTS (
                SELECT 1 
                FROM AllPeriods ap
                WHERE ap.Period = f.SubmissionPeriod
            )
        ),
        LatestDates AS (
            SELECT 
                SubmissionPeriod,
                PackagingMaterial, 
                OrganisationId, 
                MAX(Created) AS LatestDate
            FROM FilteredValidSubmissions
            GROUP BY 
                SubmissionPeriod, 
                PackagingMaterial,
                OrganisationId
        )

        -- Step 11: Store latest dates
        SELECT *
        INTO #LatestDates
        FROM LatestDates;

        -- Step 12: Aggregate latest weight and units
        SELECT 
            f.SubmissionPeriod, 
            f.PackagingMaterial, 
            f.OrganisationId,
            ld.LatestDate,
            SUM(f.Weight) AS Weight,
            SUM(f.TransitionalPackaging) AS TransitionalPackaging,
            f.SixDigitOrgId,
            f.SubmitterId,
            f.SubmitterType
        INTO #AggregatedWeightsForDuplicates
        FROM #FilteredApprovedSubmissions f
        INNER JOIN #LatestDates ld
            ON f.SubmissionPeriod = ld.SubmissionPeriod
            AND f.PackagingMaterial = ld.PackagingMaterial
            AND f.OrganisationId = ld.OrganisationId
            AND f.Created = ld.LatestDate
        GROUP BY 
            f.SubmissionPeriod, 
            f.PackagingMaterial, 
            f.OrganisationId, 
            ld.LatestDate,
            f.SixDigitOrgId,
            f.SubmitterId,
            f.SubmitterType;

        -- Step 13: Identify orgs with submissions after ApprovedAfter
        SELECT DISTINCT 
            p.organisation_id
        INTO #ValidOrganisations
        FROM #FileIdss f
        INNER JOIN [rpd].[Pom] p ON p.FileName = f.FileName
        WHERE TRY_CAST(f.Created AS datetime2) >= @ApprovedAfter;

        -- Step 14: Build final aggregation
        SELECT DISTINCT
            CAST(f.SubmissionId AS UNIQUEIDENTIFIER) AS SubmissionId,
            p.submission_period AS SubmissionPeriod,
            p.packaging_material AS PackagingMaterial,
            aw.Weight AS PackagingMaterialWeight,
            aw.TransitionalPackaging,
            aw.OrganisationId,
            aw.SubmitterId,
            aw.SubmitterType
        INTO #AggregatedMaterials
        FROM #FileIdss f
        INNER JOIN [rpd].[Pom] p 
            ON p.FileName = f.FileName
        INNER JOIN #AggregatedWeightsForDuplicates aw
            ON p.submission_period = aw.SubmissionPeriod
            AND p.packaging_material = aw.PackagingMaterial
            AND p.organisation_id = aw.SixDigitOrgId
            AND f.Created = aw.LatestDate
        INNER JOIN [rpd].[Organisations] o 
            ON p.organisation_id = o.ReferenceNumber
        WHERE p.organisation_id IN (SELECT organisation_id FROM #ValidOrganisations);

        -- Step 15: Handle Partial
        UPDATE #AggregatedMaterials
        SET PackagingMaterialWeight = CASE 
            WHEN SubmissionPeriod = @PartialPeriod 
                THEN ROUND((PackagingMaterialWeight * @NumberOfDaysInWholePeriod) / @NumberOfDaysInReportingPeriod, 0)
            WHEN SubmissionPeriod = @PartialPeriodP3 
                THEN ROUND((PackagingMaterialWeight * @NumberOfDaysInWholePeriod) / @NumberOfDaysInReportingPeriodP3, 0)
            ELSE PackagingMaterialWeight
        END
        WHERE SubmissionPeriod IN (@PartialPeriod, @PartialPeriodP3);

        -- Step 16: Final rollup
        SELECT 
            @PeriodYear AS SubmissionPeriod,
            PackagingMaterial,
            CAST(
                ROUND(
                    (SUM(PackagingMaterialWeight) - COALESCE(SUM(TransitionalPackaging), 0)) / 1000.0, 
                    0
                ) AS INT
            ) AS PackagingMaterialWeight,
            OrganisationId,
            SubmitterId,
            SubmitterType
        FROM 
            #AggregatedMaterials
        GROUP BY 
            OrganisationId, 
            PackagingMaterial,
            SubmitterId,
            SubmitterType;

    END
    ELSE
    BEGIN
        -- Return an empty result set with the expected schema
        SELECT 
            CAST(NULL AS VARCHAR(10)) AS SubmissionPeriod,
            CAST(NULL AS VARCHAR(50)) AS PackagingMaterial,
            CAST(NULL AS FLOAT) AS PackagingMaterialWeight,
            CAST(NULL AS UNIQUEIDENTIFIER) AS OrganisationId,
            CAST(NULL AS UNIQUEIDENTIFIER) AS SubmitterId,
            CAST(NULL AS VARCHAR(50)) AS SubmitterType
        WHERE 1 = 0; -- Ensures no rows are returned
    END

	INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
	select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'dbo.sp_GetApprovedSubmissions',@ApprovedAfter, NULL, @start_dt, getdate(), '@ApprovedAfter',@batch_id
END


