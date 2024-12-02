IF EXISTS (SELECT 1 FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_OrganisationRegistrationSummaries]'))
DROP VIEW [dbo].[v_OrganisationRegistrationSummaries];
GO

create view [dbo].[v_OrganisationRegistrationSummaries]
as 
WITH 
    AllOrganisationRegistrationSubmissionsCTE AS
	(
	    SELECT         
            s.SubmissionId,
		    s.OrganisationId,   -- uuid
			org.Id as OrganisationInternalId,
            org.Name as OrganisationName,
            org.ReferenceNumber as OrganisationReferenceNumber,
            org.NationId as ProducerNationId,
			CASE org.NationId WHEN 1 then 'GB-ENG' WHEN 2 then 'GB-NIR' WHEN 3 then 'GB-SCT' WHEN 4 then 'GB-WLS' end as ProducerNationCode, -- this way for performance
	        s.Created,
		    s.SubmissionType,
            s.SubmissionPeriod,
			CAST(SUBSTRING(s.SubmissionPeriod, PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod), 4) AS INT) AS RelevantYear,
            CAST(CASE 
                WHEN s.Created > DATEFROMPARTS(YEAR(S.Created), 4, 1) THEN 1
                ELSE 0
            END AS BIT) AS IsLateSubmission,
		    org.IsComplianceScheme,
		    cd.organisation_size as ProducerSize,
		    s.AppReferenceNumber as ApplicationReferenceNumber,
		    s.UserId as SubmittedUserId,
            ROW_NUMBER() OVER (
                PARTITION BY OrganisationId, SubmissionPeriod
                ORDER BY s.Created DESC -- mark latest submission synced from cosmos
            ) as RowNum
	    from [rpd].[Submissions] as s
        inner join [rpd].[Organisations] org on org.ExternalId = s.OrganisationId
            inner join [rpd].[CompanyDetails] cd on cd.organisation_id = org.Id
	    where s.AppReferenceNumber is not null
		and org.IsDeleted = 0
	),
    LatestSubmittedRegistrationsCTE AS (
        SELECT
            SubmissionId,
            OrganisationId,
			OrganisationInternalId,
            OrganisationName,
            OrganisationReferenceNumber,
            ApplicationReferenceNumber,
            ProducerNationId,
			ProducerNationCode,
            Created as SubmittedDateTime,
            SubmissionType,
            SubmissionPeriod,
            RelevantYear,
			IsLateSubmission,
            IsComplianceScheme,
            ProducerSize,
            SubmittedUserId
        FROM AllOrganisationRegistrationSubmissionsCTE
        WHERE RowNum = 1
    ),
	AllRelatedOrganisationRegistrationDecisionEventsCTE AS (
        SELECT
            decisions.SubmissionEventId as SubmissionEventId,
            decisions.SubmissionId as SubmissionId,
            decisions.Comments as RegulatorComment,
		    decisions.RegistrationReferenceNumber as RegistrationReferenceNumber,
            decisions.Type as DecisionType,
			CASE LTRIM(RTRIM(decisions.Decision))
				when 'Accepted' then 'Granted'
				when 'Rejected' then 'Cancelled'
				else decisions.Decision
			end as SubmissionStatus,
		    decisions.Created as RegulatorDecisionDate,
            decisions.UserId as RegulatorUserId,
            decisions.DecisionDate AS StatusPendingDate,   -- part of the new RegulatorRegistrationDecision event, Cancellation Date
            ROW_NUMBER() OVER (
                PARTITION BY decisions.SubmissionId
                ORDER BY decisions.Created DESC -- mark latest submissionEvent synced from cosmos
            ) as RowNum
        FROM [rpd].[SubmissionEvents] as decisions
        inner join LatestSubmittedRegistrationsCTE registrations on 
			decisions.SubmissionId = registrations.SubmissionId
        WHERE decisions.Type = 'RegulatorRegistrationDecision'  -- a new Event type that will need to be trasnferred to synapse
        and decisions.ApplicationReferenceNumber = registrations.ApplicationReferenceNumber 
        --and LTRIM(RTRIM(decisions.Decision)) in ('Granted', 'Pending', 'Cancelled', 'Queried','Refused')
    ),
	-- Granted decision and registration number
	-- we find the Granted decision from the above CTE as this contains the RegistrationReferenceNumber
	-- this has now been moved to 
    LatestGrantedRegistrationEventCTE AS (
        select SubmissionEventId,
               SubmissionId,
               RegistrationReferenceNumber
        from AllRelatedOrganisationRegistrationDecisionEventsCTE decision
		where LTRIM(RTRIM(SubmissionStatus)) in ('Granted', 'Accepted')
    ),
    LatestDecisionEventsCTE AS (
        SELECT SubmissionEventId,
               SubmissionId,
               RegulatorComment,
               RegistrationReferenceNumber,
               RegulatorDecisionDate,
			   DecisionType,
               SubmissionStatus,
               RegulatorUserId,
               StatusPendingDate
        from AllRelatedOrganisationRegistrationDecisionEventsCTE
        where RowNum = 1 
    )
	-- producer comments
	,AllRelatedProducerCommentEventsCTE as (
		 SELECT producercomment.SubmissionEventId,
                producercomment.SubmissionId,
				producercomment.Comments as ProducerComment,
				producercomment.Created as ProducerCommentDate,
				ROW_NUMBER() OVER (
					 PARTITION BY producercomment.SubmissionId
					 ORDER BY Created DESC -- mark latest submissionEvent synced from cosmos
				 ) as RowNum
		 from [rpd].[SubmissionEvents] as producercomment
		 inner join LatestSubmittedRegistrationsCTE submittedregistrations on 
			 producercomment.SubmissionId = submittedregistrations.SubmissionId
		 WHERE producercomment.Type = 'RegistrationApplicationSubmitted'
	)
	,LatestProducerCommentEventsCTE AS (
		 SELECT SubmissionEventId,
                SubmissionId,
				ProducerComment,
				ProducerCommentDate
		 from AllRelatedProducerCommentEventsCTE
		 where RowNum = 1
	 )
	 ,AllRelatedSubmissionsDecisionsCommentsCTE AS (
        select 
            submissions.SubmissionId,
		    submissions.OrganisationId,
			submissions.OrganisationInternalId,
            submissions.OrganisationName,
            submissions.OrganisationReferenceNumber,
		    submissions.SubmittedUserId,
		    submissions.IsComplianceScheme,
		    submissions.ProducerSize,
			submissions.ApplicationReferenceNumber,
		    granteddecision.RegistrationReferenceNumber,
		    submissions.SubmittedDateTime,
            submissions.RelevantYear,
			submissions.SubmissionPeriod,
			submissions.IsLateSubmission,
            decisions.RegistrationReferenceNumber as DecisionRegistrationReferenceNumber,
		    CASE 
			WHEN producercomments.ProducerCommentDate > decisions.RegulatorDecisionDate THEN 'Updated'
			ELSE ISNULL(decisions.SubmissionStatus, 'Pending')
			END AS SubmissionStatus,
            decisions.RegulatorUserId,
            decisions.StatusPendingDate,
            decisions.RegulatorDecisionDate,
			producercomments.ProducerCommentDate,
			producercomments.SubmissionEventId as ProducerSubmissionEventId,
			decisions.SubmissionEventId as RegulatorSubmissionEventId,
            submissions.ProducerNationId,
			submissions.ProducerNationCode
        from LatestSubmittedRegistrationsCTE as submissions 
            left join LatestDecisionEventsCTE as decisions
                on submissions.Submissionid = decisions.Submissionid
            left join LatestGrantedRegistrationEventCTE as granteddecision
                on submissions.SubmissionId = granteddecision.SubmissionId
			left join LatestProducerCommentEventsCTE as producercomments
				on producercomments.SubmissionId = submissions.SubmissionId
    )
    SELECT 
    submissions.SubmissionId,
    submissions.OrganisationId,
	submissions.OrganisationInternalId,
    submissions.OrganisationName,
    submissions.OrganisationReferenceNumber,
    CASE 
        WHEN submissions.IsComplianceScheme = 1 THEN 'compliance'
        ELSE submissions.ProducerSize
    END AS OrganisationType,
	submissions.IsComplianceScheme,
	submissions.ProducerSize,
    submissions.RelevantYear,
	submissions.IsLateSubmission,
    submissions.SubmittedDateTime,
    CASE WHEN submissions.ProducerCommentDate > submissions.RegulatorDecisionDate
         THEN 'Updated'
         ELSE submissions.SubmissionStatus
    END as SubmissionStatus,
    submissions.StatusPendingDate,
	submissions.SubmissionPeriod,
    submissions.ApplicationReferenceNumber,
    CASE 
        WHEN submissions.RegistrationReferenceNumber IS NOT NULL 
            THEN submissions.RegistrationReferenceNumber
        ELSE submissions.DecisionRegistrationReferenceNumber
    END AS RegistrationReferenceNumber,
    submissions.ProducerNationId as NationId,
	submissions.ProducerNationCode as NationCode,
    submissions.RegulatorUserId,
	submissions.SubmittedUserId,
	submissions.RegulatorDecisionDate,
	submissions.ProducerCommentDate,
	submissions.ProducerSubmissionEventId,
	submissions.RegulatorSubmissionEventId
    from AllRelatedSubmissionsDecisionsCommentsCTE as submissions ;
GO

