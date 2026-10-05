-- Historic registration lifecycle for the epr-payment-service registration migration (temporary).
-- Returns one row per event of each selected CompanyDetails file, in replay order.
-- Files selected per submission (roles): Latest, LatestNonRejected, FirstNonRejected, LatestNonRejectedAppSubmitted.
-- Events are paired to files the way the payment service attaches them: to the latest file declared at or before the event.
-- Only submissions whose selected files are all in @BlobContainerName are returned (the payment service reads blobs from it).

DECLARE @BlobContainerName NVARCHAR(200) = N'registration-upload-container-recyclers';

IF OBJECT_ID('tempdb..#RegSubs')        IS NOT NULL DROP TABLE #RegSubs;
IF OBJECT_ID('tempdb..#RegEvents')      IS NOT NULL DROP TABLE #RegEvents;
IF OBJECT_ID('tempdb..#FileContainers') IS NOT NULL DROP TABLE #FileContainers;
IF OBJECT_ID('tempdb..#Files')          IS NOT NULL DROP TABLE #Files;
IF OBJECT_ID('tempdb..#PairedAll')      IS NOT NULL DROP TABLE #PairedAll;
IF OBJECT_ID('tempdb..#Paired')         IS NOT NULL DROP TABLE #Paired;
IF OBJECT_ID('tempdb..#Selected')       IS NOT NULL DROP TABLE #Selected;

-- 1. Registration submissions, latest load per SubmissionId, 2025+ only (no payment-service submission period before 2025)
CREATE TABLE #RegSubs WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT SubmissionId, OrganisationId, ComplianceSchemeId, SubmissionPeriod, RegistrationJourney
FROM (
    SELECT SubmissionId, OrganisationId, ComplianceSchemeId, SubmissionPeriod, RegistrationJourney,
           ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY load_ts DESC) AS rn
    FROM rpd.Submissions
    WHERE SubmissionType = 'Registration'
) s
WHERE rn = 1
  AND RIGHT(RTRIM(SubmissionPeriod), 4) >= '2025';

-- 2. Relevant events for those submissions, de-duplicated, dates parsed safely
CREATE TABLE #RegEvents WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT SubmissionId, SubmissionEventId, [Type], FileId, Decision,
       ApplicationReferenceNumber, AppReferenceNumber,
       CreatedTs,
       COALESCE(CASE WHEN SubmissionDt >= '2000-01-01' THEN SubmissionDt END, CreatedTs) AS SubmissionTs,
       COALESCE(CASE WHEN DecisionDt   >= '2000-01-01' THEN DecisionDt   END, CreatedTs) AS DecisionTs
FROM (
    SELECT se.SubmissionId, se.SubmissionEventId, se.[Type], se.FileId, se.Decision,
           se.ApplicationReferenceNumber, se.AppReferenceNumber,
           COALESCE(TRY_CONVERT(DATETIME2(3), LEFT(se.Created, 23), 126),
                    TRY_CONVERT(DATETIME2(3), LEFT(se.Created, 19), 126))        AS CreatedTs,
           COALESCE(TRY_CONVERT(DATETIME2(3), LEFT(se.SubmissionDate, 23), 126),
                    TRY_CONVERT(DATETIME2(3), LEFT(se.SubmissionDate, 19), 126)) AS SubmissionDt,
           COALESCE(TRY_CONVERT(DATETIME2(3), LEFT(se.DecisionDate, 23), 126),
                    TRY_CONVERT(DATETIME2(3), LEFT(se.DecisionDate, 19), 126))   AS DecisionDt,
           ROW_NUMBER() OVER (PARTITION BY se.SubmissionEventId ORDER BY se.load_ts DESC) AS rn
    FROM rpd.SubmissionEvents se
    INNER JOIN #RegSubs s ON s.SubmissionId = se.SubmissionId
    WHERE se.[Type] IN ('Submitted', 'RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision')
) e
WHERE rn = 1
  AND CreatedTs >= '2000-01-01';

-- 2b. Blob container recorded on each file's SubmissionEvents.
--     A file is in the container only if every recorded value equals @BlobContainerName.
CREATE TABLE #FileContainers WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT se.SubmissionId, se.FileId,
       CASE WHEN MIN(se.BlobContainerName) = @BlobContainerName
             AND MAX(se.BlobContainerName) = @BlobContainerName THEN 1 ELSE 0 END AS InContainer
