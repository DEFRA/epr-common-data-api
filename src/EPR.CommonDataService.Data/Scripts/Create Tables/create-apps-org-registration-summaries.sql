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
		FirstSubmissionDate NVARCHAR(50) NULL,
		RegistrationDate NVARCHAR(50) NULL, --NEW
		IsResubmission BIT, --NEW
		ResubmissionDate NVARCHAR(50) NULL, --NEW
		RelevantYear INT NULL,
		SubmissionPeriod NVARCHAR(500) NULL,
		IsLateSubmission BIT,
		SubmissionStatus NVARCHAR(20) NULL,
		ResubmissionStatus NVARCHAR(50) NULL, --NEW
		ResubmissionDecisionDate NVARCHAR(50) NULL,
		RegulatorDecisionDate NVARCHAR(50) NULL, --NEW
		StatusPendingDate NVARCHAR(50) NULL,
		NationId INT NULL,
		NationCode NVARCHAR(10) NULL,
		ComplianceSchemeId NVARCHAR(50) NULL,
		ProducerComment NVARCHAR(4000) NULL,
		RegulatorComment NVARCHAR(4000) NULL,
		FileId NVARCHAR(50) NULL,
		ResubmissionComment NVARCHAR(4000) NULL,
		ResubmittedUserId NVARCHAR(50) NULL,
		ProducerUserId NVARCHAR(50) NULL,
		RegulatorUserId NVARCHAR(50) NULL,
		ResubmissionDecisionDate NVARCHAR(50) NULL,
		load_ts datetime2(7)
	)
	WITH
    (
        DISTRIBUTION = HASH([SubmissionId])
    );
END;
