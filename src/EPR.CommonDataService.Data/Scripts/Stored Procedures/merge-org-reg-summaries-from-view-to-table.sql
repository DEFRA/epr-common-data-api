IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_AggregateAndMergeOrgRegSummaries]'))
DROP PROCEDURE [apps].[sp_AggregateAndMergeOrgRegSummaries];
GO

CREATE PROCEDURE [apps].[sp_AggregateAndMergeOrgRegSummaries]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempDB..#TempOrgRegTable', 'U') IS NOT NULL
    DROP TABLE #TempOrgRegTable

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

        CompanyFileId   NVARCHAR(50) NULL,
        CompanyUploadFileName NVARCHAR(255) NULL,
		CompanyBlobName NVARCHAR(50) NULL,
		BrandFileId NVARCHAR(50) NULL,
		BrandUploadFileName NVARCHAR(255) NULL,
		BrandBlobName NVARCHAR(50) NULL,
		PartnerUploadFileName NVARCHAR(255) NULL,
		PartnerFileId NVARCHAR(59) NULL,
		PartnerBlobName NVARCHAR(50) NULL,

		IsOnlineMarketPlace BIT NULL,
		NumberOfSubsidiaries INT NULL,
		NumberOfSubsidiariesBeingOnlineMarketPlace INT NULL
    );

    INSERT INTO #TempOrgRegTable 
    SELECT *
    FROM [apps].[v_OrganisationRegistrationSummaries];

    DECLARE @loadTime DATETIME2(7) = SYSDATETIME();

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
                Target.FirstSubmissionDate = Source.FirstSubmissionDate,
                Target.RegistrationDate = Source.RegistrationDate,
                Target.IsResubmission = Source.IsResubmission,
                Target.ResubmissionDate = Source.ResubmissionDate,
                Target.RelevantYear = Source.RelevantYear,
                Target.SubmissionPeriod = Source.SubmissionPeriod,
                Target.IsLateSubmission = Source.IsLateSubmission,
                Target.SubmissionStatus = Source.SubmissionStatus,
                Target.ResubmissionStatus = Source.ResubmissionStatus,
                Target.ResubmissionDecisionDate = Source.ResubmissionDecisionDate,
                Target.RegulatorDecisionDate = Source.RegulatorDecisionDate,
                Target.StatusPendingDate = Source.StatusPendingDate,
                Target.NationId = Source.NationId,
                Target.NationCode = Source.NationCode,
                Target.ComplianceSchemeId = Source.ComplianceSchemeId,
                Target.ProducerComment = Source.ProducerComment,
                Target.RegulatorComment = Source.RegulatorComment,
                Target.FileId = Source.FileId,
                Target.ResubmissionComment = Source.ResubmissionComment,
                Target.ResubmittedUserId = Source.ResubmittedUserId,
		        Target.ProducerUserId =  Source.ProducerUserId,
		        Target.RegulatorUserId = Source.RegulatorUserId,

                Target.CompanyFileId = Source.CompanyFileId,         
                Target.CompanyUploadFileName = Source.CompanyUploadFileName, 
                Target.CompanyBlobName = Source.CompanyBlobName,
                Target.BrandFileId = Source.BrandFileId,
                Target.BrandUploadFileName  = Source.BrandUploadFileName,
                Target.BrandBlobName = Source.BrandBlobName,
                Target.PartnerUploadFileName = Source.PartnerUploadFileName,
                Target.PartnerFileId = Source.PartnerFileId,
                Target.PartnerBlobName = Source.PartnerBlobName,

                Target.IsOnlineMarketPlace = Source.IsOnlineMarketPlace,
                Target.NumberOfSubsidiaries = Source.NumberOfSubsidiaries,
                Target.NumberOfSubsidiariesBeingOnlineMarketPlace = Source.NumberOfSubsidiariesBeingOnlineMarketPlace,

                Target.load_ts = @loadTime
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
                FirstSubmissionDate,
                RegistrationDate,
                IsResubmission,
                ResubmissionDate,
                RelevantYear,
                SubmissionPeriod,
                IsLateSubmission,
                SubmissionStatus,
                ResubmissionStatus,
                ResubmissionDecisionDate,
                RegulatorDecisionDate,
                StatusPendingDate,
                NationId,
                NationCode,
                ComplianceSchemeId,
                ProducerComment,
                RegulatorComment,
                FileId,
                ResubmissionComment,
                ResubmittedUserId,
                ProducerUserId,
                RegulatorUserId,
                
                CompanyFileId,         
                CompanyUploadFileName, 
                CompanyBlobName,
                BrandFileId,
                BrandUploadFileName,
                BrandBlobName,
                PartnerUploadFileName,
                PartnerFileId,
                PartnerBlobName,

                IsOnlineMarketPlace,
                NumberOfSubsidiaries,
                NumberOfSubsidiariesBeingOnlineMarketPlace,
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
                Source.FirstSubmissionDate,
                Source.RegistrationDate,
                Source.IsResubmission,
                Source.ResubmissionDate,
                Source.RelevantYear,
                Source.SubmissionPeriod,
                Source.IsLateSubmission,
                Source.SubmissionStatus,
                Source.ResubmissionStatus,
                Source.ResubmissionDecisionDate,
                Source.RegulatorDecisionDate,
                Source.StatusPendingDate,
                Source.NationId,
                Source.NationCode,
                Source.ComplianceSchemeId,
                Source.ProducerComment,
                Source.RegulatorComment,
                Source.FileId,
                Source.ResubmissionComment,
                Source.ResubmittedUserId,
                Source.ProducerUserId,
                Source.RegulatorUserId,

                Source.CompanyFileId,         
                Source.CompanyUploadFileName, 
                Source.CompanyBlobName,
                Source.BrandFileId,
                Source.BrandUploadFileName,
                Source.BrandBlobName,
                Source.PartnerUploadFileName,
                Source.PartnerFileId,
                Source.PartnerBlobName,

                Source.IsOnlineMarketPlace,
                Source.NumberOfSubsidiaries,
                Source.NumberOfSubsidiariesBeingOnlineMarketPlace,

                @loadTime
            )
        WHEN NOT MATCHED BY SOURCE THEN
            DELETE;

    IF OBJECT_ID('tempDB..#TempOrgRegTable', 'U') IS NOT NULL
    DROP TABLE #TempOrgRegTable;
END

GO

exec apps.sp_AggregateAndMergeOrgRegSummaries;
GO
select * from apps.OrgRegistrationsSummaries
order by SubmissionId ASC;
