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
                PARTITION BY OrganisationId
                ORDER BY s.load_ts DESC -- mark latest submission synced from cosmos
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
            O.Id as OrganisationId, -- in Cosmos but not SubmissionEvent table
            decisions.Comments as RegulatorComment,
		    decisions.RegistrationReferenceNumber as RegistrationReferenceNumber,   -- Where?
            decisions.Type as DecisionType,
			CASE decisions.Decision
				when 'Accepted' then 'Granted'
				when 'Rejected' then 'Cancelled'
				else decisions.Decision
			end as SubmissionStatus,
		    --decisions.Decision as SubmissionStatus,
			decisions.Created as RegulatorDecisionDate,
            decisions.UserId as RegulatorUserId,
            decisions.DecisionDate AS StatusPendingDate,   -- part of the new RegulatorRegistrationDecision event, Cancellation Date
            (SELECT o.NationId from 
                rpd.Users u
                    INNER JOIN rpd.Persons p ON p.UserId = u.Id
                    INNER JOIN rpd.PersonOrganisationConnections poc ON poc.PersonId = p.Id
                    INNER JOIN rpd.Organisations o ON o.Id = poc.OrganisationId
                    INNER JOIN rpd.Enrolments e ON e.ConnectionId = poc.Id
                    INNER JOIN rpd.ServiceRoles sr ON sr.Id = e.ServiceRoleId
                where sr.ServiceId = 2
                and U.UserId = decisions.UserId
            ) as RegulatorNationId,
            ROW_NUMBER() OVER (
                PARTITION BY decisions.SubmissionId
                ORDER BY decisions.load_ts DESC -- mark latest submissionEvent synced from cosmos
            ) as RowNum
        FROM [rpd].[SubmissionEvents] as decisions
        inner join LatestSubmittedRegistrationsCTE registrations on 
            decisions.SubmissionId = registrations.SubmissionId
        inner join [rpd].[Organisations] O on O.ExternalId = registrations.OrganisationId
        WHERE decisions.Type = 'RegulatorRegistrationDecision'  -- a new Event type that will need to be trasnferred to synapse
		--and LTRIM(RTRIM(decisions.Decision)) in ('Granted', 'Pending', 'Cancelled', 'Queried','Refused')
    ),
    LatestGrantedRegistrationEventCTE AS (
        select  top(1) SubmissionId,
                RegistrationReferenceNumber
        from AllRelatedOrganisationRegistrationDecisionEventsCTE
        where SubmissionStatus in ('Granted', 'Accepted')
    ),
    LatestDecisionEventsCTE AS (
        SELECT SubmissionEventId,
                SubmissionId,
                OrganisationId,
                RegulatorComment,
                RegistrationReferenceNumber,
                RegulatorDecisionDate,
				DecisionType,
                SubmissionStatus,
                RegulatorUserId,
                StatusPendingDate,
                RegulatorNationId
        from AllRelatedOrganisationRegistrationDecisionEventsCTE
        where RowNum = 1 
    )
	-- producer comments
	,AllRelatedProducerCommentEventsCTE as (
		 SELECT producercomment.SubmissionId,
				producercomment.Comments as ProducerComment,
				producercomment.Created as ProducerCommentDate,
				ROW_NUMBER() OVER (
					 PARTITION BY producercomment.SubmissionId
					 ORDER BY load_ts DESC -- mark latest submissionEvent synced from cosmos
				 ) as RowNum
		 from [rpd].[SubmissionEvents] as producercomment
		 inner join LatestSubmittedRegistrationsCTE submittedregistrations on 
			 producercomment.SubmissionId = submittedregistrations.SubmissionId
		 WHERE producercomment.Type = 'RegistrationApplicationSubmitted'
	 )
	 ,LatestProducerCommentEventsCTE AS (
		 SELECT SubmissionId,
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
		    --'ApplicationReferenceNumber' as ApplicationReferenceNumber, 
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
			submissions.ProducerNationId,
			submissions.ProducerNationCode,
            decisions.RegulatorNationId
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
    submissions.SubmissionStatus,
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
	submissions.ProducerCommentDate
    from AllRelatedSubmissionsDecisionsCommentsCTE as submissions ;
GO

-- filtering SP
-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries]'))
DROP PROCEDURE [rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries];
GO
create proc [rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries] 
    @OrganisationNameCommaSeparated[nvarchar](255),
    @OrganisationReferenceCommaSeparated [nvarchar](255),
    @SubmissionYearsCommaSeparated [nvarchar](255),
    @StatusesCommaSeparated [nvarchar](100),
    @OrganisationTypeCommaSeparated [nvarchar](255),
    @NationId int,
	@AppRefNumbersCommaSeparated [nvarchar](2000),
    @PageSize [INT],
    @PageNumber [INT]