FROM rpd.SubmissionEvents se
INNER JOIN #RegSubs s ON s.SubmissionId = se.SubmissionId
WHERE se.FileId IS NOT NULL
  AND NULLIF(se.BlobContainerName, '') IS NOT NULL
GROUP BY se.SubmissionId, se.FileId;

-- 3. One row per declared CompanyDetails file (= one live RegistrationSubmissionData row)
CREATE TABLE #Files WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT SubmissionId, FileId, BlobName, OrganisationId, ComplianceSchemeId,
       SubmissionPeriod, RegistrationJourney, FileSubmittedTs, AppReferenceNumber, InContainer
FROM (
    SELECT cfm.SubmissionId, cfm.FileId, cfm.BlobName,
           s.OrganisationId, s.ComplianceSchemeId, s.SubmissionPeriod, s.RegistrationJourney,
           e.CreatedTs AS FileSubmittedTs, e.AppReferenceNumber,
           ISNULL(fc.InContainer, 0) AS InContainer,
           ROW_NUMBER() OVER (PARTITION BY cfm.FileId ORDER BY e.CreatedTs, cfm.load_ts DESC) AS rn
    FROM rpd.cosmos_file_metadata cfm
    INNER JOIN #RegSubs s   ON s.SubmissionId = cfm.SubmissionId
    INNER JOIN #RegEvents e ON e.SubmissionId = cfm.SubmissionId
                           AND e.FileId = cfm.FileId
                           AND e.[Type] = 'Submitted'
    LEFT JOIN #FileContainers fc ON fc.SubmissionId = cfm.SubmissionId AND fc.FileId = cfm.FileId
    WHERE cfm.FileType = 'CompanyDetails'
) f
WHERE rn = 1;

-- 4. Live-style pairing: each event belongs to the latest file declared at or before it (over ALL files)
CREATE TABLE #PairedAll WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT SubmissionId, SubmissionEventId, FileId, [Type], ReplayTs, EventDate, ApplicationReferenceNumber, Decision
FROM (
    SELECT e.SubmissionId, e.SubmissionEventId, f.FileId, e.[Type],
           e.CreatedTs AS ReplayTs,
           CASE WHEN e.[Type] = 'RegulatorRegistrationDecision' THEN e.DecisionTs ELSE e.SubmissionTs END AS EventDate,
           e.ApplicationReferenceNumber, e.Decision,
           ROW_NUMBER() OVER (PARTITION BY e.SubmissionEventId ORDER BY f.FileSubmittedTs DESC) AS rn
    FROM #RegEvents e
    INNER JOIN #Files f ON f.SubmissionId = e.SubmissionId AND e.CreatedTs >= f.FileSubmittedTs
    WHERE e.[Type] IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision')
) p
WHERE rn = 1;

-- 4b. Collapse bursts: an event identical (type + decision) to the previous event on the same file is dropped
CREATE TABLE #Paired WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT SubmissionId, SubmissionEventId, FileId, [Type], ReplayTs, EventDate, ApplicationReferenceNumber, Decision
FROM (
    SELECT p.*,
           LAG(CONCAT(p.[Type], '|', ISNULL(p.Decision, '')))
               OVER (PARTITION BY p.SubmissionId, p.FileId ORDER BY p.ReplayTs, p.SubmissionEventId) AS PrevKey
    FROM #PairedAll p
) x
WHERE PrevKey IS NULL
   OR PrevKey <> CONCAT([Type], '|', ISNULL(Decision, ''));

-- 5. Role-based file selection
CREATE TABLE #Selected WITH (DISTRIBUTION = HASH(SubmissionId), HEAP) AS
SELECT r.*,
       CONCAT(
           CASE WHEN LatestSeq = 1 THEN 'Latest;' ELSE '' END,
           CASE WHEN IsRejected = 0 AND NonRejDesc = 1 THEN 'LatestNonRejected;' ELSE '' END,
           CASE WHEN IsRejected = 0 AND NonRejAsc  = 1 THEN 'FirstNonRejected;' ELSE '' END,
           CASE WHEN IsRejected = 0 AND IsAppSubmitted = 1 AND NonRejAppDesc = 1 THEN 'LatestNonRejectedAppSubmitted;' ELSE '' END
       ) AS Roles
