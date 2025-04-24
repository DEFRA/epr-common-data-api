/****** Object:  StoredProcedure [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub]    Script Date: 24/04/2025 10:26:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub] @SubmissionId [nvarchar](36) AS

BEGIN
SET NOCOUNT ON;

	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod nvarchar(100);
	DECLARE @CSOReferenceNumber nvarchar(100);
	DECLARE @ComplianceSchemeId nvarchar(50);
	DECLARE @ApplicationReferenceNumber nvarchar(4000);
	DECLARE @IsComplianceScheme bit;

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
		,ReconciledSubmissionEvents as (		-- applies fileId to corresponding events
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
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			ORDER BY RowNum asc
		)
		,InitialDecisionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			ORDER BY RowNum asc
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
				-- Submission Status comes from initial regulator decision if any, else 'Pending'
                ,CASE WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
					  ELSE COALESCE(id.SubmissionStatus, 'Pending') 
				 END AS SubmissionStatus
				,s.SubmissionEventId
				,s.Comment as SubmissionComment
				,s.DecisionDate as SubmissionDate
				,s.FileId as SubmittedFileId
				-- Join on matching FileId for resubmission decision
				,COALESCE(r.UserId, s.UserId) AS SubmittedUserId			
				
				,id.DecisionDate AS RegistrationDecisionDate
				,id.StatusPendingDate
				,id.SubmissionEventId AS RegistrationDecisionEventId

				,CASE
					WHEN r.SubmissionEventId IS NOT NULL AND rd.SubmissionEventId IS NOT NULL THEN rd.ResubmissionStatus
					WHEN r.SubmissionEventId IS NOT NULL THEN 'Pending'
					ELSE NULL
				END AS ResubmissionStatus
				,r.Comment as ResubmissionComment
				,r.SubmissionEventId as ResubmissionEventId
				,r.DecisionDate as ResubmissionDate
				,r.UserId as ResubmittedUserId
				,rd.DecisionDate AS ResubmissionDecisionDate
				,rd.SubmissionEventId AS ResubmissionDecisionEventId

				,COALESCE(rd.Comment, id.Comment) AS RegulatorComment
				,COALESCE(r.FileId, s.FileId) AS FileId
				,COALESCE(rd.UserId, id.UserId) AS RegulatorUserId
				,COALESCE(r.UserId, s.UserId) as LatestProducerUserId

				,id.RegistrationReferenceNumber
			FROM InitialSubmissionCTE s
			LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
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
		,AppropriateSubmissionDateCTE as (
			SELECT S.SubmissionDate, P.ResubmissionDate 
			FROM SubmittedCTE S LEFT JOIN ResubmissionDetailsCTE P
			ON P.SubmissionId = S.SubmissionId
		)
		,UploadedDataForOrganisationCTE as (
			select *, Row_Number() over (partition by UploadingOrgExternalId, SubmissionPeriod, ComplianceSchemeId order by UploadDate desc) as UpSeq
			FROM
				[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org 
			WHERE org.UploadingOrgExternalId = @OrganisationUUIDForSubmission
				and org.SubmissionPeriod = @SubmissionPeriod
				and @ComplianceSchemeId IS NULL OR org.ComplianceSchemeId = @ComplianceSchemeId
		)
		,UploadedViewCTE as (
			select * from (
				select *, Row_Number() over (order by UpSeq asc) as RowNum
				FROM
					UploadedDataForOrganisationCTE org 
				WHERE org.UploadDate <= (SELECT ISNULL(ResubmissionDate, SubmissionDate) FROM AppropriateSubmissionDateCTE)
			) uploadeddata where RowNum = 1
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
				FROM
					[dbo].[v_ProducerPaycalParameters_resub] AS ppp
				inner join UploadedViewCTE udc on udc.CompanyFileName = ppp.FileName
			WHERE ppp.OrganisationExternalId = @OrganisationUUIDForSubmission
		)
		,SubmissionDetails AS (
		    select a.* FROM (
				SELECT
					s.SubmissionId
					,o.Name AS OrganisationName
					,org.UploadOrgName as UploadedOrganisationName
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
					,GREATEST(ss.RegistrationDecisionDate,ss.ResubmissionDecisionDate) as RegulatorDecisionDate
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
					,CASE UPPER(TRIM(org.organisationsize))
						WHEN 'S' THEN 'Small'
						WHEN 'L' THEN 'Large'
					 END as ProducerSize
					,org.IsComplianceScheme
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
		,ComplianceSchemeMembersCTE as (
			select *
			from dbo.v_ComplianceSchemeMembers csm
			where @IsComplianceScheme = 1
				  and csm.CSOReference = @CSOReferenceNumber
				  and csm.SubmissionPeriod = @SubmissionPeriod
				  and csm.ComplianceSchemeId = @ComplianceSchemeId
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
				,csm.IsLateFeeApplicable
				,ppp.IsOnlineMarketPlace
				,ppp.NumberOfSubsidiaries
				,ppp.OnlineMarketPlaceSubsidiaries as NumberOfSubsidiariesBeingOnlineMarketPlace
				,csm.submissionperiod
				,@SubmissionPeriod AS WantedPeriod
            FROM
                dbo.v_ComplianceSchemeMembers csm
                INNER JOIN dbo.v_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
				  			AND ppp.FileName = csm.FileName
            WHERE @IsComplianceScheme = 1
                AND csm.CSOReference = @CSOReferenceNumber
                AND csm.SubmissionPeriod = @SubmissionPeriod
				AND csm.ComplianceSchemeId = @ComplianceSchemeId
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
        ) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS nvarchar(16)) + '", ' + '"IsLateFeeApplicable": ' + CASE
            WHEN IsLateFeeApplicable = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"SubmissionPeriodDescription": "' + submissionperiod + '"}' AS OrganisationDetailsJsonString
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
        ,r.IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
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
        INNER JOIN [rpd].[Organisations] o
			LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber 
			ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
END;
GO
