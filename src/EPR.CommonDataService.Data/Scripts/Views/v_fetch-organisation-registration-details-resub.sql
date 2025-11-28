﻿/****** Object:  View [dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub]    Script Date: 04/11/2025 12:05:17 ******/
IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub]')
) DROP VIEW [dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub];
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON


CREATE VIEW [dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub] AS WITH 
derivered_variables as
(SELECT 
   O.Id  as OrganisationIDForSubmission
  ,O.ExternalId as OrganisationUUIDForSubmission
  ,O.ReferenceNumber as CSOReferenceNumber
  ,CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END as IsComplianceScheme
  ,S.ComplianceSchemeId as ComplianceSchemeId
  ,S.SubmissionPeriod as SubmissionPeriod
  ,S.AppReferenceNumber as ApplicationReferenceNumber
  ,s.submissionid as submissionid
  -- converted in to new columns 
  ,CASE WHEN RIGHT(s.SubmissionPeriod, 4) LIKE '%[^0-9]%' THEN NULL 
  ELSE CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) END AS RelYear
  --,RIGHT(s.SubmissionPeriod, 4) as RelYear
  -- SmallLateFeeCutoffDate is always DATEFROMPARTS(RelYear, 4, 1), regardless of condition
  ,CASE WHEN RIGHT(s.SubmissionPeriod, 4) LIKE '%[^0-9]%' THEN NULL 
  ELSE DATEFROMPARTS(RIGHT(s.SubmissionPeriod, 4), 4, 1) END AS SmallLateFeeCutoffDate
 -- , DATEFROMPARTS(RIGHT(s.SubmissionPeriod, 4), 4, 1) AS SmallLateFeeCutoffDate 
        -- CSLLateFeeCutoffDate varies based on RelYear
 -- ,CASE WHEN RIGHT(s.SubmissionPeriod, 4) < 2026 THEN DATEFROMPARTS(RIGHT(s.SubmissionPeriod, 4), 4, 1) ELSE DATEFROMPARTS(RIGHT(s.SubmissionPeriod, 4) - 1, 8, 27) END AS CSLLateFeeCutoffDate
 ,CASE  WHEN TRY_CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) IS NOT NULL 
         AND RIGHT(s.SubmissionPeriod, 4) NOT LIKE '%[^0-9]%'   
    THEN 
        CASE 
            WHEN RIGHT(s.SubmissionPeriod, 4) < '2026' 
            THEN DATEFROMPARTS(CAST(RIGHT(s.SubmissionPeriod, 4) AS INT), 4, 1)
            ELSE DATEFROMPARTS(CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) - 1, 10, 11)
        END
    ELSE NULL
END AS CSLLateFeeCutoffDate
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
  where TRY_CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) IS NOT NULL)
 --    
,		SubmissionEventsCTE as (
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
					,decisions.IsResubmission
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision', 'Submitted')	
				--AND decisions.SubmissionId = @SubmissionId
			) as subevents
			where RowNum = 1
		)
		
,LatestRegistrationApplicationSubmittedCTE as (
			select sev.SubmissionId,
			       sev.SubmissionEventId,
       			sev.DecisionDate as LatestRegistrationApplicationSubmittedDate,
				ROW_NUMBER() OVER (partition by sev.submissionid ,sev.SubmissionEventId order by sev.DecisionDate desc) as RowNum
			from SubmissionEventsCTE sev
			where sev.type = 'RegistrationApplicationSubmitted'
			and RowNum = 1
	)	
	
	
--	
	,LatestFirstUploadedSubmissionEventCTE AS (
     select SubmissionId,SubmissionEventId, FileId, DecisionDate as UploadDate, ROW_NUMBER() OVER (partition by submissionid /*,SubmissionEventId*/ order by DecisionDate desc) as RowNum
       from SubmissionEventsCTE p
      where UploadEvent = 1
	)
--		
	,latest_file_id as (
	    select x.FileId,x.SubmissionId,x.SubmissionEventId,RowNum from (     
		SELECT  upload.FileId,decision.SubmissionId,decision.SubmissionEventId,
		ROW_NUMBER() OVER (PARTITION BY decision.SubmissionId,decision.SubmissionEventId ORDER BY upload.RowNum asc) AS RowNum
		from SubmissionEventsCTE decision  
		left join LatestFirstUploadedSubmissionEventCTE upload on decision.submissionid=upload.submissionid
		--and decision.submissionid=upload.submissionid
		and upload.UploadDate < decision.DecisionDate
		--order by upload.RowNum asc
		) x where x.RowNum=1
	   )
