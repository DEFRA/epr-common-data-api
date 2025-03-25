IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_OrganisationRegistrationSummaries_R9]'))
DROP PROCEDURE [dbo].[sp_OrganisationRegistrationSummaries_R9];
GO

CREATE PROC [dbo].[sp_OrganisationRegistrationSummaries_R9] AS
BEGIN
	SET NOCOUNT ON;

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
					decisions.FileId,
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
			--where RowNum = 1
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
			,FileId
			,RowNum
			,OrderedRowNum
		FROM
			#ProdCommentsRegulatorDecisions as decisions
	)
	,SubmittedCTE as (
		SELECT *
		FROM (
			SELECT SubmissionId, SubmissionEventId, Comment, DecisionDate as SubmissionDate
				   ,FileId ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 1	and FileId IS NULL
		) as submittedevents WHERE RowNum = 1
	)
	,ProducerReSubmissionCTE as (
		SELECT * from (
			SELECT SubmissionId, SubmissionEventId, Comment, DecisionDate as ResubmissionDate
				   ,FileId, ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE
			where IsProducerComment = 1	AND FileId IS NOT NULL
		) as resubmissions
		where RowNum = 1
		AND NOT EXISTS (
				SELECT 1 
				FROM SubmittedCTE s 
				WHERE s.SubmissionEventId = resubmissions.SubmissionEventId
			)
	)
	,RegistrationDecisionCTE as (
		SELECT *
		FROM (
			SELECT SubmissionId, SubmissionEventId, Userid, RegistrationReferenceNumber, 
					DecisionDate as RegistrationDate, FileId
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 0 AND SubmissionStatus = 'Granted' AND RegistrationReferenceNumber IS NOT NULL
		) as grantedevents WHERE RowNum = 1
	)
	,RegulatorResubmissionDecisionCTE AS (
		SELECT *
		FROM (
			SELECT SubmissionId, SubmissionEventId, Userid, RegistrationReferenceNumber, 
					DecisionDate as ResubmissionDecisionDate, FileId, SubmissionStatus as ResubmissionStatus
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 0 
		) as grantedevents WHERE RowNum = 1
	)
	,RegulatorDecisionsCTE as (
		SELECT * FROM (
			SELECT SubmissionId, SubmissionEventId, UserId, SubmissionStatus, 
					StatusPendingDate, DecisionDate, FileId
				   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
			FROM ProdCommentsRegulatorDecisionsCTE
			where IsProducerComment = 0 AND FileId IS NULL
		) as resubmissions
		WHERE RowNum = 1
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
                ,CASE WHEN resubmission.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
				 END as IsResubmission
				,CASE WHEN resubmission.ResubmissionDate IS NOT NULL 
					  THEN
					  	CASE WHEN regulatorresubmissiondecision.ResubmissionDecisionDate IS NOT NULL 
							 		AND regulatorresubmissiondecision.FileId = resubmission.FileId
							 THEN
								  CASE regulatorresubmissiondecision.ResubmissionStatus 
								  	   WHEN 'Granted' 
								  			THEN 'Accepted'
									   WHEN 'Refused'
									   		THEN 'Rejected'
								  END 
						     ELSE 'Pending'
						END
					  ELSE NULL
				 END as ResubmissionStatus
				,CASE WHEN regulatordecisions.DecisionDate IS NOT NULL
						      THEN regulatordecisions.SubmissionStatus
							  ELSE 'Pending'
						 END as SubmissionStatus
				,regulatorresubmissiondecision.ResubmissionDecisionDate
				,regulatordecisions.StatusPendingDate
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
            	,resubmission.ResubmissionDate
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
				INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
				INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
				LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
				LEFT JOIN RegistrationDecisionCTE as registrationdecision on registrationdecision.submissionid = s.SubmissionId
				LEFT JOIN ProducerReSubmissionCTE resubmission on resubmission.SubmissionId = s.SubmissionId
				LEFT JOIN RegulatorResubmissionDecisionCTE regulatorresubmissiondecision on regulatorresubmissiondecision.SubmissionId = s.SubmissionId 
				LEFT JOIN RegulatorDecisionsCTE regulatordecisions on regulatordecisions.SubmissionId = s.SubmissionId 
            WHERE s.AppReferenceNumber IS NOT NULL
                AND s.SubmissionType = 'Registration'
				AND s.IsSubmitted = 1
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
			,ResubmissionDecisionDate
			,StatusPendingDate
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
