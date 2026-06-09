CREATE OR ALTER VIEW dbo.v_producer_obligation_determination AS

-- latest_accepted_registration_files: join source tables, deduplicate, keep most recent per org/submitter/year
WITH larf_base AS (
    SELECT DISTINCT
        cfm.FileName,
        cd.organisation_id,
        RIGHT(cfm.SubmissionPeriod, 4)                           AS submission_period_year,
        COALESCE(cfm.ComplianceSchemeId, o.ExternalId)           AS submitter_id,
        cfm.Created,
        sofs.Regulator_Status
    FROM rpd.CompanyDetails cd
    INNER JOIN rpd.Organisations o
        ON o.ReferenceNumber = cd.organisation_id
    INNER JOIN rpd.cosmos_file_metadata cfm
        ON cfm.FileName = cd.FileName
    INNER JOIN dbo.v_submitted_pom_org_file_status sofs
        ON sofs.cfm_fileid = cfm.FileId
       AND sofs.filetype = 'CompanyDetails'
       AND sofs.Regulator_Status IN ('Granted', 'Accepted', 'Cancelled')
    WHERE o.IsDeleted = 0
),
latest_accepted_registration_files AS (
    SELECT FileName, organisation_id, submission_period_year, submitter_id, Created, Regulator_Status
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY organisation_id, submitter_id, submission_period_year
                ORDER BY CAST(SUBSTRING(Created, 1, 23) AS DATETIME2) DESC
            ) AS rn
        FROM larf_base
    ) t
    WHERE rn = 1
),

-- latest_accepted_registrations: join back to CompanyDetails, filter large orgs
latest_accepted_registrations AS (
    SELECT
        larf.organisation_id,
        cd.subsidiary_id,
        larf.submitter_id,
        cd.organisation_name,
        cd.trading_name,
        cd.leaver_code,
        cd.joiner_date,
        cd.leaver_date,
        larf.submission_period_year,
        COALESCE(TRY_CAST(cd.subsidiary_id AS INT), TRY_CAST(cd.organisation_id AS INT)) AS producer_id,
        larf.Regulator_Status
    FROM latest_accepted_registration_files larf
    INNER JOIN rpd.CompanyDetails cd
        ON  cd.organisation_id = larf.organisation_id
        AND cd.FileName = larf.FileName
    WHERE cd.organisation_size = 'L'
      AND cd.organisation_id IS NOT NULL
      AND cd.organisation_name IS NOT NULL
),

-- compute_raw_obligation_status: classify each row's obligation based on leaver code
raw_obligation AS (
    SELECT
        organisation_id,
        subsidiary_id,
        submitter_id,
        organisation_name,
        trading_name,
        leaver_code AS status_code,
        leaver_date,
        joiner_date,
        submission_period_year,
        producer_id,
        CASE
            WHEN Regulator_Status = 'Cancelled'                                               THEN 'Not Obligated'
            WHEN leaver_code IS NULL OR leaver_code = ''                                      THEN 'Blank'
            WHEN leaver_code IN ('09', '18')             AND subsidiary_id IS NOT NULL        THEN 'Invalid leaver code'
            WHEN leaver_code IN ('06', '07', '08', '10') AND subsidiary_id IS NULL            THEN 'Invalid leaver code'
            WHEN leaver_code IN ('11', '12')                                                  THEN 'Blank'
            WHEN leaver_code IN ('01','02','03','04','05','06','08','10','15','17','19','20') THEN 'Obligated'
            WHEN leaver_code IN ('07','09','13','14','16','18','21')                          THEN 'Not Obligated'
            ELSE 'Invalid leaver code'
        END AS raw_obligation_status
    FROM latest_accepted_registrations
),

-- apply_status_inheritance: propagate parent Not Obligated status to all subsidiaries in same group
status_inheritance AS (
    SELECT
        organisation_id,
        subsidiary_id,
        submitter_id,
        organisation_name,
        trading_name,
        status_code,
        leaver_date,
        joiner_date,
        submission_period_year,
        producer_id,
        CASE
            WHEN MAX(CASE WHEN subsidiary_id IS NULL AND raw_obligation_status = 'Not Obligated' THEN 1 ELSE 0 END)
                     OVER (PARTITION BY organisation_id, submitter_id, submission_period_year) = 1
            THEN 'Not Obligated'
            ELSE raw_obligation_status
        END AS raw_obligation_status
    FROM raw_obligation
),

