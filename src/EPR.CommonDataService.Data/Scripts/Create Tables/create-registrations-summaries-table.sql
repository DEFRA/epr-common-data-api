IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[RegistrationsSummaries]') AND type in (N'U'))
BEGIN

    CREATE TABLE apps.RegistrationsSummaries (
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
        [PartnershipFileId] NVARCHAR(4000),
        [PartnershipFileName] NVARCHAR(4000),
        [BrandsFileId] NVARCHAR(4000),
        [BrandsFileName] NVARCHAR(4000),
        [SubmissionPeriod] NVARCHAR(4000),
        [RegistrationDate] NVARCHAR(4000),
        [Decision] NVARCHAR(4000),
        [Comments] NVARCHAR(4000),
        [IsResubmission] BIT,
        [PreviousRejectionComments] NVARCHAR(4000),
        [NationId] INT
    )
    WITH
    (
        DISTRIBUTION = HASH([SubmissionId])
    );

END;
Go