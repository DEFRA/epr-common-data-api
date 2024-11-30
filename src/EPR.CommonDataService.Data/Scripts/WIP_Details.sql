IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_fetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [rpd].[sp_fetchOrganisationRegistrationSubmissionDetails];
GO

create proc [rpd].[sp_fetchOrganisationRegistrationSubmissionDetails]
    @SubmissionId UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod nvarchar(4000);
	DECLARE @CSOReferenceNumber nvarchar(4000);
	DECLARE @IsComplianceScheme bit;

	SELECT  @OrganisationIDForSubmission = O.Id,
			@OrganisationUUIDForSubmission = O.ExternalId,
			@CSOReferenceNumber = O.ReferenceNumber,
			@IsComplianceScheme = O.IsComplianceScheme,
			@SubmissionPeriod = S.SubmissionId
	FROM [rpd].[Submissions] as S
		inner join [rpd].[Organisations] O on S.OrganisationId = O.ExternalId
	WHERE S.SubmissionId = @SubmissionId;



    WITH
		-- basic OrganisationInformation
		SubmissionSummary as (
			SELECT 
				submission.SubmissionId,
				submission.OrganisationId,
				submission.OrganisationName,
				submission.OrganisationReferenceNumber,
				submission.IsComplianceScheme,
				submission.ProducerSize,
				CASE 
					WHEN submission.IsComplianceScheme = 1 THEN 'compliance'
					ELSE submission.ProducerSize
				END AS OrganisationType,
				submission.RelevantYear,
				submission.IsLateSubmission,
				submission.SubmittedDateTime,
				submission.SubmissionStatus,
				submission.SubmissionPeriod,
				submission.StatusPendingDate,
				submission.ApplicationReferenceNumber,
				RegistrationReferenceNumber,
				submission.NationId,
				submission.NationCode,
				submission.RegulatorUserId,
				submission.SubmittedUserId,
				submission.RegulatorDecisionDate,
				submission.ProducerCommentDate
				from [dbo].[v_OrganisationRegistrationSummaries] as submission where submission.SubmissionId = @SubmissionId
		)
		,ProducerPaycalParametersCTE AS (
			SELECT ExternalId
				   , ProducerSize 
				   , IsOnlineMarketplace
				   , NumberOfSubsidiaries
				   , NumberOfSubsidiariesBeingOnlineMarketPlace
			FROM [dbo].[v_ProducerPaycalParameters] as ppp
			WHERE ppp.ExternalId = @OrganisationUUIDForSubmission
		)
		,SubmissionOrganisationDetails as (
			SELECT DISTINCT
				submission.SubmissionId,
				submission.OrganisationId,
				submission.OrganisationName,
				submission.OrganisationReferenceNumber,
				submission.IsComplianceScheme,
				submission.ProducerSize,
				CASE 
					WHEN submission.IsComplianceScheme = 1 THEN 'compliance'
					ELSE submission.ProducerSize
				END AS OrganisationType,
				submission.RelevantYear,
				submission.SubmittedDateTime,
				submission.IsLateSubmission,
				submission.SubmissionPeriod,
				submission.SubmissionStatus,
				submission.StatusPendingDate,
				submission.ApplicationReferenceNumber,
				RegistrationReferenceNumber,
				submission.NationId,
				submission.NationCode,
				submission.RegulatorUserId,
				submission.SubmittedUserId,
				submission.RegulatorDecisionDate,
				submission.ProducerCommentDate,
				ISNULL(ppp.IsOnlineMarketplace, 0) as IsOnlineMarketplace,
				ISNULL(ppp.NumberOfSubsidiaries, 0) as NumberOfSubsidiaries,
				ISNULL(ppp.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) as NumberOfSubsidiariesBeingOnlineMarketPlace
				from SubmissionSummary as submission
					left join ProducerPaycalParametersCTE ppp on ppp.ExternalId = submission.OrganisationId
		)
		 -- producer comments
		,AllRelatedProducerCommentEventsCTE as (
			SELECT decision.SubmissionId,
				   decision.Comments,
				   decision.Created,
				   ROW_NUMBER() OVER (
						PARTITION BY decision.SubmissionId
						ORDER BY decision.Created DESC -- mark latest submissionEvent synced from cosmos
					) as RowNum
			from [rpd].[SubmissionEvents] as decision
			inner join SubmissionOrganisationDetails submittedregistrations on 
				decision.SubmissionId = submittedregistrations.SubmissionId 
			WHERE decision.Type = 'RegistrationApplicationSubmitted'
		)
		,LatestProducerCommentEventsCTE AS (
			SELECT SubmissionId,
				   Comments as ProducerComment,
				   Created as ProducerCommentDate
			from AllRelatedProducerCommentEventsCTE
			where RowNum = 1
		)
		-- regulator decisions
		,AllRelatedRegulatorDecisionEventsCTE as (
			SELECT decision.SubmissionId,
				   decision.Comments as RegulatorComment,
				   decision.Decision as SubmissionStatus,
				   decision.RegistrationReferenceNumber as RegistrationReferenceNumber,
				   decision.DecisionDate as StatusPendingDate,
				   decision.UserId as RegulatorUserId,
				   decision.Created,
				   (SELECT o.NationId from 
					rpd.Users u
						INNER JOIN rpd.Persons p ON p.UserId = u.Id
						INNER JOIN rpd.PersonOrganisationConnections poc ON poc.PersonId = p.Id
						INNER JOIN rpd.Organisations o ON o.Id = poc.OrganisationId
						INNER JOIN rpd.Enrolments e ON e.ConnectionId = poc.Id
						INNER JOIN rpd.ServiceRoles sr ON sr.Id = e.ServiceRoleId
					where sr.ServiceId = 2
					and U.UserId = decision.UserId
				   ) as RegulatorNationId,
				   ROW_NUMBER() OVER (
						PARTITION BY decision.SubmissionId
						ORDER BY load_ts DESC -- mark latest submissionEvent synced from cosmos
				   ) as RowNum
			from [rpd].[SubmissionEvents] as decision
			inner join SubmissionOrganisationDetails submittedregistration on 
				decision.SubmissionId = submittedregistration.SubmissionId
			WHERE decision.Type = 'RegulatorRegistrationDecision'
			and submittedregistration.SubmissionId = @SubmissionId
		)
		-- Granted decision and registration number
		,LatestGrantedRegistrationEventCTE AS (
			select  top(1) SubmissionId,
					RegistrationReferenceNumber
			from AllRelatedRegulatorDecisionEventsCTE
			where SubmissionStatus in ('Accepted','Granted')
		)
		,LatestRegulatorDecisionEventsCTE AS (
			SELECT decisions.SubmissionId,
				   decisions.RegulatorComment,
				   decisions.SubmissionStatus,
				   granted.RegistrationReferenceNumber,
				   decisions.StatusPendingDate,
				   decisions.RegulatorUserId,
				   decisions.RegulatorNationId,
				   decisions.Created as DecisionDate
			from AllRelatedRegulatorDecisionEventsCTE decisions
				left outer join LatestGrantedRegistrationEventCTE granted on granted.SubmissionId = decisions.SubmissionId
			where RowNum = 1 
		)
		-- Submission Details with Producer and Regulator Comments
		,SubmissionOrganisationCommentsDetailsCTE as (
			SELECT 
				submission.SubmissionId,
				submission.OrganisationId,
				submission.OrganisationName,
				submission.OrganisationReferenceNumber,
				submission.IsComplianceScheme,
				submission.ProducerSize,
				CASE 
					WHEN submission.IsComplianceScheme = 1 THEN 'compliance'
					ELSE submission.ProducerSize
				END AS OrganisationType,
				submission.RelevantYear,
				submission.SubmittedDateTime,
				submission.IsLateSubmission,
				submission.SubmissionPeriod,
				submission.SubmissionStatus,
				submission.StatusPendingDate,
				submission.ApplicationReferenceNumber,
				submission.RegistrationReferenceNumber,
				submission.NationId,
				submission.NationCode,
				submission.RegulatorUserId,
				submission.SubmittedUserId,
				submission.RegulatorDecisionDate,
				decision.RegulatorComment,
				producer.ProducerComment,
				submission.ProducerCommentDate,
				submission.IsOnlineMarketplace,
				submission.NumberOfSubsidiaries,
				submission.NumberOfSubsidiariesBeingOnlineMarketPlace
			from SubmissionOrganisationDetails submission
				left join LatestRegulatorDecisionEventsCTE decision on decision.SubmissionId = submission.SubmissionId
				left join LatestProducerCommentEventsCTE producer on producer.SubmissionId = submission.SubmissionId
		)
		, AllOrganisationFiles AS (
			SELECT
				FileId,
				BlobName,
				FileType,
				OriginalFileName as FileName,
				TargetDirectoryName,
				RegistrationSetId,
				OrganisationId,
				SubmissionType,
				load_ts,
				ROW_NUMBER() OVER (
					PARTITION BY submissionId 
					ORDER BY load_ts DESC
				) AS row_num
			FROM
				[rpd].[cosmos_file_metadata]
				where FileType in ('Partnerships', 'Brands', 'CompanyDetails')
				and IsSubmitted = 1
				and SubmissionType = 'Registration'
				and OrganisationId = @OrganisationUUIDForSubmission
		),
		AllBrandFiles as (
			select FileId as BrandFileId, 
					BlobName as BrandBlobName, 
					FileType as BrandFileType, 
					FileName as BrandFileName,
					OrganisationId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY OrganisationId 
						ORDER BY load_ts DESC
					) AS row_num
			from AllOrganisationFiles aof
			where aof.FileType = 'Brands'
		),
		AllPartnershipFiles as (
			select FileId as PartnerFileId, 
					BlobName as PartnerBlobName, 
					FileType as PartnerFileType, 
					FileName as PartnerFileName,
					OrganisationId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY OrganisationId
						ORDER BY load_ts DESC
					) AS row_num
			from AllOrganisationFiles aof
			where aof.FileType = 'Partnerships'
		),
		AllCompanyFiles as (
			select FileId as CompanyFileId, 
					BlobName as CompanyBlobName, 
					FileType as CompanyFileType, 
					FileName as CompanyFileName,
					OrganisationId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY OrganisationId
						ORDER BY load_ts DESC
					) AS row_num
			from AllOrganisationFiles aof
			where aof.FileType = 'CompanyDetails'
		),
		LatestBrandsFile as (
			select BrandFileId, BrandBlobName, BrandFileType, BrandFileName, OrganisationId
			from AllBrandFiles abf
			where abf.row_num = 1
		),
		LatestPartnerFile as (
			select PartnerFileId, PartnerBlobName, PartnerFileType, PartnerFileName, OrganisationId
			from AllPartnershipFiles apf
			where apf.row_num = 1			   
		),
		LatestCompanyFiles as (
			select CompanyFileId, CompanyBlobName, CompanyFileType, CompanyFileName, OrganisationId
			from AllCompanyFiles acf
			where acf.row_num = 1			   
		)
		,AllCombinedOrgFiles as (
			SELECT
				lcf.OrganisationId, CompanyFileId, CompanyFileName, CompanyBlobName, BrandFileId, BrandFileName, BrandBlobName, PartnerFileId, PartnerFileName, PartnerBlobName
			FROM
				LatestCompanyFiles lcf
					left outer join LatestBrandsFile lbf
						left outer join LatestPartnerFile lpf
						on lpf.OrganisationId = lbf.OrganisationId
					on lcf.OrganisationId = lbf.OrganisationId
		)
		,JoinDataWithPartnershipAndBrandsCTE AS (
			SELECT
				joinedSubmissions.*,
				CompanyFileId as CompanyDetailsFileId,
				CompanyFileName as CompanyDetailsFileName,
				CompanyBlobName as CompanyDetailsBlobName,
				BrandFileId as BrandsFileId,
				BrandFileName as BrandsFileName,
				BrandBlobName BrandsBlobName,
				PartnerFileName as PartnershipFileName,
				PartnerFileId as PartnershipFileId,
				PartnerBlobName as PartnershipBlobName
			FROM SubmissionOrganisationCommentsDetailsCTE AS joinedSubmissions
			left join AllCombinedOrgFiles acof on acof.OrganisationId = joinedSubmissions.OrganisationId
		)
		,CompliancePaycalCTE as (
			select 	CSOReference
					,csm.ReferenceNumber
					,csm.RelevantYear
					,ppp.ProducerSize
					,csm.SubmittedDate
					,csm.IsLateFeeApplicable
					,ppp.IsOnlineMarketPlace
					,ppp.NumberOfSubsidiaries
					,ppp.NumberOfSubsidiariesBeingOnlineMarketPlace
					,csm.submissionperiod
			from dbo.v_ComplianceSchemeMembers csm
				inner join dbo.v_ProducerPayCalParameters ppp
					on ppp.OrganisationReference = csm.ReferenceNumber
			where csm.CSOReference	= @CSOReferenceNumber
		)
		,JsonifiedCompliancePaycalCTE as (
			SELECT
				CSOReference
				,ReferenceNumber,
				'{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' +
				'"MemberType": "' + ProducerSize + '", ' +
				'"IsOnlineMarketPlace": ' + 
				CASE 
					WHEN IsOnlineMarketPlace = 1 THEN 'true' 
					ELSE 'false' 
				END + ', ' +
				'"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(MAX)) + ', ' +
				'"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(MAX)) + ', ' +
				'"RelevantYear":' + CAST(RelevantYear as NVARCHAR(4)) + ', ' +
				'"SubmittedDate": "' + CAST(SubmittedDate as nvarchar(16)) + '", ' +
				'"IsLateFeeApplicable": ' +
				CASE 
					WHEN IsLateFeeApplicable = 1 THEN 'true' 
					ELSE 'false' 
				END + ', ' +
				'"SubmissionPeriodDescription": "' + submissionperiod + '"}' AS OrganisationDetailsJsonString
			   FROM 
				CompliancePaycalCTE
		)
		,AllCompliancePaycalParametersAsJSONCTE as (
	
			SELECT CSOReference
				   ,'[' + STRING_AGG(OrganisationDetailsJsonString, ', ') + ']' as FinalJson
			FROM JsonifiedCompliancePaycalCTE
			WHERE CSOReference = @CSOReferenceNumber
			GROUP BY CSOReference
		)

	SELECT
		r.SubmissionId,
		r.OrganisationId,
		r.OrganisationName As OrganisationName,
		r.OrganisationReferenceNumber as OrganisationReference,
		r.ApplicationReferenceNumber,
		r.RegistrationReferenceNumber,
		r.SubmissionStatus,
		r.StatusPendingDate,
		r.SubmittedDateTime,
		r.IsLateSubmission,
		r.SubmissionPeriod,
		r.RelevantYear,
		r.IsComplianceScheme,
		r.ProducerSize as OrganisationSize,
		r.OrganisationType,
		r.NationId,
		r.NationCode,
		r.RegulatorComment,
		r.ProducerComment,
		r.RegulatorDecisionDate,
		r.ProducerCommentDate,
		r.RegulatorUserId,
    
		o.CompaniesHouseNumber,
		o.BuildingName,
		o.SubBuildingName,
		o.BuildingNumber,
		o.Street,
		o.Locality,
		o.DependentLocality,
		o.Town,
		o.County,
		o.Country,
		o.Postcode,

		r.SubmittedUserId,
		p.FirstName,
		p.LastName,
		p.Email,
		p.Telephone,
		sr.Name as ServiceRole,
		sr.Id as ServiceRoleId,

		r.IsOnlineMarketplace,
		r.NumberOfSubsidiaries,
		r.NumberOfSubsidiariesBeingOnlineMarketPlace as NumberOfOnlineSubsidiaries,

		r.CompanyDetailsFileId,
		r.CompanyDetailsFileName,
		r.CompanyDetailsBlobName,
		r.PartnershipFileId,
		r.PartnershipFileName,
		r.PartnershipBlobName,
		r.BrandsFileId,
		r.BrandsFileName,
		r.BrandsBlobName,
		acpp.FinalJson as CSOJson
	FROM JoinDataWithPartnershipAndBrandsCTE r
	INNER JOIN [rpd].[Organisations] o
		LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp on acpp.CSOReference = o.ReferenceNumber
	ON o.ExternalId = r.OrganisationId
	INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
	INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
	INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
	INNER JOIN [rpd].[ServiceRoles] sr on sr.Id = poc.PersonRoleId

END

GO
