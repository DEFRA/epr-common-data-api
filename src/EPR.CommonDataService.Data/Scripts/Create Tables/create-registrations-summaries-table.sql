﻿IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[RegistrationsSummaries]') AND type in (N'U'))
BEGIN
	DROP TABLE [apps].RegistrationsSummaries
END;


    CREATE TABLE apps.RegistrationsSummaries (
		[SubmissionId] [nvarchar](4000) NULL,
		[OrganisationId] [nvarchar](4000) NULL,
		[ComplianceSchemeId] [nvarchar](4000) NULL,
		[OrganisationName] [nvarchar](4000) NULL,
		[OrganisationReference] [nvarchar](4000) NULL,
		[CompaniesHouseNumber] [nvarchar](4000) NULL,
		[SubBuildingName] [nvarchar](4000) NULL,
		[BuildingName] [nvarchar](4000) NULL,
		[BuildingNumber] [nvarchar](4000) NULL,
		[Street] [nvarchar](4000) NULL,
		[Locality] [nvarchar](4000) NULL,
		[DependentLocality] [nvarchar](4000) NULL,
		[Town] [nvarchar](4000) NULL,
		[County] [nvarchar](4000) NULL,
		[Country] [nvarchar](4000) NULL,
		[Postcode] [nvarchar](4000) NULL,
		[OrganisationType] [nvarchar](4000) NULL,
		[ProducerType] [nvarchar](4000) NULL,
		[UserId] [nvarchar](4000) NULL,
		[FirstName] [nvarchar](4000) NULL,
		[LastName] [nvarchar](4000) NULL,
		[Email] [nvarchar](4000) NULL,
		[Telephone] [nvarchar](4000) NULL,
		[ServiceRole] [nvarchar](4000) NULL,
		[CompanyDetailsFileId] [nvarchar](4000) NULL,
		[CompanyDetailsFileName] [nvarchar](4000) NULL,
		[CompanyDetailsBlobName] [nvarchar](4000) NULL,
		[PartnershipFileId] [nvarchar](4000) NULL,
		[PartnershipFileName] [nvarchar](4000) NULL,
		[PartnershipBlobName] [nvarchar](4000) NULL,
		[BrandsFileId] [nvarchar](4000) NULL,
		[BrandsFileName] [nvarchar](4000) NULL,
		[BrandsBlobName] [nvarchar](4000) NULL,
		[SubmissionPeriod] [nvarchar](4000) NULL,
		[RegistrationDate] [nvarchar](4000) NULL,
		[Decision] [nvarchar](4000) NULL,
		[Comments] [nvarchar](4000) NULL,
		[IsResubmission] [bit] NULL,
		[PreviousRejectionComments] [nvarchar](4000) NULL,
		[NationId] [int] NULL
    )
    WITH
    (
        DISTRIBUTION = HASH([SubmissionId])
    );

END;