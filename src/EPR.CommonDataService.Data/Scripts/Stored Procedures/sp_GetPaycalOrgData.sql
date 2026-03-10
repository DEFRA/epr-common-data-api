-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetPaycalOrgData]'))
DROP PROCEDURE [dbo].[sp_GetPaycalOrgData];
GO

CREATE PROC [dbo].[sp_GetPaycalOrgData]
AS
BEGIN

  DECLARE @start_dt datetime;
  DECLARE @batch_id INT;

  SELECT @batch_id = ISNULL(MAX(batch_id), 0) + 1
  FROM [dbo].[batch_log];

  SET @start_dt = GETDATE();

  BEGIN
    SET NOCOUNT ON;

    /*****************************************************************************************************************
      History:
        Created 2026-03-10: ECV-294 : Created first version of the stored procedure with logic from view dbo.v_Paycal_Org. 
                            Also parameterised organisation period to create flags. 
     *****************************************************************************************************************/

    WITH latest_accepted_pom AS (
      SELECT * FROM (
        SELECT
            p.organisation_id
          , NULLIF(TRIM(p.subsidiary_id), '') AS subsidiary_id
          , p.submission_period
            --ST005 Updated logic to determine the latest accepted file submission with data for a given organisation
          , ROW_NUMBER() OVER(
              PARTITION BY p.organisation_id, COALESCE(cfm.ComplianceSchemeId, o.ExternalId), cfm.SubmissionPeriod
              ORDER BY cfm.created DESC
            ) AS latest_producer_accepted_record_per_SP
          , RIGHT(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod),4) AS Submission_Period_Year
          , COALESCE(cfm.ComplianceSchemeId, o.ExternalId) AS submitter_id
        FROM rpd.Pom p
        INNER JOIN rpd.Organisations o
          ON o.ReferenceNumber = p.organisation_id
          --Excluding soft deleted organisations
          AND o.IsDeleted = 0
          --Restricting to just accepted pom files
        INNER JOIN rpd.cosmos_file_metadata cfm
          ON cfm.FileName = p.FileName
        INNER JOIN dbo.v_submitted_pom_org_file_status sofs
          ON sofs.cfm_fileid = cfm.fileid
          AND sofs.filetype = 'Pom'
          AND sofs.Regulator_Status = 'Accepted'
      ) a
      WHERE latest_producer_accepted_record_per_SP = 1
    ),

    organisation_period_flags AS (
      SELECT
        organisation_id
      , subsidiary_id
      , submitter_id
      , CAST(submission_period_year AS INT) AS submission_period_year
      , CAST(
          CASE
            WHEN submission_period_year = 2024 AND
              MAX(CASE WHEN submission_period LIKE '%-P1' THEN 1 ELSE 0 END) = 1 OR
              MAX(CASE WHEN submission_period LIKE '%-P2' THEN 1 ELSE 0 END) = 1 OR
              MAX(CASE WHEN submission_period LIKE '%-P3' THEN 1 ELSE 0 END) = 1
            THEN 1
            WHEN submission_period_year > 2024 AND
              MAX(CASE WHEN submission_period LIKE '%-H1' THEN 1 ELSE 0 END) = 1
            THEN 1
            ELSE 0
          END AS BIT
        ) AS has_h1
      , CAST(
          CASE
            WHEN submission_period_year = 2024 AND
              MAX(CASE WHEN submission_period LIKE '%-P4' THEN 1 ELSE 0 END) = 1
            THEN 1
            WHEN submission_period_year > 2024 AND
              MAX(CASE WHEN submission_period LIKE '%-H2' THEN 1 ELSE 0 END) = 1
            THEN 1
            ELSE 0
          END AS BIT
        ) AS has_h2
      FROM latest_accepted_pom
      GROUP BY organisation_id, subsidiary_id, submitter_id, submission_period_year
    )

    SELECT
      ob.*
    , COALESCE(opf.has_h1, CAST(0 AS BIT)) AS has_h1
    , COALESCE(opf.has_h2, CAST(0 AS BIT)) AS has_h2
    FROM dbo.t_producer_obligation_determination ob
    LEFT JOIN organisation_period_flags opf
      ON opf.organisation_id = ob.organisation_id
      AND ISNULL(opf.subsidiary_id, '') = ISNULL(ob.subsidiary_id, '')
      AND ISNULL(opf.submitter_id, '') = ISNULL(ob.submitter_id, '')
      AND opf.submission_period_year = ob.submission_period_year;

  END

  INSERT INTO [dbo].[batch_log]
    ([ID], [ProcessName], [SubProcessName], [Count], [start_time_stamp], [end_time_stamp], [Comments], batch_id)
  SELECT
    (SELECT ISNULL(MAX(id), 1) + 1 FROM [dbo].[batch_log]),
    'dbo.sp_GetPaycalOrgData',
    '',
    NULL,
    @start_dt,
    GETDATE(),
    '',
    @batch_id;

END
GO