-- pivot_raw_obligation: count each obligation status per producer/year
pivot_counts AS (
    SELECT
        producer_id,
        submission_period_year,
        SUM(CASE WHEN COALESCE(raw_obligation_status, 'Blank') = 'Obligated'           THEN 1 ELSE 0 END) AS obligated_count,
        SUM(CASE WHEN COALESCE(raw_obligation_status, 'Blank') = 'Not Obligated'       THEN 1 ELSE 0 END) AS not_obligated_count,
        SUM(CASE WHEN COALESCE(raw_obligation_status, 'Blank') = 'Invalid leaver code' THEN 1 ELSE 0 END) AS invalid_count,
        SUM(CASE WHEN COALESCE(raw_obligation_status, 'Blank') = 'Blank'               THEN 1 ELSE 0 END) AS blank_count
    FROM status_inheritance
    GROUP BY producer_id, submission_period_year
),

-- apply_decision_tree: assign O/N/E obligation_status and error_code, compute partial-year days
decision_tree AS (
    SELECT
        df.organisation_id,
        df.subsidiary_id,
        df.submitter_id,
        df.organisation_name,
        df.trading_name,
        df.status_code,
        df.leaver_date,
        df.joiner_date,
        df.raw_obligation_status,
        df.submission_period_year,
        df.producer_id,
        CASE
            WHEN df.status_code IN ('02','03')
             AND TRY_CONVERT(DATE, df.joiner_date, 103) IS NOT NULL
             AND CAST(df.submission_period_year AS INT) <> YEAR(TRY_CONVERT(DATE, df.joiner_date, 103))
                                                                                           THEN 'E'
            WHEN df.raw_obligation_status = 'Invalid leaver code'                          THEN 'E'
            WHEN p.obligated_count = 0 AND p.blank_count = 0 AND p.not_obligated_count > 0 THEN 'E'
            WHEN p.obligated_count = 0 AND p.blank_count > 1                               THEN 'E'
            WHEN p.obligated_count = 0 AND p.blank_count = 1
                THEN CASE WHEN df.raw_obligation_status = 'Blank' THEN 'O' ELSE 'N' END
            WHEN p.obligated_count = 1
                THEN CASE WHEN df.raw_obligation_status = 'Obligated' THEN 'O' ELSE 'N' END
            WHEN p.obligated_count > 1                                                     THEN 'E'
            ELSE 'E'
        END AS obligation_status,
        CASE
            WHEN df.status_code IN ('02','03')
             AND TRY_CONVERT(DATE, df.joiner_date, 103) IS NOT NULL
             AND CAST(df.submission_period_year AS INT) <> YEAR(TRY_CONVERT(DATE, df.joiner_date, 103))
                                                                                           THEN 'Date input issue'
            WHEN df.raw_obligation_status = 'Invalid leaver code'                          THEN 'Invalid leaver code'
            WHEN p.obligated_count = 0 AND p.blank_count = 0 AND p.not_obligated_count > 0 THEN 'Not Obligated'
            WHEN p.obligated_count = 0 AND p.blank_count > 1                               THEN 'Conflicting Obligations (Blanks)'
            WHEN p.obligated_count = 0 AND p.blank_count = 1                               THEN NULL
            WHEN p.obligated_count = 1                                                     THEN NULL
            WHEN p.obligated_count > 1                                                     THEN 'Conflicting Obligations (Leaver Codes)'
            ELSE 'E'
        END AS error_code,
        -- days remaining in submission year from joiner date (inclusive), for partial-year joiners
        CASE
            WHEN df.status_code IN ('02','03')
             AND YEAR(TRY_CONVERT(DATE, df.joiner_date, 103)) = CAST(df.submission_period_year AS INT)
            THEN DATEDIFF(
                    day,
                    TRY_CONVERT(DATE, df.joiner_date, 103),
                    DATEFROMPARTS(YEAR(TRY_CONVERT(DATE, df.joiner_date, 103)), 12, 31)
                 ) + 1
            ELSE NULL
        END AS num_days_obligated
    FROM status_inheritance df
    INNER JOIN pivot_counts p
        ON  df.producer_id        = p.producer_id
        AND df.submission_period_year = p.submission_period_year
),