AS
begin
	SET NOCOUNT ON;

    with 
	InitialFilterCTE as (
    	SELECT * 
        FROM dbo.[v_OrganisationRegistrationSummaries]
		WHERE 
        ( 
			1 = 1
			AND NationId = @NationId 
		)
		AND
		(
			(
				(
					LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
					AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
					AND EXISTS (
						SELECT 1
						FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
						WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
					)
					AND EXISTS (
						SELECT 1
						FROM STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
						WHERE OrganisationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
						OR ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
						OR RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
					)
				)
				-- Only OrganisationName specified
				OR (
					LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
					AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
					AND EXISTS (
						SELECT 1
						FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
						WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
					)
				)
				-- Only OrganisationReference specified
				OR (
					LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
					AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
					AND EXISTS (
						SELECT 1
						FROM STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
						WHERE OrganisationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
						OR ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
						OR RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
					)
				)
				OR (
					LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
					AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
				)
			)
		)
        AND (ISNULL(@OrganisationTypeCommaSeparated, '') = '' OR OrganisationType IN
            (SELECT TRIM(value) FROM STRING_SPLIT(@OrganisationTypeCommaSeparated, ','))
        )
        AND (ISNULL(@SubmissionYearsCommaSeparated, '') = '' OR RelevantYear IN 
            (SELECT TRIM(value) FROM STRING_SPLIT(@SubmissionYearsCommaSeparated, ','))
        )
        AND (ISNULL(@StatusesCommaSeparated, '') = '' OR SubmissionStatus IN 
			(SELECT TRIM(value) FROM STRING_SPLIT(@StatusesCommaSeparated, ','))
        )
    ),
    SortedCTE as (
        select *,
        ROW_NUMBER() OVER (
            ORDER BY
                CASE 
                    when SubmissionStatus = 'Cancelled' THEN 6
                    when SubmissionStatus = 'Refused' THEN 5
                    when SubmissionStatus = 'Granted' THEN 4
                    when SubmissionStatus = 'Queried' THEN 3
                    when SubmissionStatus = 'Pending' THEN 2
                    when SubmissionStatus = 'Updated' THEN 1
                END,
                SubmittedDateTime
        ) as RowNum
        from InitialFilterCTE
    )
SELECT
    SubmissionId,
    OrganisationId,
	OrganisationInternalId,
    OrganisationType,
    OrganisationName,
    OrganisationReferenceNumber as OrganisationReference,
    SubmissionStatus,
    StatusPendingDate,
    ApplicationReferenceNumber,
    RegistrationReferenceNumber,
    RelevantYear,
    SubmittedDateTime,
	RegulatorDecisionDate as RegulatorCommentDate,
	ProducerCommentDate,
	RegulatorUserId,
    NationId,
	NationCode,
    (SELECT COUNT(*) FROM SortedCTE) AS TotalItems
FROM SortedCTE
WHERE RowNum > (@PageSize * (@PageNumber - 1))
   AND RowNum <= @PageSize * @PageNumber
ORDER BY RowNum;

END;

GO
