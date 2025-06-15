IF EXISTS (SELECT 1 FROM sys.views WHERE object_id = OBJECT_ID(N'[apps].[v_OrganisationRegistrationSummaries]'))
   DROP VIEW [apps].[v_OrganisationRegistrationSummaries];
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [apps].[v_OrganisationRegistrationSummaries]
AS	
    WITH 
	SubmissionEventsCTE as (
		select * from (
			SELECT
				decisions.SubmissionId,
				decisions.SubmissionEventId,
				decisions.Created AS DecisionDate,
				decisions.Comments AS Comment,
				decisions.UserId,
				decisions.Type,
				decisions.FileId,
				CASE 
					WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NULL THEN
						CASE 
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Accepted' THEN 'Granted'
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Rejected' THEN 'Refused'
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
					ELSE NULL
				END AS SubmissionStatus,
				CASE 
					WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NOT NULL THEN
						CASE 
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
					ELSE NULL
				END AS ResubmissionStatus,
				CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NULL THEN 1 ELSE 0 END AS IsRegulatorDecision,
				CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NOT NULL THEN 1 ELSE 0 END AS IsRegulatorResubmissionDecision,
				CASE WHEN decisions.Type = 'Submitted' THEN 1 ELSE 0 END AS UploadEvent,
				CASE 
					WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 0 THEN 1 ELSE 0
				END AS IsProducerSubmission,
				CASE 
					WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 1 THEN 1 ELSE 0
				END AS IsProducerResubmission,
				decisions.RegistrationReferenceNumber,
				decisions.DecisionDate AS StatusPendingDate,
                decisions.load_ts,
				ROW_NUMBER() OVER (PARTITION BY decisions.SubmissionId, decisions.SubmissionEventId ORDER BY decisions.Created DESC) AS RowNum
			FROM rpd.SubmissionEvents AS decisions
			WHERE decisions.Type IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision', 'Submitted')
		) t where t.RowNum = 1
	)
	,LatestUploadsCTE AS (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS UploadOrder
		FROM SubmissionEventsCTE
		WHERE UploadEvent = 1
	)
	,ReconciledSubmissionEvents AS (
		SELECT
			f.SubmissionId,
			f.SubmissionEventId,
			f.DecisionDate,
			f.Comment,
			f.UserId,
			f.Type,
			(SELECT TOP 1 l.FileId FROM LatestUploadsCTE l WHERE l.SubmissionId = f.SubmissionId AND l.DecisionDate < f.DecisionDate ORDER BY l.UploadOrder ASC) AS FileId,
			f.RegistrationReferenceNumber,
			f.SubmissionStatus,
			f.ResubmissionStatus,
			f.StatusPendingDate,
			f.IsRegulatorDecision,
			f.IsRegulatorResubmissionDecision,
			f.IsProducerSubmission,
			f.IsProducerResubmission,
			f.UploadEvent
		FROM SubmissionEventsCTE f
		WHERE f.IsProducerSubmission = 1 OR f.IsProducerResubmission = 1 OR f.IsRegulatorDecision = 1 OR f.IsRegulatorResubmissionDecision = 1
	)
	,InitialSubmissionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
		) t WHERE RowNum = 1
	)
	,FirstSubmissionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate ASC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
		) t WHERE RowNum = 1
	)
	,InitialDecisionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
		) t WHERE RowNum = 1
	)
	,RegistrationDecisionCTE AS (
		SELECT * FROM (
			select *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate ASC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			AND SubmissionStatus = 'Granted'
		) t where RowNum = 1		
	)
	,LatestDecisionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNumber
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
		) t WHERE RowNumber = 1
	)
	,ResubmissionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsProducerResubmission = 1
		) t WHERE RowNum = 1
	)
	,ResubmissionDecisionCTE AS (
		SELECT * FROM (
			SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNum
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorResubmissionDecision = 1
		) t WHERE RowNum = 1
	)
	,SubmissionStatusCTE AS (
		SELECT
			s.SubmissionId,
			CASE WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
				 ELSE COALESCE(ld.SubmissionStatus, id.SubmissionStatus, reg.SubmissionStatus, 'Pending')
				 END AS SubmissionStatus,
			CASE
				WHEN r.SubmissionEventId IS NOT NULL AND rd.SubmissionEventId IS NOT NULL THEN rd.ResubmissionStatus
				WHEN r.SubmissionEventId IS NOT NULL THEN 'Pending'
				ELSE NULL
			END AS ResubmissionStatus,
			s.DecisionDate as SubmissionDate,
			fs.DecisionDate as FirstSubmissionDate,
			s.SubmissionEventId as ProducerSubmissionEventId,
			COALESCE(reg.DecisionDate, ld.DecisionDate, id.DecisionDate) AS RegistrationDate,
			id.SubmissionEventId AS SubmissionDecisionEventId,
			COALESCE(ld.StatusPendingDate, id.StatusPendingDate) as StatusPendingDate,
			COALESCE(ld.DecisionDate, reg.DecisionDate, id.DecisionDate) as RegulatorDecisionDate,
			rd.DecisionDate AS ResubmissionDecisionDate,
			rd.SubmissionEventId AS ResubmissionDecisionEventId,
			r.DecisionDate as ResubmissionDate,
			r.Comment as ResubmissionComment,
			r.UserId as ResubmittedUserId, 
			r.SubmissionEventId AS ResubmissionEventId,
			COALESCE(r.FileId, s.FileId) AS FileId,
			COALESCE(r.UserId, s.UserId) AS ProducerUserId,
			COALESCE(rd.UserId, id.UserId) AS RegulatorUserId,
			reg.RegistrationReferenceNumber,
			COALESCE(r.Comment, s.Comment) as ProducerComment,
			COALESCE(rd.Comment, reg.Comment, id.Comment) as RegulatorComment,
			reg.DecisionDate AS RegistrationDecisionDate
		FROM InitialSubmissionCTE s
        LEFT JOIN FirstSubmissionCTE fs on fs.SubmissionId = s.SubmissionId
		LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
		LEFT JOIN LatestDecisionCTE ld ON ld.SubmissionId = s.SubmissionId
		LEFT JOIN RegistrationDecisionCTE reg on reg.SubmissionId = s.SubmissionId
		LEFT JOIN ResubmissionCTE r ON r.SubmissionId = s.SubmissionId
		LEFT JOIN ResubmissionDecisionCTE rd ON rd.SubmissionId = r.SubmissionId AND rd.FileId = r.FileId
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
                ,ss.RegistrationReferenceNumber
				,ss.RegistrationDate
				,ss.SubmissionDate as SubmittedDateTime
				,ss.FirstSubmissionDate
                ,CASE WHEN ss.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
				 END as IsResubmission
				,ss.ResubmissionStatus
				,ss.SubmissionStatus
				,ss.ResubmissionDecisionDate
				,ss.RegulatorDecisionDate
				,ss.StatusPendingDate
				,ss.ProducerComment
				,ss.RegulatorComment
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
				,ss.RegulatorUserId
				,ss.ProducerSubmissionEventId
				,ss.SubmissionDecisionEventId as RegulatorGrantedEventId
				,ss.ResubmissionDecisionEventId as ResubmissionDecisionEventId
				,ss.ResubmissionEventId as ResubmissionEventId
            	,ss.ResubmissionDate
				,s.OrganisationId AS InternalOrgId
                ,s.SubmissionType
                ,s.UserId AS SubmittedUserId
                ,CAST(
                    CASE
                        WHEN ss.SubmissionDate > DATEFROMPARTS(CONVERT( int, SUBSTRING(
                                        s.SubmissionPeriod,
                                        PATINDEX('%[0-9][0-9][0-9][0-9]', s.SubmissionPeriod),
                                        4
                                    )),4,1) THEN 1
                        ELSE 0
                    END AS BIT
                ) AS IsLateSubmission
				,s.ComplianceSchemeId
				,ss.FileId
				,ss.ResubmissionComment
				,ss.ResubmittedUserId
				,ss.ProducerUserId

				,org.CompanyFileId
				,org.CompanyUploadFileName
				,org.CompanyBlobName
				,org.BrandFileId
				,org.BrandUploadFileName
				,org.BrandBlobName
				,org.PartnerUploadFileName
				,org.PartnerFileId
				,org.PartnerBlobName

				,CONVERT(bit, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace
				,ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
				,ISNULL(ppp.OnlineMarketPlaceSubsidiaries,0) AS NumberOfSubsidiariesBeingOnlineMarketPlace

				,ROW_NUMBER() OVER (
                    PARTITION BY s.OrganisationId,
                    s.SubmissionPeriod, s.ComplianceSchemeId
                    ORDER BY s.Created DESC, s.load_ts DESC
                ) AS RowNum
            FROM
                [rpd].[Submissions] AS s
				INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
				INNER JOIN SubmissionStatusCTE ss on ss.SubmissionId = s.SubmissionId
                INNER JOIN [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org 
					ON org.UploadingOrgExternalId = s.OrganisationId 
					and org.SubmissionPeriod = s.SubmissionPeriod
					and (s.ComplianceSchemeId is NULL OR org.ComplianceSchemeId = s.ComplianceSchemeId)
					and org.CompanyFileId = ss.FileId
		        INNER JOIN [dbo].[v_ProducerPaycalParameters_resub] AS ppp on ppp.FileId = ss.FileId
				LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
            WHERE s.AppReferenceNumber IS NOT NULL
                AND s.SubmissionType = 'Registration'
				AND s.IsSubmitted = 1
        ) AS a
        WHERE a.RowNum = 1
    )

   -- SELECT * FROM LatestOrganisationRegistrationSubmissionsCTE
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
			,submissions.FirstSubmissionDate
            ,submissions.RegistrationDate
			,submissions.IsResubmission
			,submissions.ResubmissionDate
			,submissions.RelevantYear
            ,submissions.SubmissionPeriod
            ,submissions.IsLateSubmission
            ,ISNULL(submissions.SubmissionStatus, 'Pending') as SubmissionStatus
            ,submissions.ResubmissionStatus
			,ResubmissionDecisionDate
			,RegulatorDecisionDate
			,StatusPendingDate
            ,submissions.NationId
            ,submissions.NationCode
			,submissions.ComplianceSchemeId
			,submissions.ProducerComment
			,submissions.RegulatorComment
			,submissions.FileId
			,submissions.ResubmissionComment
			,submissions.ResubmittedUserId
			,submissions.ProducerUserId
			,submissions.RegulatorUserId

			,CompanyFileId
			,CompanyUploadFileName
			,CompanyBlobName
			,BrandFileId
			,BrandUploadFileName
			,BrandBlobName
			,PartnerUploadFileName
			,PartnerFileId
			,PartnerBlobName

			,IsOnlineMarketplace
			,NumberOfSubsidiaries
			,NumberOfSubsidiariesBeingOnlineMarketPlace
        FROM
            LatestOrganisationRegistrationSubmissionsCTE submissions
		)
	SELECT
		DISTINCT *
	FROM
		AllSubmissionsAndDecisionsAndCommentCTE submissions;
GO