--
	,ReconciledSubmissionEvents 
	as (
	    select
		decision.SubmissionId
		,decision.SubmissionEventId
		,DecisionDate
		,Comment
		,UserId
		,[Type]
		,lf.FileId
		,RegistrationReferenceNumber
		,SubmissionStatus
		,ResubmissionStatus
		,StatusPendingDate
		,IsRegulatorDecision
		,IsRegulatorResubmissionDecision
		,IsProducerSubmission
		,IsProducerResubmission
		,UploadEvent
		,Row_number() over ( partition by decision.submissionid order by DecisionDate desc) as RowNum
	   from SubmissionEventsCTE decision
	   left join latest_file_id lf on lf.submissionid=decision.submissionid
	   and lf.SubmissionEventId=decision.SubmissionEventId
	   where IsProducerSubmission = 1 or IsProducerResubmission = 1 or IsRegulatorDecision = 1 or IsRegulatorResubmissionDecision = 1
	 )
--
	,InitialSubmissionCTE 
	AS (
		select * from (
			SELECT /* TOP 1 */ rse.*, cd.organisation_size, Row_number() over ( partition by rse.submissionid ORDER BY RowNum asc) as RowNumber
			FROM ReconciledSubmissionEvents rse
			inner join rpd.cosmos_file_metadata cfm on cfm.FileId = rse.FileId
			inner join rpd.companydetails cd on cd.filename = cfm.filename
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			--ORDER BY RowNum asc
			) x
			where x.RowNumber = 1
		)
--
		,FirstSubmissionCTE 
		AS (
		    select * from (
			SELECT /*TOP 1*/ *, Row_number() over ( partition by submissionid ORDER BY RowNum desc) as RowNumber
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			--ORDER BY RowNum desc
			) x 
			where x.RowNumber = 1
		)
--
		,InitialDecisionCTE 
		AS (
		select * from (
			SELECT /* TOP 1 */ *, Row_number() over ( partition by submissionid ORDER BY RowNum asc) as RowNumber
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			--ORDER BY RowNum asc
			) x
			where x.RowNumber = 1
		)
--
	,RegistrationDecisionCTE
	 AS (
		select * from (
			SELECT /* TOP 1 */ *, Row_number() over ( partition by submissionid ORDER BY RowNum asc) as RowNumber
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			AND SubmissionStatus = 'Granted'
			--ORDER BY RowNum asc
			) x
			where x.RowNumber = 1
		)
--
		,LatestDecisionCTE 
		AS (
			SELECT * FROM (
				SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNumber
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			) t WHERE RowNumber = 1
		)
--
	    ,ResubmissionCTE
		AS (
		    select * from (
			SELECT /* TOP 1 */ *, Row_number() over ( partition by submissionid ORDER BY Rownum asc) as RowNumber
			FROM ReconciledSubmissionEvents
			WHERE IsProducerResubmission = 1
			--ORDER BY Rownum asc
			) x 
			where x.RowNumber = 1
		)
--	
		,ResubmissionDecisionCTE 
		AS (
			select * 
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorResubmissionDecision = 1
		)
