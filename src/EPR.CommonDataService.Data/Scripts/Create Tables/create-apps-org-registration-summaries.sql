IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[OrgRegistrationsSummaries]') AND type in (N'U'))
BEGIN
	CREATE TABLE [apps].[OrgRegistrationsSummaries] (
		SubmissionId NVARCHAR(150) NULL,
		OrganisationId NVARCHAR(150) NULL,
		OrganisationInternalId INT NULL,
		OrganisationName NVARCHAR(500) NULL,
		UploadedOrganisationName NVARCHAR(500) NULL,
		OrganisationReference NVARCHAR(25) NULL,
		SubmittedUserId NVARCHAR(150) NULL,
		IsComplianceScheme BIT,
		OrganisationType NVARCHAR(50) NULL,
		ProducerSize NVARCHAR(50) NULL,
		ApplicationReferenceNumber NVARCHAR(50) NULL,
		RegistrationReferenceNumber NVARCHAR(50) NULL,
		SubmittedDateTime NVARCHAR(50) NULL,
		RegistrationDate NVARCHAR(50) NULL, --NEW
		IsResubmission BIT, --NEW
		ResubmissionDate NVARCHAR(50) NULL, --NEW
		RelevantYear INT NULL,
		SubmissionPeriod NVARCHAR(500) NULL,
		IsLateSubmission BIT,
		SubmissionStatus NVARCHAR(20) NULL,
		ResubmissionStatus NVARCHAR(50) NULL, --NEW
		RegulatorDecisionDate NVARCHAR(50) NULL, --NEW
		StatusPendingDate NVARCHAR(50) NULL,
		NationId INT NULL,
		NationCode NVARCHAR(10) NULL
	)
	WITH
    (
        DISTRIBUTION = HASH([SubmissionId])
    );
END;
