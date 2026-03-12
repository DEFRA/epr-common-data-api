IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetPaycalPomData]'))
	DROP PROCEDURE [dbo].[sp_GetPaycalPomData];
GO

CREATE PROCEDURE [dbo].[sp_GetPaycalPomData] @SubmissionPeriodYear INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_dt DATETIME;
    DECLARE @batch_id INT;

    SELECT @batch_id = ISNULL(MAX(batch_id), 0) + 1
    FROM [dbo].[batch_log]

    SET @start_dt = GETDATE();
    
    BEGIN
        ----Find latest Registration file with data submitted for a given organisation--
        --ST006
        WITH latest_accepted_registration AS (
        SELECT * FROM (
            SELECT DISTINCT
            cfm.filename
            , cd.organisation_id
            --ST004 Updated logic to determine the latest accepted file submission with data for a given organisation
            , row_number() over(
                partition by cd.organisation_id, coalesce(cfm.ComplianceSchemeId, o.ExternalId), cfm.SubmissionPeriod
                order by cfm.created desc
            ) as latest_producer_accepted_record_per_SP
            , Right(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod),4) as Submission_Period_Year
            FROM [rpd].[CompanyDetails] cd
            INNER JOIN rpd.Organisations o
            on o.ReferenceNumber = cd.organisation_id
            --Excluding soft deleted organisations
            AND o.IsDeleted = 0
            INNER JOIN [rpd].[cosmos_file_metadata] cfm
            on cfm.FileName = cd.FileName
            --ST003 Restricting the extraction to just Registration files (Excluding older Org type files)
            AND Right(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod),4) > 2024
            -- Only considering Granted files--
            INNER JOIN dbo.v_submitted_pom_org_file_status sofs
            ON sofs.cfm_fileid = cfm.fileid
            AND sofs.filetype = 'CompanyDetails'
            --ST007 Added Accepted Status to cater for resubmission registration files
            AND sofs.Regulator_Status IN ('Granted','Accepted')
        ) a
        WHERE latest_producer_accepted_record_per_SP = 1
        ),
        ----Find latest POM file with data submitted for a given organisation--
        latest_accepted_pom AS (
        SELECT * FROM (
            SELECT
            p.organisation_id
            , cfm.[FileName]
            , p.submission_period
            , cfm.submissionperiod as submission_period_desc
            --ST005 Updated logic to determine the latest accepted file submission with data for a given organisation
            , row_number() over(
                partition by p.organisation_id, coalesce(cfm.ComplianceSchemeId, o.ExternalId), cfm.SubmissionPeriod
                order by cfm.created desc
            ) as latest_producer_accepted_record_per_SP
            , Right(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod),4) as Submission_Period_Year
            , coalesce(cfm.ComplianceSchemeId, o.ExternalId) as submitter_id
            FROM rpd.Pom p
            INNER JOIN rpd.Organisations o
            on o.ReferenceNumber = p.organisation_id
            --Excluding soft deleted organisations
            AND o.IsDeleted = 0
            --Restricting to just accepted pom files
            INNER JOIN [rpd].[cosmos_file_metadata] cfm
            on cfm.FileName = p.FileName
            INNER JOIN dbo.v_submitted_pom_org_file_status sofs ON sofs.cfm_fileid = cfm.fileid
            AND sofs.filetype = 'Pom'
            AND sofs.Regulator_Status = 'Accepted'
        ) a
        WHERE latest_producer_accepted_record_per_SP = 1
        ),
        -- Assign period flags for organisations
        organisation_period_flags AS (
	        SELECT
	              organisation_id
	            , submitter_id
	            , CAST(submission_period_year AS INT) AS submission_period_year
	            , MAX(CASE
                        WHEN submission_period = '2024-P1' THEN 1
                        WHEN submission_period = '2024-P2' THEN 1
                        WHEN submission_period = '2024-P3' THEN 1
                        WHEN CAST(submission_period_year AS INT) > 2024 AND RIGHT(submission_period, 3) = '-H1' THEN 1
                        ELSE 0
                      END) AS has_h1
                , MAX(CASE 
                        WHEN submission_period = '2024-P4' THEN 1
	                    WHEN CAST(submission_period_year AS INT) > 2024 AND RIGHT(submission_period, 3) = '-H2' THEN 1
                        ELSE 0
	                    END) AS has_h2
	        FROM latest_accepted_pom
	        GROUP BY
	              organisation_id
	            , submitter_id
	            , submission_period_year
	    ),

        -- The following is to ensure we only consider orgs which have submitted two periods

        LatestAcceptedPomsWith2Period as (
        select pom.*
        from latest_accepted_pom pom
        inner join organisation_period_flags as periods
            on  pom.organisation_id = periods.organisation_id
            and pom.submitter_id = periods.submitter_id
            and pom.Submission_Period_Year = periods.Submission_Period_Year
        where has_h1 = 1 and has_h2 = 1
        ),

        --ST006
        Latest_Org_Data_Selection AS (
        SELECT DISTINCT
            cd.organisation_id
        , lar.Submission_Period_Year -1 as Submission_Period_Year_minus_1
        FROM rpd.CompanyDetails cd
        INNER JOIN latest_accepted_registration lar
            ON cd.filename = lar.filename
            --Ensuring this is kept at a per org level of extraction, otherwise we would extract all data from the file
            --In latest_accepted_registration finding the latest file regardless of org size
            --Restricting here to those records where the organisation size is Large
            AND cd.Organisation_size = 'L'
            AND lar.organisation_id = cd.organisation_id
            AND cd.organisation_id IS NOT NULL
            AND cd.organisation_name IS NOT NULL
        )

        -----------------------------
        -----Main Selection of Data--
        -----------------------------
        SELECT
        p.organisation_id
        , NULLIF(trim(p.subsidiary_id), '') as subsidiary_id
        , p.submission_period
        , p.packaging_activity
        , p.packaging_type
        , p.packaging_class
        , p.packaging_material
        , p.packaging_material_weight
        , lap.submission_period_desc
        , lap.submitter_id
        FROM rpd.POM p
        INNER JOIN LatestAcceptedPomsWith2Period lap
        ON trim(p.FileName) = trim(lap.FileName)
        AND lap.organisation_id = p.organisation_id
        -- ST006 Join to latest registration data to ensure a registration is present for the associated pom data
        INNER JOIN Latest_Org_Data_Selection lods
        ON lods.organisation_id = p.organisation_id
        -- Additional criteria on the join to ensure the match is at a submission period year level
        AND lods.Submission_Period_Year_minus_1 = lap.Submission_Period_Year
        WHERE (p.packaging_type IN ('HH','CW','PB')
            -- HDC packaging_type - specifically restricted to just GL (Glass) materials--
            or (p.packaging_type = 'HDC' and p.packaging_material = 'GL')
            )
        and p.organisation_size = 'L'
        AND (p.to_country IS NULL OR trim(p.to_country) = '')
        AND p.organisation_id IS NOT NULL
        AND LEFT(p.submission_period,4) = @SubmissionPeriodYear 

	  END

    INSERT INTO [dbo].[batch_log]
        ([ID], [ProcessName], [SubProcessName], [Count], [start_time_stamp], [end_time_stamp], [Comments], [batch_id])
    SELECT
          (SELECT ISNULL(MAX(id), 1) + 1 FROM [dbo].[batch_log])
        , 'dbo.sp_GetPaycalPomData'
        , ''
        , NULL
        , @start_dt
        , GETDATE()
        , ''
        , @batch_id;
END
