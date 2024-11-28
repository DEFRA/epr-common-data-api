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
	SET @OrganisationIDForSubmission = (SELECT O.Id from [rpd].[Submissions] as S
		inner join [rpd].[Organisations] O on S.OrganisationId = O.ExternalId
		WHERE S.SubmissionId = @SubmissionId);
	SET @OrganisationUUIDForSubmission = (SELECT S.OrganisationId from [rpd].[Submissions] as S
		WHERE S.SubmissionId = @SubmissionId);

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
		-- for paycal
		,SubsidiaryCountsCTE AS (
			SELECT 
				o.organisation_id,
				ISNULL(s.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
			FROM 
				(SELECT DISTINCT organisation_id FROM rpd.companyDetails) o
			LEFT JOIN 
				(
					SELECT 
						organisation_id,
						COUNT(*) AS NumberOfSubsidiaries
					FROM 
						rpd.companyDetails
					WHERE 
						subsidiary_id IS NOT NULL
					GROUP BY 
						organisation_id
				) s
			ON o.organisation_id = s.organisation_id
		)
		,OnlineMarketSubsidiaryCountCTE as (
			SELECT 
				o.organisation_id,
				ISNULL(s.NumberOfSubsidiariesBeingOnlineMarketPlace, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
			FROM 
				(SELECT DISTINCT organisation_id FROM rpd.companyDetails) o
			LEFT JOIN 
				(
					SELECT 
						organisation_id,
						COUNT(*) AS NumberOfSubsidiariesBeingOnlineMarketPlace
					FROM 
						rpd.companyDetails
					WHERE 
						packaging_activity_om IN ('Primary', 'Secondary')
					GROUP BY 
						organisation_id
				) s
			ON 
				o.organisation_id = s.organisation_id
		)
		,SubsidiaryCountCTE AS (
			select organisation_id,
				   NumberOfSubsidiaries
			from SubsidiaryCountsCTE where organisation_id = @OrganisationIDForSubmission
		)
		,OnlineMarketplaceCountCTE AS (
			select organisation_id, NumberOfSubsidiariesBeingOnlineMarketPlace
			from OnlineMarketSubsidiaryCountCTE
			where organisation_id = @OrganisationIDForSubmission
		),
		OrganisationMarketPlaceInformationCTE AS (
			SELECT
				@SubmissionId as SubmissionId,
				cd.organisation_id,
				cd.organisation_size AS ProducerSize,
				CASE
					WHEN EXISTS (
						SELECT 1
						FROM rpd.companyDetails
						WHERE organisation_id = @OrganisationIDForSubmission
						AND packaging_activity_om IN ('Primary', 'Secondary')
					) THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				END AS IsOnlineMarketplace,
				ISNULL(sc.NumberOfSubsidiaries,0) as NumberOfSubsidiaries,
				ISNULL(omc.NumberOfSubsidiariesBeingOnlineMarketPlace,0) as NumberOfSubsidiariesBeingOnlineMarketPlace
			FROM
				rpd.Organisations org
				LEFT JOIN rpd.companyDetails cd ON org.id = cd.organisation_id
				LEFT JOIN SubsidiaryCountCTE sc ON sc.organisation_id = cd.organisation_id
				LEFT JOIN OnlineMarketplaceCountCTE omc ON omc.organisation_id = cd.organisation_id
			WHERE cd.organisation_id = @OrganisationIDForSubmission
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
				org.IsOnlineMarketplace,
				org.NumberOfSubsidiaries,
				org.NumberOfSubsidiariesBeingOnlineMarketPlace
				from SubmissionSummary as submission
					inner join OrganisationMarketPlaceInformationCTE org on org.SubmissionId = submission.SubmissionId
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
		,SubmissionOrganisationCommentDetailsCTE as (
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
		,LatestCompanyDetailsCTE AS ( 
			select NewID() as CompanyDetailsFileId,
				   'CompanyDetailsFileName.csv' as CompanyDetailsFileName,
				   'abc' as CompanyDetailsBlobName,
					'xyz' as RegistrationSetId
		)
		,LatestBrandDetailsCTE AS(
			select NewID() as BrandsFileId,
				   'BrandsFileName.csv' as BrandsFileName,
				   'def' as BrandsBlobName,
				   'xyz' as RegistrationSetId
		)
		,LatestPartnershipDetailsCTE AS (
			select NewID() as PartnershipFileId,
				   'PartnershipFileName.csv' as PartnershipFileName,
				   'ghi' as PartnershipBlobName,
				   'xyz' as RegistrationSetId
		)
		,JoinDataWithPartnershipAndBrandsCTE AS (
			SELECT
				joinedSubmissions.*,
				companyDetails.CompanyDetailsFileId,
				companyDetails.CompanyDetailsFileName,
				companyDetails.CompanyDetailsBlobName,
				brands.BrandsFileName,
				brands.BrandsFileId,
				brands.BrandsBlobName,
				partnerships.PartnershipFileName,
				partnerships.PartnershipFileId,
				partnerships.PartnershipBlobName
			FROM SubmissionOrganisationCommentDetailsCTE AS joinedSubmissions
			left JOIN LatestCompanyDetailsCTE companyDetails ON companyDetails.RegistrationSetId = 'xyz'
			LEFT JOIN LatestBrandDetailsCTE brands ON brands.RegistrationSetId = companyDetails.RegistrationSetId
			LEFT JOIN LatestPartnershipDetailsCTE partnerships ON partnerships.RegistrationSetId = brands.RegistrationSetId
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
		r.BrandsBlobName
	FROM JoinDataWithPartnershipAndBrandsCTE r
	INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId
	INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
	INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
	INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
	INNER JOIN [rpd].[ServiceRoles] sr on sr.Id = poc.PersonRoleId

END

GO
