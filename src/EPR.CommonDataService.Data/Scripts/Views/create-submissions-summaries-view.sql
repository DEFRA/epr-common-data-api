-- Dropping view if it exists
IF EXISTS (SELECT 1 FROM sys.views WHERE object_id = OBJECT_ID(N'[apps].[v_SubmissionsSummaries]'))
DROP VIEW [apps].[v_SubmissionsSummaries];
GO

CREATE VIEW [apps].[v_SubmissionsSummaries] AS WITH 
	File_id_code_description as 
	(
		select distinct meta.fileid, p.filename, p.submission_period as SubmissionCode, Text as ActualSubmissionPeriod
		from rpd.pom p
		left join dbo.v_PoM_Codes c on 
			p.submission_period = c.Code
		left join rpd.cosmos_file_metadata meta 
		on meta.filename = p.filename
		where c.Type = 'apps_submission_period'
	),
	File_id_code_description_combined as
	(
		select F.fileid, F.filename, F.SubmissionCode, F.ActualSubmissionPeriod, A.Combined_SubmissionCode, A.Combined_ActualSubmissionPeriod
		from File_id_code_description F
		left join 
		(
			select fileid, filename, string_agg(SubmissionCode, ',') as Combined_SubmissionCode, string_agg(ActualSubmissionPeriod, ',') as Combined_ActualSubmissionPeriod
			from File_id_code_description
			group by fileid, filename
		) A on A.fileid = F.fileid and A.filename = F.filename 
	)
	,
	AllSubmittedEventsCTE AS (
    SELECT
        submitted.SubmissionEventId,
        submitted.SubmissionId,
        submitted.Type,
        submitted.FileId,
        submitted.Created AS SubmittedDate,
		submitted.UserId as SubmittedUserId,
        ROW_NUMBER() OVER(
				PARTITION BY FileId
				ORDER BY load_ts DESC -- mark latest submissionEvent synced from cosmos
			) as RowNum
    FROM [apps].[SubmissionEvents] submitted
        WHERE submitted.Type='Submitted'
        )

    -- Get LATEST submitted event by load_ts per SubmissionEventId (to remove cosmos sync duplicates)
        ,LatestSubmittedEventsCTE AS (
        SELECT
        SubmissionEventId,
        SubmissionId,
        Type,
        FileId,
        SubmittedDate,
		SubmittedUserId
        FROM AllSubmittedEventsCTE
        WHERE RowNum = 1
        )
		
    -- Get Decision events for submitted (match by fileId)
        ,AllRelatedDecisionEventsCTE AS (
        SELECT
        decision.FileId,
        decision.SubmissionEventId,
        decision.SubmissionId,
        decision.Decision,
        decision.Comments,
        CASE
            WHEN UPPER( ISNULL(decision.IsResubmissionRequired,'FALSE')) = 'TRUE' THEN 1
            ELSE 0
        END AS IsResubmissionRequired ,
        decision.Created AS DecisionDate,
        ROW_NUMBER() OVER(
        PARTITION BY decision.FileId  -- mark latest submissionEvent synced from cosmos
        ORDER BY decision.load_ts DESC
        ) as RowNum
        FROM [apps].[SubmissionEvents] decision
        INNER JOIN LatestSubmittedEventsCTE submitted ON submitted.FileId = decision.FileId
        WHERE
        decision.Type='RegulatorPomDecision'
        )

        ,LatestRelatedDecisionEventsCTE AS (
        SELECT
        FileId,
        SubmissionEventId,
        SubmissionId,
        Decision,
        Comments,
        IsResubmissionRequired,
        DecisionDate
        FROM AllRelatedDecisionEventsCTE
        WHERE RowNum = 1 --  get only latest
        )

        ,JoinedSubmittedAndDecisionsCTE AS (
        SELECT
        submitted.SubmissionId,
        submitted.SubmittedDate,
        submitted.FileId,
		submitted.SubmittedUserId,
        decision.DecisionDate,
        decision.Decision,
        decision.Comments,
        decision.IsResubmissionRequired
        FROM LatestSubmittedEventsCTE submitted
        LEFT JOIN LatestRelatedDecisionEventsCTE decision ON decision.FileId = submitted.FileId
        WHERE
        decision.Decision IS NULL -- get ALL pending
        OR
        submitted.SubmittedDate >= FORMAT(DATEADD(MONTH, -6, GETDATE()), 'yyyy-MM-dd') -- or last 6 months with decisions (accepted/rejected)
        )

        ,AllRelatedSubmissionsCTE AS (
        SELECT
        s.SubmissionId,
        s.OrganisationId,
        s.ComplianceSchemeId,
        s.UserId,
        s.SubmissionPeriod,
        ROW_NUMBER() OVER(PARTITION BY s.SubmissionId ORDER BY s.load_ts DESC) as RowNum -- mark latest submission synced from cosmos
        FROM [apps].[Submissions] s
        INNER JOIN JoinedSubmittedAndDecisionsCTE jsd ON jsd.SubmissionId = s.SubmissionId
        WHERE s.SubmissionType='Producer'
        )

        ,LatestRelatedSubmissionsCTE AS (
        SELECT
        SubmissionId,
        OrganisationId,
        ComplianceSchemeId,
        UserId,
        SubmissionPeriod
        FROM AllRelatedSubmissionsCTE
        WHERE RowNum = 1
        )

    -- Use the above CTEs to get all submissions with submitted event, and join decision if exists
        ,JoinedSubmissionsAndEventsCTE AS (
        SELECT
        s.SubmissionId,
        s.OrganisationId,
        s.ComplianceSchemeId,
        s.UserId,
        s.SubmissionPeriod,
        jsd.FileId,
        jsd.Decision,
        jsd.Comments,
        jsd.IsResubmissionRequired,
        jsd.SubmittedDate,
        jsd.DecisionDate,
		jsd.SubmittedUserId,
        ROW_NUMBER() OVER(
        PARTITION BY s.SubmissionId --, jsd.FileId (commented out to fix incorrect ressubmission details issue) -- to match the count with power bi
        ORDER BY jsd.SubmittedDate DESC
        ) as RowNum -- original row number based on submitted date
        FROM JoinedSubmittedAndDecisionsCTE jsd
        INNER JOIN LatestRelatedSubmissionsCTE s ON jsd.SubmissionId = s.SubmissionId
        )

        ,JoinedSubmissionsAndEventsWithResubmissionCTE AS (
        SELECT
        l.*,
        (
        SELECT COUNT(*)
        FROM JoinedSubmissionsAndEventsCTE j
        WHERE
        j.SubmissionId = l.SubmissionId AND
        j.RowNum > l.RowNum AND
        j.Decision IS NOT NULL -- how many decisions BEFORE this one           
        ) AS PreviousDecisions,
        (
        SELECT TOP 1 j.Comments
        FROM JoinedSubmissionsAndEventsCTE j
        WHERE
        j.SubmissionId = l.SubmissionId AND
        j.RowNum > l.RowNum AND
        j.Decision='Rejected' -- get last rejection comments BEFORE this one
        ORDER BY j.SubmittedDate DESC
        ) AS PreviousRejectionComments,
        (
        SELECT TOP 1 j.IsResubmissionRequired
        FROM JoinedSubmissionsAndEventsCTE j
        WHERE
        j.SubmissionId = l.SubmissionId AND
        j.RowNum > l.RowNum AND
        j.Decision='Rejected' -- get last rejection isResubmissionRequired BEFORE this one
        ORDER BY j.SubmittedDate DESC
        ) AS PreviousRejectionIsResubmissionRequired
        FROM JoinedSubmissionsAndEventsCTE l
        WHERE
        (l.Decision IS NULL AND RowNum=1) -- show pending if latest
        OR l.Decision IS NOT NULL -- and show all decisions
        )

    -- Create subquery for latest enrolment
        ,LatestEnrolment AS (
        SELECT
        e.ConnectionId,
        e.ServiceRoleId,
        e.LastUpdatedOn,
        ROW_NUMBER() OVER(PARTITION BY e.ConnectionId ORDER BY e.LastUpdatedOn DESC) as rn
        FROM [rpd].[Enrolments] e
        )