FROM (
    SELECT x.*,
           ROW_NUMBER() OVER (PARTITION BY x.SubmissionId ORDER BY x.FileSubmittedTs DESC) AS LatestSeq,
           ROW_NUMBER() OVER (PARTITION BY x.SubmissionId, x.IsRejected ORDER BY x.FileSubmittedTs DESC) AS NonRejDesc,
           ROW_NUMBER() OVER (PARTITION BY x.SubmissionId, x.IsRejected ORDER BY x.FileSubmittedTs ASC)  AS NonRejAsc,
           ROW_NUMBER() OVER (PARTITION BY x.SubmissionId, x.IsRejected, x.IsAppSubmitted ORDER BY x.FileSubmittedTs DESC) AS NonRejAppDesc
    FROM (
        SELECT f.SubmissionId, f.FileId, f.BlobName, f.OrganisationId, f.ComplianceSchemeId,
               f.SubmissionPeriod, f.RegistrationJourney, f.FileSubmittedTs, f.AppReferenceNumber, f.InContainer,
               ISNULL(fl.IsRejected, 0)     AS IsRejected,
               ISNULL(fl.IsAppSubmitted, 0) AS IsAppSubmitted
        FROM #Files f
        LEFT JOIN (
            SELECT SubmissionId, FileId,
                   MAX(CASE WHEN [Type] = 'RegulatorRegistrationDecision' AND Decision = 'Rejected' THEN 1 ELSE 0 END) AS IsRejected,
                   MAX(CASE WHEN [Type] = 'RegistrationApplicationSubmitted' THEN 1 ELSE 0 END)                       AS IsAppSubmitted
            FROM #Paired
            GROUP BY SubmissionId, FileId
        ) fl ON fl.SubmissionId = f.SubmissionId AND fl.FileId = f.FileId
    ) x
) r
WHERE LatestSeq = 1
   OR (IsRejected = 0 AND (NonRejDesc = 1 OR NonRejAsc = 1))
   OR (IsRejected = 0 AND IsAppSubmitted = 1 AND NonRejAppDesc = 1);

-- 6. Output: one row per event of each selected file, in replay order.
--    Submissions are kept or dropped whole: any selected file outside @BlobContainerName drops the submission.
SELECT w.SubmissionId, w.FileId, w.BlobName, w.OrganisationId, w.ComplianceSchemeId,
       w.SubmissionPeriod, w.RegistrationJourney, w.RegulatorNation, w.Roles,
       ev.EventType, ev.EventTypeOrder, ev.ReplayTs, ev.EventDate, ev.ApplicationReferenceNumber, ev.Decision
FROM (
    SELECT sel.*,
           CASE COALESCE(cs.NationId, o.NationId)
                WHEN 1 THEN 'GB-ENG' WHEN 2 THEN 'GB-NIR' WHEN 3 THEN 'GB-SCT' WHEN 4 THEN 'GB-WLS'
           END AS RegulatorNation
    FROM #Selected sel
    LEFT JOIN dbo.v_rpd_Organisations_Active o      ON o.ExternalId  = sel.OrganisationId     AND o.IsDeleted = 0
    LEFT JOIN dbo.v_rpd_ComplianceSchemes_Active cs ON cs.ExternalId = sel.ComplianceSchemeId AND cs.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM #Selected bad
                      WHERE bad.SubmissionId = sel.SubmissionId
                        AND bad.InContainer = 0)
) w
INNER JOIN (
    SELECT SubmissionId, FileId, CAST('Submitted' AS NVARCHAR(50)) AS EventType, 1 AS EventTypeOrder,
           FileSubmittedTs AS ReplayTs, FileSubmittedTs AS EventDate,
           AppReferenceNumber AS ApplicationReferenceNumber, CAST(NULL AS NVARCHAR(4000)) AS Decision
    FROM #Selected
    UNION ALL
    SELECT p.SubmissionId, p.FileId, p.[Type],
           CASE WHEN p.[Type] = 'RegistrationApplicationSubmitted' THEN 2 ELSE 3 END,
           p.ReplayTs, p.EventDate, p.ApplicationReferenceNumber, p.Decision
    FROM #Paired p
) ev ON ev.SubmissionId = w.SubmissionId AND ev.FileId = w.FileId
ORDER BY w.SubmissionId, ev.ReplayTs, ev.EventTypeOrder;
