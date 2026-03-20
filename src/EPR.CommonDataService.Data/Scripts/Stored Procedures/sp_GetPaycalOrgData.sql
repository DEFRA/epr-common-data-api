IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetPaycalOrgData]'))
	DROP PROCEDURE [dbo].[sp_GetPaycalOrgData];
GO

CREATE PROCEDURE [dbo].[sp_GetPaycalOrgData] @RelativeYear INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_dt DATETIME;
    DECLARE @batch_id INT;

    SELECT @batch_id = ISNULL(MAX(batch_id), 0) + 1
    FROM [dbo].[batch_log]

    SET @start_dt = GETDATE();
    
    BEGIN

	    WITH latest_accepted_pom AS (
	        SELECT 
                 a.organisation_id
                ,a.subsidiary_id
                ,a.submission_period
                ,a.submission_period_year
                ,a.submitter_id
	        FROM (
	            SELECT
	                  p.organisation_id
	                , NULLIF(p.subsidiary_id, '') AS subsidiary_id
	                , p.submission_period
	                , ROW_NUMBER() OVER (
	                    PARTITION BY p.organisation_id, COALESCE(cfm.ComplianceSchemeId, o.ExternalId), cfm.SubmissionPeriod
	                    ORDER BY cfm.created DESC
	                  ) AS latest_producer_accepted_record_per_SP
	                , CAST(RIGHT(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod), 4) AS INT) AS submission_period_year
	                , COALESCE(cfm.ComplianceSchemeId, o.ExternalId) AS submitter_id
	            FROM rpd.Pom p
	            INNER JOIN rpd.Organisations o
	                ON o.ReferenceNumber = p.organisation_id
	               AND o.IsDeleted = 0
	            INNER JOIN rpd.cosmos_file_metadata cfm
	                ON cfm.FileName = p.FileName
	            INNER JOIN dbo.v_submitted_pom_org_file_status sofs
	                ON sofs.cfm_fileid = cfm.fileid
	               AND sofs.filetype = 'Pom'
	               AND sofs.Regulator_Status = 'Accepted'
	        ) a
	        WHERE a.latest_producer_accepted_record_per_SP = 1
	    ),
	    organisation_period_flags AS (
	        SELECT
	              organisation_id
	            , subsidiary_id
	            , submitter_id
	            , submission_period_year
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
	            , subsidiary_id
	            , submitter_id
	            , submission_period_year
	    )
	    
	    SELECT
	           ob.organisation_id
	          ,ob.subsidiary_id
	          ,ob.submitter_id
	          ,ob.organisation_name
	          ,ob.trading_name
	          ,ob.status_code
	          ,ob.leaver_date
	          ,ob.joiner_date
	          ,ob.obligation_status
	          ,ob.num_days_obligated
	          ,ob.error_code
	          ,ob.submission_period_year
	          ,CAST(COALESCE(opf.has_h1, 0) AS BIT) AS has_h1
	          ,CAST(COALESCE(opf.has_h2, 0) AS BIT) AS has_h2
	    FROM dbo.t_producer_obligation_determination ob
	    LEFT JOIN organisation_period_flags opf
	        ON ob.organisation_id = opf.organisation_id
	       AND ISNULL(ob.subsidiary_id, '') = ISNULL(opf.subsidiary_id, '')
	       AND ISNULL(ob.submitter_id, '') = ISNULL(opf.submitter_id, '')
	       AND ob.submission_period_year = opf.submission_period_year
           WHERE ob.submission_period_year = @RelativeYear;
	  END

    INSERT INTO [dbo].[batch_log]
        ([ID], [ProcessName], [SubProcessName], [Count], [start_time_stamp], [end_time_stamp], [Comments], [batch_id])
    SELECT
          (SELECT ISNULL(MAX(id), 1) + 1 FROM [dbo].[batch_log])
        , 'dbo.sp_GetPaycalOrgData'
        , ''
        , NULL
        , @start_dt
        , GETDATE()
        , ''
        , @batch_id;
END
