IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_OrganisationRegistrationSummaries]'))
DROP PROCEDURE [dbo].[sp_OrganisationRegistrationSummaries];
GO

CREATE PROC [dbo].[sp_OrganisationRegistrationSummaries] AS
BEGIN
	SET NOCOUNT ON;

    -- Variable to hold the dynamically constructed SQL query
    DECLARE @ProdCommentsSQL NVARCHAR(MAX);

	SET @ProdCommentsSQL = N'
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
        END AS SubmissionStatus,
        CASE 
            WHEN decisions.Type = ''RegistrationApplicationSubmitted'' THEN 1 ELSE 0
        END AS IsProducerComment,
	';

	IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'DecisionDate' AND [object_id] = OBJECT_ID('rpd.SubmissionEvents')
	)
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        decisions.DecisionDate AS StatusPendingDate,
		')
	END
	ELSE
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        NULL AS StatusPendingDate,
		');
	END;

	IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'RegistrationReferenceNumber' AND [object_id] = OBJECT_ID('rpd.SubmissionEvents')
	)
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber,
		')
	END
	ELSE
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        NULL AS RegistrationReferenceNumber,
		');
	END;

	SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'
            ROW_NUMBER() OVER (
                PARTITION BY decisions.SubmissionId, decisions.Type
                ORDER BY decisions.Created DESC
            ) AS RowNum
        INTO #ProdCommentsRegulatorDecisions
        FROM rpd.SubmissionEvents AS decisions
        WHERE decisions.Type IN (''RegistrationApplicationSubmitted'', ''RegulatorRegistrationDecision'');	');


	IF OBJECT_ID('tempdb..#ProdCommentsRegulatorDecisions') IS NOT NULL
		DROP TABLE #ProdCommentsRegulatorDecisions;
		
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
			FROM
				#ProdCommentsRegulatorDecisions as decisions
			WHERE decisions.Type IN ( 'RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision')
		)
		,GrantedDecisionsCTE as (
			SELECT *
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 0
					AND SubmissionStatus = 'Granted'
		)
        ,LatestGrantedDecisionsCTE as (
			SELECT *
			FROM GrantedDecisionsCTE granteddecision
            WHERE RowNum = 1
		)
		,LatestProducerSubmissionCTE as (
			SELECT *
			FROM ProdCommentsRegulatorDecisionsCTE
            WHERE IsProducerComment = 1 AND RowNum = 1
		)
		,LatestOrganisationRegistrationSubmissionsCTE
		AS
		(
			SELECT
				a.*
			FROM
				(
				SELECT
					o.Name AS OrganisationName
					,org.UploadOrgName as UploadedOrganisationName
					,o.ReferenceNumber
					,o.Id as OrganisationInternalId
					,o.ExternalId as OrganisationId
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,granteddecision.RegistrationReferenceNumber
					,granteddecision.SubmissionStatus
					,granteddecision.DecisionDate as RegulatorDecisionDate
					,granteddecision.UserId as RegulatorUserId
            		,producersubmission.DecisionDate as ProducerCommentDate
					,producersubmission.Comment as ProducerComment
					,producersubmission.SubmissionEventId as ProducerSubmissionEventId
					,granteddecision.SubmissionEventId as RegulatorSubmissionEventId
					,s.SubmissionPeriod
					,s.SubmissionId
					,s.OrganisationId AS InternalOrgId
					,producersubmission.DecisionDate AS SubmittedDateTime
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
					,s.SubmissionType
					,producersubmission.UserId AS SubmittedUserId
					,CAST(
						SUBSTRING(
							s.SubmissionPeriod,
							PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
							4
						) AS INT
					) AS RelevantYear
					,CAST(
						CASE
							WHEN producersubmission.DecisionDate > DATEFROMPARTS(CONVERT( int, SUBSTRING(
											s.SubmissionPeriod,
											PATINDEX('%[0-9][0-9][0-9][0-9]', s.SubmissionPeriod),
											4
										)),4,1) THEN 1	-- 1st April cut-off
							ELSE 0
						END AS BIT
					) AS IsLateSubmission
					,CASE UPPER(TRIM(org.organisationsize))
						WHEN 'S' THEN 'Small'
						WHEN 'L' THEN 'Large'
					END as ProducerSize
					,CASE WHEN s.ComplianceSchemeId is not null THEN 1 ELSE 0 END as IsComplianceScheme
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
					LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
					LEFT JOIN LatestGrantedDecisionsCTE granteddecision on granteddecision.SubmissionId = s.SubmissionId 
					INNER JOIN LatestProducerSubmissionCTE producersubmission on producersubmission.SubmissionId = s.SubmissionId 
						and producersubmission.IsProducerComment = 1
				WHERE s.AppReferenceNumber IS NOT NULL
					AND s.SubmissionType = 'Registration'
					ANd s.IsSubmitted = 1
			) AS a
			WHERE a.RowNum = 1
		)
		,LatestRelatedRegulatorDecisionsCTE AS
		(
			select * from (
				select b.SubmissionId
					,b.SubmissionEventId
					,b.DecisionDate as RegulatorDecisionDate
					,b.Comment as RegulatorComment
					,b.RegistrationReferenceNumber
					,b.SubmissionStatus
					,b.StatusPendingDate
					,b.UserId
					,row_number() over ( partition by submissionid order by decisiondate desc) as RowNum
				from ProdCommentsRegulatorDecisionsCTE as b
				where b.IsProducerComment = 0 
			) as decisions 
			where decisions.RowNum = 1
		)
		,AllRelatedProducerCommentEventsCTE
		AS
		(
			SELECT
				CONVERT(uniqueidentifier, c.SubmissionId) as SubmissionId
				,c.SubmissionEventId
				,c.Comment AS ProducerComment
				,c.DecisionDate AS ProducerCommentDate
			FROM
				(
				SELECT TOP 1
					ProdCommentsRegulatorDecisionsCTE.SubmissionEventId
					,ProdCommentsRegulatorDecisionsCTE.SubmissionId
					,ProdCommentsRegulatorDecisionsCTE.Comment 
					,ProdCommentsRegulatorDecisionsCTE.DecisionDate 
				FROM LatestOrganisationRegistrationSubmissionsCTE 
						LEFT JOIN ProdCommentsRegulatorDecisionsCTE 
						ON ProdCommentsRegulatorDecisionsCTE.IsProducerComment = 1 
						   AND ProdCommentsRegulatorDecisionsCTE.SubmissionId = LatestOrganisationRegistrationSubmissionsCTE.SubmissionId 
				ORDER BY ProdCommentsRegulatorDecisionsCTE.DecisionDate desc
			) AS c
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
				,submissions.ReferenceNumber as OrganisationReferenceNumber
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
				,submissions.RelevantYear
				,submissions.SubmissionPeriod
				,submissions.IsLateSubmission
				,ISNULL(decisions.SubmissionStatus, 'Pending') as SubmissionStatus
				,decisions.StatusPendingDate
				,decisions.RegulatorDecisionDate
				,decisions.UserId as RegulatorUserId
				,ISNULL(submissions.ProducerCommentDate, producercomments.ProducerCommentDate) as ProducerCommentDate
				,ISNULL(submissions.ProducerSubmissionEventId, producercomments.SubmissionEventId) as ProducerSubmissionEventId
				,ISNULL(submissions.RegulatorSubmissionEventId, decisions.SubmissionEventId) AS RegulatorSubmissionEventId
				,submissions.NationId
				,submissions.NationCode
			FROM
				LatestOrganisationRegistrationSubmissionsCTE submissions
				LEFT JOIN LatestRelatedRegulatorDecisionsCTE decisions
					ON decisions.SubmissionId = submissions.SubmissionId
				LEFT JOIN AllRelatedProducerCommentEventsCTE producercomments
					ON producercomments.SubmissionId = submissions.SubmissionId
		)
	INSERT INTO #TempTable
	SELECT
		DISTINCT *
	FROM
		AllSubmissionsAndDecisionsAndCommentCTE submissions;
END;
GO
