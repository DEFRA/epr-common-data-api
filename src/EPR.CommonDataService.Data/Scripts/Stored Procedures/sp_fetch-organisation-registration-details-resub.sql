IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub] @SubmissionId [nvarchar](36) AS

BEGIN
	SET NOCOUNT ON;

	select o.SubmissionId,
           o.OrganisationId,
           o.OrganisationName,
           o.OrganisationReference,
           o.ApplicationReferenceNumber,
           o.RegistrationReferenceNumber,
           o.SubmissionStatus,
           o.StatusPendingDate,
           o.SubmittedDateTime,
           o.IsLateSubmission,
           o.IsResubmission,
           o.ResubmissionStatus,
           o.RegistrationDate,
           o.ResubmissionDate,
           o.ResubmissionFileId,
           o.SubmissionPeriod,
           o.RelevantYear,
           o.IsComplianceScheme,
           o.OrganisationSize,
           o.OrganisationType,
           o.NationId,
           o.NationCode,
           o.RegulatorComment,
           o.ProducerComment,
           o.RegulatorDecisionDate,
           o.RegulatorResubmissionDecisionDate,
           o.RegulatorUserId,
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
           o.SubmittedUserId,
           o.FirstName,
           o.LastName,
           o.Email,
           o.Telephone,
           o.ServiceRole,
           o.ServiceRoleId,
           o.IsOnlineMarketplace,
           o.NumberOfSubsidiaries,
           o.NumberOfOnlineSubsidiaries,
           o.CompanyDetailsFileId,
           o.CompanyDetailsFileName,
           o.CompanyDetailsBlobName,
           o.PartnershipFileId,
           o.PartnershipFileName,
           o.PartnershipBlobName,
           o.BrandsFileId,
           o.BrandsFileName,
           o.BrandsBlobName,
           o.ComplianceSchemeId,
           o.CSId,
           o.CSOJson,
           s.RegistrationJourney
	from dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub o
    join apps.Submissions s on s.SubmissionId = o.SubmissionId
    where o.SubmissionId = @SubmissionId;
END;
go

