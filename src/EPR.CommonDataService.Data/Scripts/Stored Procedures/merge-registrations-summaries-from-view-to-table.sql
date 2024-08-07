﻿-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_AggregateAndMergeRegistrationData]'))
DROP PROCEDURE [apps].[sp_AggregateAndMergeRegistrationData];
GO

CREATE PROC [apps].[sp_AggregateAndMergeRegistrationData] AS
BEGIN
	IF OBJECT_ID('tempdb..#RegistrationsSummariesTemp') IS NOT NULL
DROP TABLE #RegistrationsSummariesTemp;

-- Create temp table
CREATE TABLE #RegistrationsSummariesTemp
(
    [SubmissionId] NVARCHAR(4000),
    [OrganisationId] NVARCHAR(4000),
    [ComplianceSchemeId] NVARCHAR(4000),
    [OrganisationName] NVARCHAR(4000),
    [OrganisationReference] NVARCHAR(4000),
    [CompaniesHouseNumber] NVARCHAR(4000),
    [SubBuildingName] NVARCHAR(4000),
    [BuildingName] NVARCHAR(4000),
    [BuildingNumber] NVARCHAR(4000),
    [Street] NVARCHAR(4000),
    [Locality] NVARCHAR(4000),
    [DependentLocality] NVARCHAR(4000),
    [Town] NVARCHAR(4000),
    [County] NVARCHAR(4000),
    [Country] NVARCHAR(4000),
    [Postcode] NVARCHAR(4000),
    [OrganisationType] NVARCHAR(4000),
    [ProducerType] NVARCHAR(4000),
    [UserId] NVARCHAR(4000),
    [FirstName] NVARCHAR(4000),
    [LastName] NVARCHAR(4000),
    [Email] NVARCHAR(4000),
    [Telephone] NVARCHAR(4000),
    [ServiceRole] NVARCHAR(4000),
    [CompanyDetailsFileId] NVARCHAR(4000),
    [CompanyDetailsFileName] NVARCHAR(4000),
    [CompanyDetailsBlobName] NVARCHAR(4000),
    [PartnershipFileId] NVARCHAR(4000),
    [PartnershipFileName] NVARCHAR(4000),
    [PartnershipBlobName] NVARCHAR(4000),
    [BrandsFileId] NVARCHAR(4000),
    [BrandsFileName] NVARCHAR(4000),
    [BrandsBlobName] NVARCHAR(4000),
    [SubmissionPeriod] NVARCHAR(4000),
    [RegistrationDate] NVARCHAR(4000),
    [Decision] NVARCHAR(4000),
    [Comments] NVARCHAR(4000),
    [IsResubmission] BIT,
    [PreviousRejectionComments] NVARCHAR(4000),
    [NationId] INT
	);

INSERT INTO #RegistrationsSummariesTemp
SELECT
    [SubmissionId],
    [OrganisationId],
    [ComplianceSchemeId],
    [OrganisationName],
    [OrganisationReference],
    [CompaniesHouseNumber],
    [SubBuildingName],
    [BuildingName],
    [BuildingNumber],
    [Street],
    [Locality],
    [DependentLocality],
    [Town],
    [County],
    [Country],
    [Postcode],
    [OrganisationType],
    [ProducerType],
    [UserId],
    [FirstName],
    [LastName],
    [Email],
    [Telephone],
    [ServiceRole],
    [CompanyDetailsFileId],
    [CompanyDetailsFileName],
    [CompanyDetailsBlobName],
    [PartnershipFileId],
    [PartnershipFileName],
    [PartnershipBlobName],
    [BrandsFileId],
    [BrandsFileName],
    [BrandsBlobName],
    [SubmissionPeriod],
    [RegistrationDate],
    [Decision],
    [Comments],
    [IsResubmission],
    [PreviousRejectionComments],
    [NationId]
FROM apps.v_RegistrationsSummaries;

