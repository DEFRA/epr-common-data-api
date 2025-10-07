/****** Object:  StoredProcedure [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee]    Script Date: 24/04/2025 10:26:16 ******/
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee] @SubmissionId [nvarchar](36) AS

BEGIN

	SET NOCOUNT ON;

	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod nvarchar(100);
	DECLARE @CSOReferenceNumber nvarchar(100);
	DECLARE @ComplianceSchemeId nvarchar(50);
	DECLARE @ApplicationReferenceNumber nvarchar(4000);
	DECLARE @IsComplianceScheme bit;

	DECLARE @SmallLateFeeCutoffDate DATE; 
	DECLARE @CSLLateFeeCutoffDate DATE; 

    SELECT
        @OrganisationIDForSubmission = O.Id 
		,@OrganisationUUIDForSubmission = O.ExternalId 
		,@CSOReferenceNumber = O.ReferenceNumber 
		,@IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
		,@ComplianceSchemeId = S.ComplianceSchemeId
		,@SubmissionPeriod = S.SubmissionPeriod
	    ,@ApplicationReferenceNumber = S.AppReferenceNumber
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;

	DECLARE @RelYear INT = CAST(RIGHT(@SubmissionPeriod, 4) AS INT);	
	
	IF @RelYear < 2026
	BEGIN
		SET @SmallLateFeeCutoffDate = DATEFROMPARTS(@RelYear, 4, 1);
		SET @CSLLateFeeCutoffDate = DATEFROMPARTS(@RelYear, 4, 1);
	END
	ELSE
	BEGIN
		SET @SmallLateFeeCutoffDate = DATEFROMPARTS(@RelYear, 4, 1);
		SET @CSLLateFeeCutoffDate = DATEFROMPARTS(@RelYear - 1, 10, 1);
	END;

    WITH
		SubmissionEventsCTE as (
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
					CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NULL THEN
						CASE
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Accepted' THEN 'Granted'
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Rejected' THEN 'Refused'
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
						ELSE NULL
					END AS SubmissionStatus
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NOT NULL THEN
						CASE
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
						ELSE NULL
					END AS ResubmissionStatus
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NULL THEN 1 ELSE 0 END AS IsRegulatorDecision
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NOT NULL THEN 1 ELSE 0 END AS IsRegulatorResubmissionDecision
					,CASE WHEN decisions.Type = 'Submitted' THEN 1 ELSE 0 END AS UploadEvent 
					,CASE 
						WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 0 THEN 1 ELSE 0
					END AS IsProducerSubmission
					,CASE 
						WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 1 THEN 1 ELSE 0
					END AS IsProducerResubmission
					,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
					,decisions.DecisionDate AS StatusPendingDate
					,ROW_NUMBER() OVER (
						PARTITION BY decisions.SubmissionId, decisions.SubmissionEventId
						ORDER BY decisions.Created DESC
					) AS RowNum
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision', 'Submitted')	
				AND decisions.SubmissionId = @SubmissionId
			) as subevents
			where RowNum = 1
		)
		,ProdSubmissionsRegulatorDecisionsCTE as (
			SELECT
				decisions.SubmissionId
				,decisions.SubmissionEventId
				,decisions.DecisionDate
				,decisions.Comment
				,decisions.UserId
				,decisions.RegistrationReferenceNumber
				,decisions.SubmissionStatus
				,decisions.ResubmissionStatus
				,decisions.StatusPendingDate
				,IsRegulatorDecision
				,IsRegulatorResubmissionDecision
				,IsProducerSubmission
				,IsProducerResubmission
				,UploadEvent
				,[Type]
				,FileId
				,RowNum
			FROM
				SubmissionEventsCTE as decisions
			WHERE decisions.SubmissionId = @SubmissionId
		)
		,LatestFirstUploadedSubmissionEventCTE as (
			select * 
			from (
				select SubmissionId, FileId, DecisionDate as UploadDate, ROW_NUMBER() OVER (order by DecisionDate desc) as RowNum
				from ProdSubmissionsRegulatorDecisionsCTE p
				where UploadEvent = 1
			) x
		)
		,ReconciledSubmissionEvents as (
			select
				SubmissionId
				,SubmissionEventId
				,DecisionDate
				,Comment
				,UserId
				,[Type]
				,(SELECT TOP 1 FileId 
				  from LatestFirstUploadedSubmissionEventCTE upload
				  where upload.UploadDate < decision.DecisionDate
				  order by upload.RowNum asc
				 ) as FileId
				,RegistrationReferenceNumber
				,SubmissionStatus
				,ResubmissionStatus
				,StatusPendingDate
				,IsRegulatorDecision
				,IsRegulatorResubmissionDecision
				,IsProducerSubmission
				,IsProducerResubmission
				,UploadEvent
				,Row_number() over ( order by DecisionDate desc) as RowNum
			from ProdSubmissionsRegulatorDecisionsCTE decision
			where IsProducerSubmission = 1 or IsProducerResubmission = 1 or IsRegulatorDecision = 1	or IsRegulatorResubmissionDecision = 1
		)
		,InitialSubmissionCTE AS (
			SELECT TOP 1 rse.*, cd.organisation_size
			FROM ReconciledSubmissionEvents rse
			inner join rpd.cosmos_file_metadata cfm on cfm.FileId = rse.FileId
			inner join rpd.companydetails cd on cd.filename = cfm.filename
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			ORDER BY RowNum asc
		)
		,FirstSubmissionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			ORDER BY RowNum desc
		)
		,InitialDecisionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			ORDER BY RowNum asc
		)
		,RegistrationDecisionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			AND SubmissionStatus = 'Granted'
			ORDER BY RowNum asc
		)
		,LatestDecisionCTE AS (
			SELECT * FROM (
				SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNumber
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			) t WHERE RowNumber = 1
		)
	    ,ResubmissionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerResubmission = 1
			ORDER BY Rownum asc
		)
		,ResubmissionDecisionCTE AS (
			select * 
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorResubmissionDecision = 1
		)
		,SubmissionStatusCTE AS (
			SELECT TOP 1
				s.SubmissionId
				,CASE WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
				      ELSE COALESCE(ld.SubmissionStatus, reg.SubmissionStatus, id.SubmissionStatus, 'Pending')
				 END as SubmissionStatus
				,s.SubmissionEventId
				,s.Comment as SubmissionComment
				,s.DecisionDate as SubmissionDate
				,fs.DecisionDate as FirstSubmissionDate
				,CASE WHEN @IsComplianceScheme = 1 THEN 'C' ELSE s.organisation_size END as OrganisationType
				,CAST(CASE WHEN @IsComplianceScheme = 1 OR UPPER(TRIM(s.organisation_size)) = 'L' THEN
						CASE
							WHEN fs.DecisionDate > @CSLLateFeeCutoffDate THEN 1
							ELSE 0
						END
				      ELSE
						CASE
							WHEN fs.DecisionDate > @SmallLateFeeCutoffDate THEN 1
							ELSE 0
						END
				 END AS BIT
                ) AS IsLateSubmission
				,s.FileId as SubmittedFileId
				,COALESCE(r.UserId, s.UserId) AS SubmittedUserId			
				,COALESCE(ld.DecisionDate, reg.DecisionDate, id.DecisionDate) as RegulatorDecisionDate
				,reg.DecisionDate AS RegistrationDecisionDate
				,id.StatusPendingDate
				,reg.SubmissionEventId AS RegistrationDecisionEventId

				,CASE
					WHEN r.SubmissionEventId IS NOT NULL AND rd.SubmissionEventId IS NOT NULL THEN rd.ResubmissionStatus
					WHEN r.SubmissionEventId IS NOT NULL THEN 'Pending'
					ELSE NULL
				END AS ResubmissionStatus
				,r.Comment as ResubmissionComment
				,r.SubmissionEventId as ResubmissionEventId
				,r.DecisionDate as ResubmissionDate
				,CAST(CASE WHEN @IsComplianceScheme = 1 OR s.organisation_size = 'L' THEN
						CASE
							WHEN r.DecisionDate > @CSLLateFeeCutoffDate THEN 1
							ELSE 0
						END
						ELSE
						CASE
							WHEN r.DecisionDate > @SmallLateFeeCutoffDate THEN 1
							ELSE 0
						END
				 END AS BIT
                ) AS IsResubmissionLate
				,r.UserId as ResubmittedUserId
				,rd.DecisionDate AS ResubmissionDecisionDate
				,rd.SubmissionEventId AS ResubmissionDecisionEventId

				,COALESCE(rd.Comment, ld.Comment, id.Comment) AS RegulatorComment
				,COALESCE(r.FileId, s.FileId) AS FileId
				,COALESCE(rd.UserId, id.UserId) AS RegulatorUserId
				,COALESCE(r.UserId, s.UserId) as LatestProducerUserId

				,reg.RegistrationReferenceNumber
			FROM InitialSubmissionCTE s
			LEFT JOIN FirstSubmissionCTE fs on fs.SubmissionId = s.SubmissionId
			LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
			LEFT JOIN LatestDecisionCTE ld ON ld.SubmissionId = s.SubmissionId
			LEFT JOIN RegistrationDecisionCTE reg on reg.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionCTE r ON r.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionDecisionCTE rd ON rd.SubmissionId = r.SubmissionId AND rd.FileId = r.FileId
			order by resubmissiondecisiondate desc
		)
		,SubmittedCTE as (
			SELECT SubmissionId, 
					SubmissionEventId, 
					SubmissionComment, 
					SubmittedFileId as FileId, 
					SubmittedUserId,
					SubmissionDate,
					SubmissionStatus
			FROM SubmissionStatusCTE 
		)
		,ResubmissionDetailsCTE as (
			SELECT SubmissionId, 
					ResubmissionEventId, 
					ResubmissionComment, 
					FileId, 
					ResubmittedUserId,
					ResubmissionDate
			FROM SubmissionStatusCTE
		)
		,UploadedDataForOrganisationCTE as (
			select distinct org.*
			FROM
				[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org
				inner join SubmissionStatusCTE ss on ss.FileId = org.CompanyFileId
			WHERE org.UploadingOrgExternalId = @OrganisationUUIDForSubmission
				and org.SubmissionPeriod = @SubmissionPeriod
				and (@ComplianceSchemeId IS NULL OR org.ComplianceSchemeId = @ComplianceSchemeId)
				and (org.CompanyFileId IN (SELECT FileId from SubmissionStatusCTE))
		)
		,UploadedViewCTE as (
			select distinct
				org.UploadingOrgName
				,org.UploadingOrgExternalId
				,CASE WHEN org.IsComplianceScheme = 1 THEN NULL
					  ELSE org.OrganisationSize
				 END as OrganisationSize
				,org.NationCode
				,org.IsComplianceScheme
				,org.CompanyFileId
				,org.CompanyUploadFileName
				,org.CompanyBlobName
				,org.BrandFileId
				,org.BrandUploadFileName
				,org.BrandBlobName
				,org.PartnerUploadFileName
				,org.PartnerFileId
				,org.PartnerBlobName
			FROM
				UploadedDataForOrganisationCTE org 
		)
		,ProducerPaycalParametersCTE
			AS
			(
				SELECT
				OrganisationExternalId
				,OrganisationId
				,ppp.RegistrationSetId
				,FileId
				,FileName
				,ProducerSize
				,IsOnlineMarketplace
				,NumberOfSubsidiaries
				,OnlineMarketPlaceSubsidiaries
				,NumberOfLateSubsidiaries
				FROM
					[dbo].[t_ProducerPaycalParameters_resub] AS ppp
				WHERE ppp.FileId in (SELECT FileId from SubmissionStatusCTE)
		)
		,SubmissionDetails AS (
		    select a.* FROM (
				SELECT
					s.SubmissionId
					,o.Name AS OrganisationName
					,org.UploadingOrgName as UploadedOrganisationName
					,o.ReferenceNumber as OrganisationReferenceNumber
					,org.UploadingOrgExternalId as OrganisationId
					,SubmittedCTE.SubmissionDate as SubmittedDateTime
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,ss.RegistrationReferenceNumber
					,ss.RegistrationDecisionDate as RegistrationDate
					,ss.RegistrationDecisionEventId as RegistrationEventId
            		,ss.ResubmissionDate
					,ss.SubmissionStatus
					,ss.ResubmissionStatus
					,CASE WHEN ss.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
					 END as IsResubmission
					,CASE WHEN ss.ResubmissionDate IS NOT NULL
						THEN ss.FileId 
						ELSE NULL
					 END as ResubmissionFileId
					,ss.RegulatorComment
					,COALESCE(ss.ResubmissionComment, ss.SubmissionComment) as ProducerComment
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
					,ss.RegulatorUserId
					,ss.ResubmissionEventId
					,GREATEST(ss.RegistrationDecisionDate, ss.RegulatorDecisionDate) as RegulatorDecisionDate
					,ss.ResubmissionDecisionDate as RegulatorResubmissionDecisionDate
					,CASE WHEN ss.SubmissionStatus = 'Cancelled' 
						  THEN ss.StatusPendingDate
						  ELSE null
					 END as StatusPendingDate
					,s.SubmissionPeriod
					,CAST(
						SUBSTRING(
							s.SubmissionPeriod,
							PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
							4
						) AS INT
					) AS RelevantYear
					,CAST(ss.IsLateSubmission AS BIT) AS IsLateSubmission
					,CASE UPPER(TRIM(org.organisationsize))
						WHEN 'S' THEN 'Small'
						WHEN 'L' THEN 'Large'
					 END as ProducerSize
					,CONVERT(bit, org.IsComplianceScheme) as IsComplianceScheme
					,CASE 
						WHEN org.IsComplianceScheme = 1 THEN 'Compliance'
						WHEN UPPER(TRIM(org.organisationsize)) = 'S' THEN 'Small'
						WHEN UPPER(TRIM(org.organisationsize)) = 'L' THEN 'Large'
					 END AS OrganisationType
					,CONVERT(bit, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace
					,ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
					,ISNULL(ppp.OnlineMarketPlaceSubsidiaries,0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
					,org.CompanyFileId AS CompanyDetailsFileId
					,org.CompanyUploadFileName AS CompanyDetailsFileName
					,org.CompanyBlobName AS CompanyDetailsBlobName
					,org.BrandFileId AS BrandsFileId
					,org.BrandUploadFileName AS BrandsFileName
					,org.BrandBlobName BrandsBlobName
					,org.PartnerUploadFileName AS PartnershipFileName
					,org.PartnerFileId AS PartnershipFileId
					,org.PartnerBlobName AS PartnershipBlobName
					,ss.LatestProducerUserId as SubmittedUserId
					,s.ComplianceSchemeId
					,@ComplianceSchemeId as CSId
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId
								     ,s.SubmissionPeriod
									 ,s.ComplianceSchemeId
						ORDER BY s.load_ts DESC
					) AS RowNum
				    ,ISNULL(ppp.NumberOfLateSubsidiaries,0) AS NumberOfLateSubsidiaries 
				FROM
					[rpd].[Submissions] AS s
						INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
						INNER JOIN UploadedViewCTE org on org.UploadingOrgExternalId = s.OrganisationId
						INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
						INNER JOIN SubmissionStatusCTE ss on ss.SubmissionId = s.SubmissionId
		                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.OrganisationExternalId = s.OrganisationId
						LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
	    		WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
		,CSSchemeDetailsCTE as (
			select csm.*,
				   re.DecisionDate as FirstApplicationSubmittedDate
			from dbo.v_ComplianceSchemeMembers_resub_latefee csm
				,ReconciledSubmissionEvents re
			where @IsComplianceScheme = 1
				  and csm.CSOReference = @CSOReferenceNumber
				  and csm.SubmissionPeriod = @SubmissionPeriod
				  and csm.ComplianceSchemeId = @ComplianceSchemeId
				  and csm.EarliestFileId = re.FileId and re.Type = 'RegistrationApplicationSubmitted'
		) 
		,ComplianceSchemeMembersCTE as (
			select csm.*
				   ,ss.SubmissionDate as SubmittedOn
				   ,ss.IsLateSubmission
				   ,ss.IsResubmissionLate
				   ,ss.FileId as SubmittedFileId
				   ,ss.FirstSubmissionDate as FirstApplicationSubmissionDate
				   ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 1
						 WHEN ss.ResubmissionDate is not null THEN
							  CASE WHEN csm.joiner_date is not null then 0
								   ELSE 1
							  END
						 ELSE 1 
					END AS IsOriginal				   
				   ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 0
						 WHEN ss.ResubmissionDate is not null THEN
							  CASE WHEN csm.joiner_date is not null then 1
								   ELSE 0
							  END
						  ELSE 0
					END as IsNewJoiner
			from CSSchemeDetailsCTE csm
				,SubmissionStatusCTE ss
			where @IsComplianceScheme = 1
				  and csm.CSOReference = @CSOReferenceNumber
				  and csm.SubmissionPeriod = @SubmissionPeriod
				  and csm.ComplianceSchemeId = @ComplianceSchemeId
				  and csm.FileId = ss.FileId
		)
		,CompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
				,csm.ReferenceNumber
				,csm.RelevantYear
				,ppp.ProducerSize
				,csm.SubmittedDate
				,CASE 
					--Original Submission Was Late So All Members are late
					WHEN UPPER(TRIM(csm.organisation_size)) = 'L' and csm.FirstApplicationSubmissionDate > @CSLLateFeeCutoffDate
					THEN 1
					
					--Original Submission Was Late So All Members are late
					WHEN UPPER(TRIM(csm.organisation_size)) = 'S' and csm.FirstApplicationSubmissionDate > @SmallLateFeeCutoffDate
					THEN 1
					
					--Original Submission Was On Time So Calculate LateFee if joiner_date presesnt
					ELSE
						CASE 
							-- Check if the first application submission date is later than the first application submitted date
							-- and if the joiner date is null
							WHEN csm.FirstApplicationSubmittedDate > csm.FirstApplicationSubmissionDate 
								 AND csm.joiner_date IS NULL 
							THEN 
								-- If true, set the result to 0 (no late fee applicable)
								0 
							ELSE 				
								CASE	
									-- Check the organization size
									WHEN UPPER(TRIM(csm.organisation_size)) = 'S' 
									THEN
										CASE 
											-- Check if the first application submitted date is after the small late fee cutoff date
											WHEN csm.FirstApplicationSubmittedDate > @SmallLateFeeCutoffDate 
											THEN
												-- If true, set the result to 1 (late fee applicable)
												1
											ELSE
												-- If false, set the result to 0 (no late fee applicable)
												0 
										END
									-- For large organizations
									WHEN UPPER(TRIM(csm.organisation_size)) = 'L' 
									THEN
										CASE 
											-- Check if the first application submitted date is after the CSL late fee cutoff date
											WHEN csm.FirstApplicationSubmittedDate > @CSLLateFeeCutoffDate 
											THEN 
												-- If true, set the result to 1 (late fee applicable)
												1
											ELSE 
												-- If false, set the result to 0 (no late fee applicable)
												0 
										END
									-- Fall Back to IsLateSubmission
									ELSE 
										 csm.IsLateSubmission
								END
						END 
					END AS IsLateFeeApplicable_Post2025
				,CASE WHEN csm.IsNewJoiner = 1 THEN csm.IsResubmissionLate
   				      ELSE csm.IsLateSubmission
				  END AS IsLateFeeApplicable
				,csm.OrganisationName
				,csm.leaver_code
				,csm.leaver_date
				,csm.joiner_date
				,csm.organisation_change_reason
				,ppp.IsOnlineMarketPlace
				,ppp.NumberOfSubsidiaries
				,ppp.OnlineMarketPlaceSubsidiaries as NumberOfSubsidiariesBeingOnlineMarketPlace
				,csm.submissionperiod
				,ppp.NumberOfLateSubsidiaries
            FROM
				ComplianceSchemeMembersCTE csm
				INNER JOIN dbo.t_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
				  			AND ppp.FileName = csm.FileName
            WHERE @IsComplianceScheme = 1
        ) 
	   ,JsonifiedCompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
            ,ReferenceNumber
            ,'{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' + '"MemberType": "' + ProducerSize + '", ' + '"IsOnlineMarketPlace": ' + CASE
            WHEN IsOnlineMarketPlace = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(6)) + ', ' + '"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(
            NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(6)
        ) + ', ' + '"NumberOfLateSubsidiaries": ' + CAST(NumberOfLateSubsidiaries AS NVARCHAR(6)) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS nvarchar(16)) + '", ' + '"IsLateFeeApplicable": ' + 
		CASE
            WHEN @RelYear < 2026 THEN
				CASE
					WHEN IsLateFeeApplicable = 1 THEN 'true'
					ELSE 'false'
				END
            ELSE 
				CASE
					WHEN IsLateFeeApplicable_Post2025 = 1 THEN 'true'
					ELSE 'false'
				END
        END
		+ ', ' + '"SubmissionPeriodDescription": "' + submissionperiod + '"}' AS OrganisationDetailsJsonString
            FROM
                CompliancePaycalCTE
        )
    ,AllCompliancePaycalParametersAsJSONCTE
        AS
        (
            SELECT
                CSOReference
            ,'[' + STRING_AGG(CONVERT(nvarchar(max),OrganisationDetailsJsonString), ', ') + ']' AS FinalJson
            FROM
                JsonifiedCompliancePaycalCTE
            WHERE CSOReference = @CSOReferenceNumber
            GROUP BY CSOReference
        )
	SELECT DISTINCT
        r.SubmissionId
        ,r.OrganisationId
        ,r.OrganisationName AS OrganisationName
        ,CONVERT(nvarchar(20), r.OrganisationReferenceNumber) AS OrganisationReference
        ,r.ApplicationReferenceNumber
        ,r.RegistrationReferenceNumber
        ,r.SubmissionStatus
        ,r.StatusPendingDate
        ,r.SubmittedDateTime
        ,r.IsLateSubmission
		,CONVERT(bit, r.IsResubmission) as IsResubmission
        ,CASE WHEN r.IsResubmission = 1 THEN ISNULL(r.ResubmissionStatus, 'Pending') ELSE NULL END as ResubmissionStatus
		,r.RegistrationDate
		,r.ResubmissionDate
		,r.ResubmissionFileId
		,r.SubmissionPeriod
        ,r.RelevantYear
        ,CONVERT(bit, r.IsComplianceScheme) as IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
		,r.RegulatorResubmissionDecisionDate
        ,r.RegulatorUserId
        ,o.CompaniesHouseNumber
        ,o.BuildingName
        ,o.SubBuildingName
        ,o.BuildingNumber
        ,o.Street
        ,o.Locality
        ,o.DependentLocality
        ,o.Town
        ,o.County
        ,o.Country
        ,o.Postcode
        ,r.SubmittedUserId
        ,p.FirstName
        ,p.LastName
        ,p.Email
        ,p.Telephone
        ,sr.Name AS ServiceRole
        ,sr.Id AS ServiceRoleId
        ,r.IsOnlineMarketplace
        ,r.NumberOfSubsidiaries
        ,r.NumberOfSubsidiariesBeingOnlineMarketPlace AS NumberOfOnlineSubsidiaries
        ,r.CompanyDetailsFileId
        ,r.CompanyDetailsFileName
        ,r.CompanyDetailsBlobName
        ,r.PartnershipFileId
        ,r.PartnershipFileName
        ,r.PartnershipBlobName
        ,r.BrandsFileId
        ,r.BrandsFileName
        ,r.BrandsBlobName
		,r.ComplianceSchemeId
		,r.CSId
        ,acpp.FinalJson AS CSOJson
		,r.NumberOfLateSubsidiaries
    FROM
        SubmissionDetails r
        INNER JOIN [rpd].[Organisations] o
			LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber 
			ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
END;
GO
