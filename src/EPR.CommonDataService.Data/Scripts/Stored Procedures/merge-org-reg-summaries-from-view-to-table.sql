IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_AggregateAndMergeOrgRegSummaries]'))
DROP PROCEDURE [apps].[sp_AggregateAndMergeOrgRegSummaries];
GO

CREATE PROCEDURE [apps].[sp_AggregateAndMergeOrgRegSummaries]
AS
BEGIN
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

    IF OBJECT_ID('tempDB..#TempOrgRegTable', 'U') IS NOT NULL
    DROP TABLE #TempOrgRegTable

    DECLARE @loadTime DATETIME2(7) = SYSDATETIME();

    CREATE TABLE #TempOrgRegTable (
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
        NationCode NVARCHAR(10) NULL,
        MaxLoadTime DATETIME2(7)
    );

    INSERT INTO #TempOrgRegTable 
    SELECT *
    FROM [apps].[v_OrganisationRegistrationSummaries];

    MERGE INTO [apps].[OrgRegistrationsSummaries] as Target
        USING #TempOrgRegTable as Source
        ON Target.SubmissionId = Source.SubmissionId
        WHEN MATCHED THEN
            UPDATE SET
                Target.SubmissionId = Source.SubmissionId,
                Target.OrganisationId = Source.OrganisationId,
                Target.OrganisationInternalId = Source.OrganisationInternalId,
                Target.OrganisationName = Source.OrganisationName,
                Target.UploadedOrganisationName = Source.UploadedOrganisationName,
                Target.OrganisationReference = Source.OrganisationReference,
                Target.SubmittedUserId = Source.SubmittedUserId,
                Target.IsComplianceScheme = Source.IsComplianceScheme,
                Target.OrganisationType = Source.OrganisationType,
                Target.ProducerSize = Source.ProducerSize,
                Target.ApplicationReferenceNumber = Source.ApplicationReferenceNumber,
                Target.RegistrationReferenceNumber = Source.RegistrationReferenceNumber,
                Target.SubmittedDateTime = Source.SubmittedDateTime,
                Target.RegistrationDate = Source.RegistrationDate,
                Target.IsResubmission = Source.IsResubmission,
                Target.ResubmissionDate = Source.ResubmissionDate,
                Target.RelevantYear = Source.RelevantYear,
                Target.SubmissionPeriod = Source.SubmissionPeriod,
                Target.IsLateSubmission = Source.IsLateSubmission,
                Target.SubmissionStatus = Source.SubmissionStatus,
                Target.ResubmissionStatus = Source.ResubmissionStatus,
                Target.RegulatorDecisionDate = Source.RegulatorDecisionDate,
                Target.StatusPendingDate = Source.StatusPendingDate,
                Target.NationId = Source.NationId,
                Target.NationCode = Source.NationCode
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                SubmissionId,
                OrganisationId,
                OrganisationInternalId,
                OrganisationName,
                UploadedOrganisationName,
                OrganisationReference,
                SubmittedUserId,
                IsComplianceScheme,
                OrganisationType,
                ProducerSize,
                ApplicationReferenceNumber,
                RegistrationReferenceNumber,
                SubmittedDateTime,
                RegistrationDate,
                IsResubmission,
                ResubmissionDate,
                RelevantYear,
                SubmissionPeriod,
                IsLateSubmission,
                SubmissionStatus,
                ResubmissionStatus,
                RegulatorDecisionDate,
                StatusPendingDate,
                NationId,
                NationCode,
                load_ts
            )
            VALUES (
                Source.SubmissionId,
                Source.OrganisationId,
                Source.OrganisationInternalId,
                Source.OrganisationName,
                Source.UploadedOrganisationName,
                Source.OrganisationReference,
                Source.SubmittedUserId,
                Source.IsComplianceScheme,
                Source.OrganisationType,
                Source.ProducerSize,
                Source.ApplicationReferenceNumber,
                Source.RegistrationReferenceNumber,
                Source.SubmittedDateTime,
                Source.RegistrationDate,
                Source.IsResubmission,
                Source.ResubmissionDate,
                Source.RelevantYear,
                Source.SubmissionPeriod,
                Source.IsLateSubmission,
                Source.SubmissionStatus,
                Source.ResubmissionStatus,
                Source.RegulatorDecisionDate,
                Source.StatusPendingDate,
                Source.NationId,
                Source.NationCode,
                @loadTime
            )
        WHEN NOT MATCHED BY SOURCE THEN
            DELETE;

    IF OBJECT_ID('tempDB..#TempOrgRegTable', 'U') IS NOT NULL
    DROP TABLE #TempOrgRegTable
END;
GO