-- Query the CTE to return latest row per org with isResubmission status
SELECT
    SubmissionId,
    r.OrganisationId,
    r.ComplianceSchemeId,
    o.Name As OrganisationName,
    o.ReferenceNumber as OrganisationReference,
    CASE
        WHEN r.ComplianceSchemeId IS NOT NULL THEN 'Compliance Scheme'
        ELSE 'Direct Producer'
        END AS  OrganisationType,
    pt.Name as ProducerType,
    r.SubmittedUserId as UserId,
    p.FirstName,
    p.LastName,
    p.Email,
    p.Telephone,
    sr.Name as ServiceRole,
    r.FileId,
	'20'+reverse(substring(reverse(trim(SubmissionPeriod)),1,2)) as 'SubmissionYear',
	SubmissionCode,
	ActualSubmissionPeriod,
	Combined_SubmissionCode,
	Combined_ActualSubmissionPeriod,
    SubmissionPeriod,
    SubmittedDate,
    CASE
        WHEN Decision IS NULL THEN 'Pending'
        ELSE Decision
        END AS Decision,
    CASE
        WHEN PreviousDecisions > 0 THEN ISNULL(PreviousRejectionIsResubmissionRequired,0)
        ELSE ISNULL(IsResubmissionRequired,0) END AS IsResubmissionRequired,
    Comments,
    CASE
        WHEN PreviousDecisions > 0 THEN 1
        ELSE 0
        END AS IsResubmission,
    PreviousRejectionComments,
    CASE
        WHEN r.ComplianceSchemeId IS NOT NULL THEN cs.NationId
        ELSE o.NationId
        END AS NationId
FROM JoinedSubmissionsAndEventsWithResubmissionCTE r
         INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId
    LEFT JOIN [rpd].[ProducerTypes] pt ON pt.Id = o.ProducerTypeId
    INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
    INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
    INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
    INNER JOIN LatestEnrolment le ON le.ConnectionId = poc.Id AND le.rn = 1 -- join on only latest enrolment
    INNER JOIN [rpd].[ServiceRoles] sr on sr.Id = le.ServiceRoleId
    LEFT JOIN [rpd].[ComplianceSchemes] cs ON cs.ExternalId = r.ComplianceSchemeId -- join CS to get nation above
	left join File_id_code_description_combined file_desc on file_desc.fileid = r.FileId
WHERE o.IsDeleted=0 and poc.IsDeleted=0;
GO
