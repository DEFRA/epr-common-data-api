IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetPaycalOrgData]'))
	DROP PROCEDURE [dbo].[sp_GetPaycalOrgData];
GO

CREATE PROCEDURE [dbo].[sp_GetPaycalOrgData] @SubmissionPeriodYear INT
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
	        SELECT *
	        FROM (
	            SELECT
	                  p.organisation_id
	                , NULLIF(LTRIM(RTRIM(p.subsidiary_id)), '') AS subsidiary_id
	                , p.submission_period
	                , ROW_NUMBER() OVER (
	                    PARTITION BY p.organisation_id, COALESCE(cfm.ComplianceSchemeId, o.ExternalId), cfm.SubmissionPeriod
	                    ORDER BY cfm.created DESC
	                  ) AS latest_producer_accepted_record_per_SP
	                , RIGHT(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod), 4) AS submission_period_year
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
	        WHERE latest_producer_accepted_record_per_SP = 1
            AND CAST(submission_period_year AS INT) = @SubmissionPeriodYear
	    ),
	    organisation_period_flags AS (
	        SELECT
	              organisation_id
	            , subsidiary_id
	            , submitter_id
	            , CAST(submission_period_year AS INT) AS submission_period_year
	            , CASE
	                WHEN CAST(submission_period_year AS INT) = 2024
	                     AND (
	                          MAX(CASE WHEN submission_period LIKE '%-P1' THEN 1 ELSE 0 END) = 1
	                       OR MAX(CASE WHEN submission_period LIKE '%-P2' THEN 1 ELSE 0 END) = 1
	                       OR MAX(CASE WHEN submission_period LIKE '%-P3' THEN 1 ELSE 0 END) = 1
	                     )
	                THEN 1
	                WHEN CAST(submission_period_year AS INT) > 2024
	                     AND MAX(CASE WHEN submission_period LIKE '%-H1' THEN 1 ELSE 0 END) = 1
	                THEN 1
	                ELSE 0
	              END AS has_h1
	            , CASE
	                WHEN CAST(submission_period_year AS INT) = 2024
	                     AND MAX(CASE WHEN submission_period LIKE '%-P4' THEN 1 ELSE 0 END) = 1
	                THEN 1
	                WHEN CAST(submission_period_year AS INT) > 2024
	                     AND MAX(CASE WHEN submission_period LIKE '%-H2' THEN 1 ELSE 0 END) = 1
	                THEN 1
	                ELSE 0
	              END AS has_h2
	        FROM latest_accepted_pom
	        GROUP BY
	              organisation_id
	            , subsidiary_id
	            , submitter_id
	            , submission_period_year
	    )
	    
	    
	    SELECT
	          ob.*
	        , COALESCE(opf.has_h1, 0) AS has_h1
	        , COALESCE(opf.has_h2, 0) AS has_h2
	    FROM dbo.t_producer_obligation_determination ob
	    LEFT JOIN organisation_period_flags opf
	        ON opf.organisation_id = ob.organisation_id
	       AND ISNULL(opf.subsidiary_id, '') = ISNULL(ob.subsidiary_id, '')
	       AND ISNULL(opf.submitter_id, '') = ISNULL(ob.submitter_id, '')
	       AND opf.submission_period_year = ob.submission_period_year
           WHERE ob.submission_period_year = @SubmissionPeriodYear;
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
