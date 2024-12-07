IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_FetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [rpd].[sp_FetchOrganisationRegistrationSubmissionDetails];
GO
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails];
GO

create proc [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails]
    @SubmissionId UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod nvarchar(4000);
	DECLARE @CSOReferenceNumber nvarchar(4000);
	DECLARE @ApplicationReferenceNumber nvarchar(4000);
	DECLARE @IsComplianceScheme bit;

	-- Fetch global IDs for the submission
	SELECT  @OrganisationIDForSubmission = O.Id,	-- the int id of the organisation
			@OrganisationUUIDForSubmission = O.ExternalId,	-- the uuid of the organisation
			@CSOReferenceNumber = O.ReferenceNumber,	-- the reference number of the organisation
			@IsComplianceScheme = O.IsComplianceScheme,	-- whether the org is a compliance scheme
			@SubmissionPeriod = S.SubmissionPeriod,	-- the submission period of the submissions
			@ApplicationReferenceNumber = S.AppReferenceNumber -- the AppRef number of the submission
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
				submission.ProducerCommentDate,
				submission.ProducerSubmissionEventId,
				submission.RegulatorSubmissionEventId
				from [dbo].[v_OrganisationRegistrationSummaries] as submission where submission.SubmissionId = @SubmissionId
		)
		-- the paycal parameterisation for the organisation itself
		,ProducerPaycalParametersCTE AS (
			SELECT ExternalId
				   , ProducerSize 
				   , IsOnlineMarketplace
				   , NumberOfSubsidiaries
				   , NumberOfSubsidiariesBeingOnlineMarketPlace
			FROM [dbo].[v_ProducerPaycalParameters] as ppp
			WHERE ppp.ExternalId = @OrganisationUUIDForSubmission
		)
		-- the submission details with Paycal parameter info
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
				submission.ProducerSubmissionEventId,
				submission.RegulatorSubmissionEventId,
				ISNULL(ppp.IsOnlineMarketplace, 0) as IsOnlineMarketplace,
				ISNULL(ppp.NumberOfSubsidiaries, 0) as NumberOfSubsidiaries,
				ISNULL(ppp.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) as NumberOfSubsidiariesBeingOnlineMarketPlace
				from SubmissionSummary as submission
					left join ProducerPaycalParametersCTE ppp on ppp.ExternalId = submission.OrganisationId
		)
		-- the latest Producer Comments for this Submission and Application Reference Number
		,LatestProducerCommentEventsCTE AS (
			SELECT distinct decision.SubmissionId,
				   Comments as ProducerComment,
				   Created as ProducerCommentDate
			from [rpd].[SubmissionEvents] as decision
			inner join SubmissionOrganisationDetails submittedregistrations on 
				decision.SubmissionEventId = submittedregistrations.ProducerSubmissionEventId
		)
		,LatestRegulatorCommentCTE as (
			SELECT distinct decision.SubmissionId,
				   Comments as RegulatorComment,
				   Created as RegulatorCommentDate
			from [rpd].[SubmissionEvents] as decision
			inner join SubmissionOrganisationDetails submittedregistrations on 
				decision.SubmissionEventId = submittedregistrations.RegulatorSubmissionEventId
		)
		-- Submission Details with Producer and Regulator Comments
		-- the RegistrationReferenceNumber is included
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
				decision.RegulatorCommentDate as RegulatorDecisionDate,
				decision.RegulatorComment,
				producer.ProducerComment,
				submission.ProducerCommentDate,
				submission.IsOnlineMarketplace,
				submission.NumberOfSubsidiaries,
				submission.NumberOfSubsidiariesBeingOnlineMarketPlace,
				submission.ProducerSubmissionEventId,
				submission.RegulatorSubmissionEventId
			from SubmissionOrganisationDetails submission
				left join LatestRegulatorCommentCTE decision on decision.SubmissionId = submission.SubmissionId
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
				OrganisationId as ExternalId,
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
			select FileId as BrandFileId, BlobName as BrandBlobName, FileType as BrandFileType, FileName as BrandFileName,
					ExternalId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY ExternalId 
						ORDER BY load_ts DESC
					) AS row_num
			from AllOrganisationFiles aof
			where aof.FileType = 'Brands'
		),
		AllPartnershipFiles as (
			select FileId as PartnerFileId, BlobName as PartnerBlobName, FileType as PartnerFileType, FileName as PartnerFileName,
					ExternalId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY ExternalId
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
					ExternalId,
					load_ts,
					ROW_NUMBER() OVER (
						PARTITION BY ExternalId
						ORDER BY load_ts DESC
					) AS row_num
			from AllOrganisationFiles aof
			where aof.FileType = 'CompanyDetails'
		),
		LatestBrandsFile as (
			select BrandFileId, BrandBlobName, BrandFileType, BrandFileName, ExternalId
			from AllBrandFiles abf
			where abf.row_num = 1
		),
		LatestPartnerFile as (
			select PartnerFileId, PartnerBlobName, PartnerFileType, PartnerFileName, ExternalId
			from AllPartnershipFiles apf
			where apf.row_num = 1			   
		),
		LatestCompanyFiles as (
			select CompanyFileId, CompanyBlobName, CompanyFileType, CompanyFileName, ExternalId
			from AllCompanyFiles acf
			where acf.row_num = 1			   
		)
		,AllCombinedOrgFiles as (
			SELECT
				lcf.ExternalId as OrganisationExternalId, 
				CompanyFileId, CompanyFileName, CompanyBlobName, 
				BrandFileId, BrandFileName, BrandBlobName, 
				PartnerFileId, PartnerFileName, PartnerBlobName
			FROM
				LatestCompanyFiles lcf
					left outer join LatestBrandsFile lbf
						left outer join LatestPartnerFile lpf
						on lpf.ExternalId = lbf.ExternalId
					on lcf.ExternalId = lbf.ExternalId
		)
		-- All submission data combined with the individual file data
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
			left join AllCombinedOrgFiles acof on acof.OrganisationExternalId = joinedSubmissions.OrganisationId
		)
		-- For the Submission Period of the Submission
		-- Use the new view to obtain information required for the Paycal API
		-- The Organisation reference number of the Submission's organisation is used
		-- It is controlled by whether the IsComplianceScheme flag is 1
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
					,@SubmissionPeriod as WantedPeriod
			from dbo.v_ComplianceSchemeMembers csm
				inner join dbo.v_ProducerPayCalParameters ppp
					on ppp.OrganisationReference = csm.ReferenceNumber
			where @IsComplianceScheme = 1 
			and csm.CSOReference	= @CSOReferenceNumber
			and csm.SubmissionPeriod = @SubmissionPeriod
		)
		-- Build a rowset of membership organisations and their producer paycal api parameter requirements
		-- the properties of the above is built into a JSON string
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
				'"RelevantYear": ' + CAST(RelevantYear as NVARCHAR(4)) + ', ' +
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
		-- the above CTE is then compressed into a single row using the STRIN_AGG function
		,AllCompliancePaycalParametersAsJSONCTE as (
	
			SELECT CSOReference
				   ,'[' + STRING_AGG(OrganisationDetailsJsonString, ', ') + ']' as FinalJson
			FROM JsonifiedCompliancePaycalCTE
			WHERE CSOReference = @CSOReferenceNumber
			GROUP BY CSOReference
		)
	-- bring all the above into one 1
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
		r.ProducerSubmissionEventId,
		r.RegulatorSubmissionEventId,
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