--	
	,SubmissionStatusCTE
	AS (
		select * from (
			SELECT /* TOP 1 */
				s.SubmissionId
				,CASE WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
				      ELSE COALESCE(ld.SubmissionStatus, reg.SubmissionStatus, id.SubmissionStatus, 'Pending')
				 END as SubmissionStatus
				,s.SubmissionEventId
				,s.Comment as SubmissionComment
				,s.DecisionDate as SubmissionDate
				,fs.DecisionDate as FirstSubmissionDate
				,CASE WHEN vars.IsComplianceScheme = 1 THEN 'C' ELSE s.organisation_size END as OrganisationType -- removed @IsComplianceScheme var
				,CAST(CASE WHEN vars.IsComplianceScheme = 1 OR UPPER(TRIM(s.organisation_size)) = 'L' THEN -- removed @IsComplianceScheme --added DG1 UPPER clasue
						CASE
							WHEN fs.DecisionDate > vars.CSLLateFeeCutoffDate THEN 1 --removed @CSLLateFeeCutoffDate var
							ELSE 0
						END
				      ELSE
						CASE
							WHEN fs.DecisionDate > vars.SmallLateFeeCutoffDate THEN 1 --removed @SmallLateFeeCutoffDate var
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
				,CAST(CASE WHEN vars.IsComplianceScheme = 1 OR s.organisation_size = 'L' THEN --removed @IsComplianceScheme var
						CASE
							WHEN r.DecisionDate > vars.CSLLateFeeCutoffDate THEN 1 --removed @CSLLateFeeCutoffDate
							ELSE 0
						END
						ELSE
						CASE
							WHEN r.DecisionDate > vars.SmallLateFeeCutoffDate THEN 1 --removed @SmallLateFeeCutoffDate
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
				-- row number to emulate TOP1 for each submission id by rd.DecisionDate aka ResubmissionDecisionDate as per the original query
				,Row_number() over ( partition by s.submissionid order by rd.DecisionDate desc) as RowNumber 
			FROM InitialSubmissionCTE s
			LEFT JOIN FirstSubmissionCTE fs on fs.SubmissionId = s.SubmissionId
			LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
			LEFT JOIN LatestDecisionCTE ld ON ld.SubmissionId = s.SubmissionId
			LEFT JOIN RegistrationDecisionCTE reg on reg.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionCTE r ON r.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionDecisionCTE rd ON rd.SubmissionId = r.SubmissionId AND rd.FileId = r.FileId
			LEFT JOIN derivered_variables vars ON vars.SubmissionId = s.SubmissionId -- added join to variables CTE
			--order by resubmissiondecisiondate desc
			) x
			where x.RowNumber = 1
		)
--	
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
--
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
   select distinct org.*, ss.SubmissionId -- added SubmissionId column
   FROM
    [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org
    inner join SubmissionStatusCTE ss on ss.FileId = org.CompanyFileId
    left join derivered_variables dv on dv.submissionid = ss.submissionid  -- added newly
    and dv.OrganisationUUIDForSubmission = org.UploadingOrgExternalId -- added newly
   --WHERE org.UploadingOrgExternalId = OrganisationUUIDForSubmission
    and org.SubmissionPeriod = dv.SubmissionPeriod
    and (dv.ComplianceSchemeId IS NULL OR org.ComplianceSchemeId = dv.ComplianceSchemeId)
    and (org.CompanyFileId IN (SELECT FileId from SubmissionStatusCTE))
	)	
--
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
				,org.SubmissionId -- added SubmissionId column
			FROM
				UploadedDataForOrganisationCTE org 
		)
			,ProducerPaycalParametersCTE
			AS
			(
				SELECT
				OrganisationExternalId
				,ppp.OrganisationId
				,ppp.RegistrationSetId
				,ppp.FileId
				,ppp.FileName
				,ppd.ProducerSize
				,IsOnlineMarketplace
				,NumberOfSubsidiaries
				,OnlineMarketPlaceSubsidiaries
				,dv.SubmissionId -- added SubmissionId column
				FROM
					[dbo].[t_ProducerPaycalParameters_resub] AS ppp
					left join [rpd].[cosmos_file_metadata] c on c.FileName=ppp.FileName -- added [cosmos_file_metadata] to join to derivered_variables
					left join derivered_variables dv ON dv.SubmissionId = c.SubmissionId -- added join to derived variables to get submissionId
				WHERE ppp.FileId in (SELECT FileId from SubmissionStatusCTE)
		)
--	 
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
					,d.ComplianceSchemeId as CSId -- removed @ComplianceSchemeId
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId
								     ,s.SubmissionPeriod
									 ,s.ComplianceSchemeId
									 ,s.submissionId -- SubmissionId added to partition by
						ORDER BY s.load_ts DESC
					) AS RowNum
				FROM
					[rpd].[Submissions] AS s
						INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
						LEFT JOIN UploadedViewCTE org on org.UploadingOrgExternalId = s.OrganisationId and org.SubmissionId = s.SubmissionId --changed to left join and added submissionId to join condition
						INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
						INNER JOIN SubmissionStatusCTE ss on ss.SubmissionId = s.SubmissionId
		                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.OrganisationExternalId = s.OrganisationId and ppp.SubmissionId = s.SubmissionId --added submissionId to join condition
						LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
						left join derivered_variables d on d.SubmissionId  = s.SubmissionId --and d.ComplianceSchemeId=s.ComplianceSchemeId
	    		WHERE s.SubmissionId = d.SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
		