MERGE INTO apps.RegistrationsSummaries AS Target
    USING #RegistrationsSummariesTemp AS Source
    ON Target.CompanyDetailsFileId = Source.CompanyDetailsFileId
    WHEN MATCHED THEN
        UPDATE SET
            Target.SubmissionId = Source.SubmissionId,
            Target.OrganisationId = Source.OrganisationId,
            Target.ComplianceSchemeId = Source.ComplianceSchemeId,
            Target.OrganisationName = Source.OrganisationName,
            Target.OrganisationReference = Source.OrganisationReference,
            Target.CompaniesHouseNumber = Source.CompaniesHouseNumber,
            Target.SubBuildingName = Source.SubBuildingName,
            Target.BuildingName = Source.BuildingName,
            Target.BuildingNumber = Source.BuildingNumber,
            Target.Street = Source.Street,
            Target.Locality = Source.Locality,
            Target.DependentLocality = Source.DependentLocality,
            Target.Town = Source.Town,
            Target.County = Source.County,
            Target.Country = Source.Country,
            Target.Postcode = Source.Postcode,
            Target.OrganisationType = Source.OrganisationType,
            Target.ProducerType = Source.ProducerType,
            Target.UserId = Source.UserId,
            Target.FirstName = Source.FirstName,
            Target.LastName = Source.LastName,
            Target.Email = Source.Email,
            Target.Telephone = Source.Telephone,
            Target.ServiceRole = Source.ServiceRole,
            Target.CompanyDetailsFileId = Source.CompanyDetailsFileId,
            Target.CompanyDetailsFileName = Source.CompanyDetailsFileName,
            Target.CompanyDetailsBlobName = Source.CompanyDetailsBlobName,
            Target.PartnershipFileId = Source.PartnershipFileId,
            Target.PartnershipFileName = Source.PartnershipFileName,
            Target.PartnershipBlobName = Source.PartnershipBlobName,
            Target.BrandsFileId = Source.BrandsFileId,
            Target.BrandsFileName = Source.BrandsFileName,
            Target.BrandsBlobName = Source.BrandsBlobName,
            Target.SubmissionPeriod = Source.SubmissionPeriod,
            Target.RegistrationDate = Source.RegistrationDate,
            Target.Decision = Source.Decision,
            Target.Comments = Source.Comments,
            Target.IsResubmission = Source.IsResubmission,
            Target.PreviousRejectionComments = Source.PreviousRejectionComments,
            Target.NationId = Source.NationId
    WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        [SubmissionId],
        [OrganisationId],
        [ComplianceSchemeId],
        [OrganisationName],
        [OrganisationReference],
        [CompaniesHouseNumber],
        [SubBuildingName],
        [BuildingName],
        [BuildingNumber],
        [Street],
        [Locality],
        [DependentLocality],
        [Town],
        [County],
        [Country],
        [Postcode],
        [OrganisationType],
        [ProducerType],
        [UserId],
        [FirstName],
        [LastName],
        [Email],
        [Telephone],
        [ServiceRole],
        [CompanyDetailsFileId],
        [CompanyDetailsFileName],
        [CompanyDetailsBlobName],
        [PartnershipFileId],
        [PartnershipFileName],
        [PartnershipBlobName],
        [BrandsFileId],
        [BrandsFileName],
        [BrandsBlobName],
        [SubmissionPeriod],
        [RegistrationDate],
        [Decision],
        [Comments],
        [IsResubmission],
        [PreviousRejectionComments],
        [NationId]
    )
    VALUES (
        Source.Submissionid,
        Source.OrganisationId,
        Source.ComplianceSchemeId,
        Source.OrganisationName,
        Source.OrganisationReference,
        Source.CompaniesHouseNumber,
        Source.SubBuildingName,
        Source.BuildingName,
        Source.BuildingNumber,
        Source.Street,
        Source.Locality,
        Source.DependentLocality,
        Source.Town,
        Source.County,
        Source.Country,
        Source.Postcode,
        Source.OrganisationType,
        Source.ProducerType,
        Source.UserId,
        Source.FirstName,
        Source.LastName,
        Source.Email,
        Source.Telephone,
        Source.ServiceRole,
        Source.CompanyDetailsFileId,
        Source.CompanyDetailsFileName,
        Source.CompanyDetailsBlobName,
        Source.PartnershipFileId,
        Source.PartnershipFileName,
        Source.PartnershipBlobName,
        Source.BrandsFileId,
        Source.BrandsFileName,
        Source.BrandsBlobName,
        Source.SubmissionPeriod,
        Source.RegistrationDate,
        Source.Decision,
        Source.Comments,
        Source.IsResubmission,
        Source.PreviousRejectionComments,
        Source.NationId
    )
    WHEN NOT MATCHED BY SOURCE THEN
        DELETE; -- delete from table when no longer in source

DROP TABLE #RegistrationsSummariesTemp;

END;