-- rule_for_11_12
rule_11_12 AS (
    SELECT
        organisation_id, subsidiary_id, submitter_id, organisation_name, trading_name,
        status_code, leaver_date, joiner_date, raw_obligation_status,
        submission_period_year, producer_id, num_days_obligated,
        CASE WHEN status_code IN ('11','12') AND obligation_status = 'N' THEN 'E'
             ELSE obligation_status
        END AS obligation_status,
        CASE WHEN status_code IN ('11','12') AND error_code IS NULL THEN 'No longer trading'
             ELSE error_code
        END AS error_code
    FROM decision_tree
),

-- rule_for_13_14
rule_13_14 AS (
    SELECT
        organisation_id, subsidiary_id, submitter_id, organisation_name, trading_name,
        status_code, leaver_date, joiner_date, raw_obligation_status,
        submission_period_year, producer_id, num_days_obligated, obligation_status,
        CASE WHEN status_code IN ('13','14') AND obligation_status = 'E' THEN 'Compliance Scheme Leaver'
             ELSE error_code
        END AS error_code
    FROM rule_11_12
),

-- rule_for_16: mark code-16 rows as errors, then flag any other row whose producer_id
-- also appears with code 16 in the same year (a conflict)
producers_with_16 AS (
    SELECT DISTINCT producer_id, submission_period_year
    FROM rule_13_14
    WHERE status_code = '16'
),
rule_16_initial AS (
    SELECT
        organisation_id, subsidiary_id, submitter_id, organisation_name, trading_name,
        status_code, leaver_date, joiner_date, raw_obligation_status,
        submission_period_year, producer_id, num_days_obligated,
        CASE WHEN status_code = '16' THEN 'E'
             ELSE obligation_status
        END AS obligation_status,
        CASE WHEN status_code = '16' THEN 'Merged with another Producer'
             ELSE error_code
        END AS error_code
    FROM rule_13_14
),
rule_16 AS (
    SELECT
        r.organisation_id, r.subsidiary_id, r.submitter_id, r.organisation_name, r.trading_name,
        r.status_code, r.leaver_date, r.joiner_date, r.raw_obligation_status,
        r.submission_period_year, r.producer_id, r.num_days_obligated,
        CASE WHEN r.obligation_status = 'O' AND p16.producer_id IS NOT NULL THEN 'E'
             ELSE r.obligation_status
        END AS obligation_status,
        CASE WHEN r.obligation_status = 'O' AND p16.producer_id IS NOT NULL THEN 'Conflicting Obligations (Leaver code)'
             ELSE r.error_code
        END AS error_code
    FROM rule_16_initial r
    LEFT JOIN producers_with_16 p16
        ON  r.producer_id         = p16.producer_id
        AND r.submission_period_year = p16.submission_period_year
)

-- prepare_return
SELECT DISTINCT
    CAST(organisation_id AS INT)             AS organisation_id,
    CAST(subsidiary_id AS NVARCHAR(256))     AS subsidiary_id,
    CAST(submitter_id AS NVARCHAR(256))      AS submitter_id,
    CAST(organisation_name AS NVARCHAR(512)) AS organisation_name,
    CAST(trading_name AS NVARCHAR(512))      AS trading_name,
    CAST(status_code AS NVARCHAR(10))        AS status_code,
    CAST(leaver_date AS NVARCHAR(50))        AS leaver_date,
    CAST(joiner_date AS NVARCHAR(50))        AS joiner_date,
    CAST(obligation_status AS NVARCHAR(1))   AS obligation_status,
    CAST(num_days_obligated AS SMALLINT)     AS num_days_obligated,
    CAST(error_code AS NVARCHAR(256))        AS error_code,
    CAST(submission_period_year AS INT)      AS submission_period_year
FROM rule_16
WHERE organisation_id IS NOT NULL
  AND obligation_status IS NOT NULL;