-- new code from DG1
	,CSSchemeDetailsCTE as (
			select distinct csm.*,
				   re.DecisionDate as FirstApplicationSubmittedDate
            from  dbo.v_ComplianceSchemeMembers_resub_latefee csm 
				,ReconciledSubmissionEvents re
				,derivered_variables vars
			where vars.IsComplianceScheme = 1
				  and csm.CSOReference = vars.CSOReferenceNumber
				  and csm.SubmissionPeriod = vars.SubmissionPeriod
				  and csm.ComplianceSchemeId = vars.ComplianceSchemeId
				  and csm.EarliestFileId = re.FileId 
				  and re.Type = 'RegistrationApplicationSubmitted'
			      and vars.SubmissionId = re.SubmissionId -- added join to variables CTE */
		) 
		--
,ComplianceSchemeMembersCTE as
         ( select   s.* from (select csm.*
		  		   ,ss.SubmissionId
				   ,ss.SubmissionDate as SubmittedOn
				   ,ss.IsLateSubmission
				   ,ss.IsResubmissionLate
				   ,ss.FileId as SubmittedFileId
				   ,ss.FirstSubmissionDate as FirstApplicationSubmissionDate
				    ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 1
						 WHEN csm.EarliestSubmissionDate <= ss.RegistrationDecisionDate AND csm.joiner_date is null THEN 1
						 WHEN csm.joiner_date is null THEN 1
						 ELSE 0 END
					AS IsOriginal
				   ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 0
						 WHEN csm.EarliestSubmissionDate <= ss.RegistrationDecisionDate THEN 0
					     WHEN ( csm.EarliestSubmissionDate > ss.RegistrationDecisionDate and csm.joiner_date is not null) THEN 1
					     WHEN ( csm.EarliestSubmissionDate > ss.RegistrationDecisionDate and csm.joiner_date is null) THEN 0
					END as IsNewJoiner
			from CSSchemeDetailsCTE csm 		--	     dbo.v_ComplianceSchemeMembers_resub csm --replaced by DG1 confirmation.
				,SubmissionStatusCTE ss
				where csm.FileId = ss.FileId)s
				  left join derivered_variables vars on vars.SubmissionId = s.SubmissionId
			where vars.IsComplianceScheme = 1 --removed @IsComplianceScheme
				  and s.CSOReference = vars.CSOReferenceNumber--removed @CSOReferenceNumber
				  and s.SubmissionPeriod = vars.SubmissionPeriod-- removed @SubmissionPeriod
				  and s.ComplianceSchemeId = vars.ComplianceSchemeId--removed @ComplianceSchemeId
				  
		)
