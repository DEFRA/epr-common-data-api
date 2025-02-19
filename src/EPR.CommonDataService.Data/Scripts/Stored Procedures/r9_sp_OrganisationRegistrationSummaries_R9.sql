IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_OrganisationRegistrationSummaries_R9]'))
DROP PROCEDURE [dbo].[sp_OrganisationRegistrationSummaries_R9];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[sp_OrganisationRegistrationSummaries_R9] AS
BEGIN
	SET NOCOUNT ON;

    -- Variable to hold the dynamically constructed SQL query
    DECLARE @ProdCommentsSQL NVARCHAR(MAX);

	IF OBJECT_ID('tempdb..#ProdCommentsRegulatorDecisions') IS NOT NULL
		DROP TABLE #ProdCommentsRegulatorDecisions;
	
	SET @ProdCommentsSQL = N'
		select *, ROW_NUMBER() OVER(
					  ORDER BY orderedsubevents.DecisionDate DESC
				  ) as OrderedRowNum
		INTO #ProdCommentsRegulatorDecisions
		from  (
			select subevents.*
			from (
				SELECT
					decisions.SubmissionId,
					decisions.SubmissionEventId AS SubmissionEventId,
					decisions.Created AS DecisionDate,
					decisions.Comments AS Comment,
					decisions.UserId,
					decisions.Type,
					CASE
						WHEN LTRIM(RTRIM(decisions.Decision)) = ''Accepted'' THEN ''Granted''
						WHEN LTRIM(RTRIM(decisions.Decision)) = ''Rejected'' THEN ''Refused''
						WHEN decisions.Decision IS NULL THEN ''Pending''
						ELSE decisions.Decision
					END AS SubmissionStatus
					,DecisionDate AS StatusPendingDate
					,CASE 
						WHEN decisions.Type = ''RegistrationApplicationSubmitted'' THEN 1 ELSE 0
					END AS IsProducerComment
	';

	IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'RegistrationReferenceNumber' AND [object_id] = OBJECT_ID('rpd.SubmissionEvents')
	)
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'				,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
		')
	END
	ELSE
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'				,NULL AS RegistrationReferenceNumber
		');
	END;

	SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'
					,ROW_NUMBER() OVER (
						PARTITION BY decisions.SubmissionId, decisions.SubmissionEventId, decisions.Type
						ORDER BY decisions.Created DESC
					) AS RowNum
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN (''RegistrationApplicationSubmitted'', ''RegulatorRegistrationDecision'')	
			) as subevents
			where RowNum = 1
		) as orderedsubevents
	');

	EXEC sp_executesql @ProdCommentsSQL;
	
	WITH ProdCommentsRegulatorDecisionsCTE as (
		SELECT
			SubmissionId
			,SubmissionEventId
			,DecisionDate
			,Comment
			,RegistrationReferenceNumber
			,SubmissionStatus
			,StatusPendingDate
			,IsProducerComment
			,UserId
			,RowNum
			,OrderedRowNum
		FROM
			#ProdCommentsRegulatorDecisions as decisions
	)
	,RegistrationDecisionCTE as (
		SELECT *
		FROM (
			SELECT SubmissionId, SubmissionEventId, Userid, RegistrationReferenceNumber, DecisionDate as RegistrationDate
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 0 AND SubmissionStatus = 'Granted' AND RegistrationReferenceNumber IS NOT NULL
		) as grantedevents WHERE RowNum = 1
	)
	,SubmittedCTE as (
		SELECT *
		FROM (
			SELECT SubmissionId, SubmissionEventId, Comment, DecisionDate as SubmissionDate
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 1
		) as submittedevents WHERE RowNum = 1
	)
	,ResubmissionRegulatorDecisionCTE as (
		SELECT * FROM (
			SELECT SubmissionId, SubmissionEventId, UserId, SubmissionStatus, StatusPendingDate, DecisionDate
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE
			where IsProducerComment = 0
		) as resubmissions
		WHERE RowNum = 1
	)
	,ProducerReSubmissionCTE as (
		SELECT * from (
			SELECT SubmissionId, SubmissionEventId, Comment, DecisionDate
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE
			where IsProducerComment = 1
		) as resubmissions
		where RowNum = 1
	)
	,LatestOrganisationRegistrationSubmissionsCTE
    AS
    (
        SELECT
            a.*
        FROM
            (
            SELECT
                s.SubmissionId
                ,o.Name AS OrganisationName
                ,org.UploadOrgName as UploadedOrganisationName
				,o.ReferenceNumber
				,o.Id as OrganisationInternalId
				,o.ExternalId as OrganisationId
                ,s.AppReferenceNumber AS ApplicationReferenceNumber
                ,CASE 
					WHEN cs.NationId IS NOT NULL THEN cs.NationId
					ELSE
					CASE UPPER(org.NationCode)
						WHEN 'EN' THEN 1
						WHEN 'NI' THEN 2
						WHEN 'SC' THEN 3
						WHEN 'WS' THEN 4
						WHEN 'WA' THEN 4
					 END
				 END AS NationId
                ,CASE
					WHEN cs.NationId IS NOT NULL THEN
						CASE cs.NationId
							WHEN 1 THEN 'GB-ENG'
							WHEN 2 THEN 'GB-NIR'
							WHEN 3 THEN 'GB-SCT'
							WHEN 4 THEN 'GB-WLS'
						END
					ELSE
					CASE UPPER(org.NationCode)
						WHEN 'EN' THEN 'GB-ENG'
						WHEN 'NI' THEN 'GB-NIR'
						WHEN 'SC' THEN 'GB-SCT'
						WHEN 'WS' THEN 'GB-WLS'
						WHEN 'WA' THEN 'GB-WLS'
					END
				 END AS NationCode
                ,registrationdecision.RegistrationReferenceNumber
				,registrationdecision.RegistrationDate
				,SubmittedCTE.SubmissionDate as SubmittedDateTime
                ,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
						AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
						CASE WHEN regulatorresubmissiondecision.DecisionDate IS NULL THEN 1
							 WHEN regulatorresubmissiondecision.DecisionDate > resubmission.DecisionDate AND regulatorresubmissiondecision.SubmissionStatus = 'Granted' 
							 THEN 0
							 ELSE 1 END
					  ELSE 0
				 END as IsResubmission
				,CASE when registrationdecision.RegistrationDate IS NOT NULL THEN 'Granted'
					  else CASE WHEN regulatorresubmissiondecision.SubmissionStatus IS NULL Then 'Pending'
						   ELSE regulatorresubmissiondecision.SubmissionStatus END
				 END as SubmissionStatus
				,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
						AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
						CASE WHEN regulatorresubmissiondecision.DecisionDate > resubmission.DecisionDate THEN regulatorresubmissiondecision.SubmissionStatus
							 ELSE 'Pending' END
					  ELSE NULL
				 END as ResubmissionStatus
				,regulatorresubmissiondecision.DecisionDate as RegulatorDecisionDate
				,regulatorresubmissiondecision.StatusPendingDate
				,ISNULL(resubmission.Comment, SubmittedCTE.Comment) 
				 as ProducerComment
				,s.SubmissionPeriod
                ,CAST(
                    SUBSTRING(
                        s.SubmissionPeriod,
                        PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
                        4
                    ) AS INT
                 ) AS RelevantYear
				,CASE UPPER(TRIM(org.organisationsize))
					WHEN 'S' THEN 'Small'
					WHEN 'L' THEN 'Large'
				 END 
				 as ProducerSize
				,CASE WHEN s.ComplianceSchemeId is not null THEN 1 ELSE 0 END 
				 as IsComplianceScheme
				,registrationdecision.UserId as RegulatorUserId
				,SubmittedCTE.SubmissionEventId as ProducerSubmissionEventId
				,registrationdecision.SubmissionEventId as RegulatorGrantedEventId
				,regulatorresubmissiondecision.SubmissionEventId as ResubmissionDecisionEventId
				,resubmission.SubmissionEventId as ResubmissionEventId
            	,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
						AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
						resubmission.DecisionDate END as ResubmissionDate
				,s.OrganisationId AS InternalOrgId
                ,s.SubmissionType
                ,s.UserId AS SubmittedUserId
                ,CAST(
                    CASE
                        WHEN SubmittedCTE.SubmissionDate > DATEFROMPARTS(CONVERT( int, SUBSTRING(
                                        s.SubmissionPeriod,
                                        PATINDEX('%[0-9][0-9][0-9][0-9]', s.SubmissionPeriod),
                                        4
                                    )),4,1) THEN 1
                        ELSE 0
                    END AS BIT
                ) AS IsLateSubmission
				,ROW_NUMBER() OVER (
                    PARTITION BY s.OrganisationId,
                    s.SubmissionPeriod, s.ComplianceSchemeId
                    ORDER BY s.load_ts DESC
                ) AS RowNum
            FROM
                [rpd].[Submissions] AS s
                INNER JOIN [dbo].[v_UploadedRegistrationDataBySubmissionPeriod] org 
					ON org.SubmittingExternalId = s.OrganisationId 
					and org.SubmissionPeriod = s.SubmissionPeriod
					and org.SubmissionId = s.SubmissionId
				INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
				INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
				LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
				LEFT JOIN RegistrationDecisionCTE as registrationdecision on registrationdecision.submissionid = s.SubmissionId
				LEFT JOIN ProducerReSubmissionCTE resubmission on resubmission.SubmissionId = s.SubmissionId
				LEFT JOIN ResubmissionRegulatorDecisionCTE regulatorresubmissiondecision on regulatorresubmissiondecision.SubmissionId = s.SubmissionId 
            WHERE s.AppReferenceNumber IS NOT NULL
                AND s.SubmissionType = 'Registration'
				ANd s.IsSubmitted = 1
        ) AS a
        WHERE a.RowNum = 1
    )
	,AllSubmissionsAndDecisionsAndCommentCTE
    AS
    (
        SELECT DISTINCT
            submissions.SubmissionId
			,submissions.OrganisationId
			,submissions.OrganisationInternalId
            ,submissions.OrganisationName
			,submissions.UploadedOrganisationName
            ,submissions.ReferenceNumber as OrganisationReference
            ,submissions.SubmittedUserId
            ,submissions.IsComplianceScheme
			,CASE 
				WHEN submissions.IsComplianceScheme = 1 THEN 'Compliance'
				ELSE submissions.ProducerSize
			END AS OrganisationType
            ,submissions.ProducerSize
            ,submissions.ApplicationReferenceNumber
			,submissions.RegistrationReferenceNumber
            ,submissions.SubmittedDateTime
            ,submissions.RegistrationDate
			,submissions.IsResubmission
			,submissions.ResubmissionDate
			,submissions.RelevantYear
            ,submissions.SubmissionPeriod
            ,submissions.IsLateSubmission
            ,ISNULL(submissions.SubmissionStatus, 'Pending') as SubmissionStatus
            ,submissions.ResubmissionStatus
			,RegulatorDecisionDate
			,StatusPendingDate
			--,ProducerComment
            ,submissions.NationId
            ,submissions.NationCode
        FROM
            LatestOrganisationRegistrationSubmissionsCTE submissions
		)
    INSERT INTO #TempTable
	SELECT
		DISTINCT *
	FROM
		AllSubmissionsAndDecisionsAndCommentCTE submissions;
	END;
GO