--
		,CompliancePaycalCTE   AS  (
            SELECT distinct
                CSOReference
				,csm.ReferenceNumber
				,csm.RelevantYear
				,ppp.ProducerSize
				,csm.SubmittedDate
				--new code added as per DG6
				,CASE 
					--Resubmission - Use pre-existing Logic
					WHEN ss.ResubmissionDate is not null
					THEN 
						CASE WHEN csm.IsNewJoiner = 1 THEN csm.IsResubmissionLate
   							  ELSE csm.IsLateSubmission
						END
					-- Latest Submission On Time for Member Type
					WHEN UPPER(TRIM(csm.organisation_size)) = 'L' and lras.LatestRegistrationApplicationSubmittedDate <=  vars.CSLLateFeeCutoffDate
					THEN 
						-- If true, set the result to 0 (no late fee applicable)
						0
					-- Latest Submission On Time for Member Type
					WHEN UPPER(TRIM(csm.organisation_size)) = 'S' and lras.LatestRegistrationApplicationSubmittedDate <= vars.SmallLateFeeCutoffDate
					THEN 
						-- If true, set the result to 0 (no late fee applicable)
						0
					--Original Submission Was Late So All Members are late
					WHEN UPPER(TRIM(csm.organisation_size)) = 'L' and csm.FirstApplicationSubmissionDate > vars.CSLLateFeeCutoffDate
					THEN 1
					--Original Submission Was Late So All Members are late
					WHEN UPPER(TRIM(csm.organisation_size)) = 'S' and csm.FirstApplicationSubmissionDate > vars.SmallLateFeeCutoffDate
					THEN 1
					--Original Submission Was On Time So Calculate LateFee if joiner_date presesnt
					ELSE
						CASE 
							-- Check if the first application submission date is later than the first application submitted date
							-- and if the joiner date is null
							WHEN csm.FirstApplicationSubmittedDate >  csm.FirstApplicationSubmissionDate 
								 AND csm.joiner_date IS NULL 
							THEN 
								-- If true, set the result to 0 (no late fee applicable)
								0 
							--Updated Submission, Joiner Date Not Null
							WHEN csm.FirstApplicationSubmittedDate >  csm.FirstApplicationSubmissionDate 
								 AND csm.joiner_date IS NOT NULL 
							THEN 
								-- If true, set the result to 1 (late fee applicable)
								1
							ELSE 				
								CASE	
									-- Check the organization size
									WHEN UPPER(TRIM(csm.organisation_size)) = 'S' 
									THEN
										CASE 
											-- Check if the first application submitted date is after the small late fee cutoff date
											WHEN csm.FirstApplicationSubmittedDate > vars.SmallLateFeeCutoffDate 
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
											WHEN csm.FirstApplicationSubmittedDate > vars.CSLLateFeeCutoffDate 
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
					END 
					AS IsLateFeeApplicable_Post2025
				-- code end
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
				,csm.SubmissionId
            FROM
				ComplianceSchemeMembersCTE csm
				INNER JOIN dbo.t_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
				  			AND ppp.FileName = csm.FileName
				--left join [rpd].[cosmos_file_metadata] c on c.FileName=csm.FileName  --added [cosmos_file_metadata] to join to derivered_variables
				left join derivered_variables vars on vars.SubmissionId = csm.SubmissionId 
				left join SubmissionStatusCTE ss on ss.SubmissionId =csm.SubmissionId
				left Join LatestRegistrationApplicationSubmittedCTE lras on lras.SubmissionId =csm.SubmissionId
	        WHERE vars.IsComplianceScheme = 1 --removed @IsComplianceScheme
		--	and csm.SubmissionId ='51934dc1-d73c-48bb-a4f5-d20cc300b456'
        ) 
	   ,JsonifiedCompliancePaycalCTE AS (
                
            SELECT
            cs.CSOReference
            ,cs.ReferenceNumber
			,cs.SubmissionId -- added SubmissionId
            ,'{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' + '"MemberType": "' + ProducerSize + '", ' + '"IsOnlineMarketPlace": ' + CASE
            WHEN IsOnlineMarketPlace = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(6)) + ', ' + '"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(
            NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(6)
        ) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS nvarchar(16)) + '", ' + '"IsLateFeeApplicable": ' + 
		CASE
            WHEN vars.RelYear < 2026 THEN
				CASE
					WHEN IsLateFeeApplicable = 1 THEN 'true'
					ELSE 'false'
				END
            ELSE 
				CASE
					WHEN IsLateFeeApplicable_Post2025 = 1 THEN 'true'
					ELSE 'false'
				END
        END + ', ' + '"SubmissionPeriodDescription": "' + cs.submissionperiod + '"}' AS OrganisationDetailsJsonString
            FROM
                CompliancePaycalCTE cs 	left join derivered_variables vars on vars.SubmissionId = cs.SubmissionId 
		--	and cs.SubmissionId ='51934dc1-d73c-48bb-a4f5-d20cc300b456'
        )
	
    ,AllCompliancePaycalParametersAsJSONCTE as ( 
                
            SELECT
                vars.SubmissionId,js.CSOReference
            ,'[' + STRING_AGG(CONVERT(nvarchar(max),OrganisationDetailsJsonString), ', ') + ']' AS FinalJson
            FROM
                JsonifiedCompliancePaycalCTE js
				left join derivered_variables vars on vars.SubmissionId = js.SubmissionId
            WHERE js.CSOReference = vars.CSOReferenceNumber  --removed @CSOReferenceNumber
            GROUP BY vars.SubmissionId,js.CSOReference
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
    FROM
        SubmissionDetails r
        INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId 		
		LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber and acpp.SubmissionId = r.SubmissionId --added submissionId to join condition
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
GO


