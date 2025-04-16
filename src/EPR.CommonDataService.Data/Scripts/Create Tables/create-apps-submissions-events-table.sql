IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[SubmissionEvents]') AND type in (N'U'))
BEGIN

    CREATE TABLE [apps].[SubmissionEvents]
    (
        [OrganisationMembers] [int] NULL,
        [RequiresRowValidation] [bit] NULL,
        [Created] [nvarchar](4000) NULL,
        [RequiresBrandsFile] [bit] NULL,
        [Comments] [nvarchar](4000) NULL,
        [RegistrationSetId] [nvarchar](4000) NULL,
        [IsResubmissionRequired] [nvarchar](4000) NULL,
        [SubmissionEventId] [nvarchar](4000) NULL,
        [DataCount] [int] NULL,
        [RowErrorCount] [int] NULL,
        [HasMaxRowErrors] [bit] NULL,
        [RequiresValidation] [bit] NULL,
        [CompanyDetailsFileId] [nvarchar](4000) NULL,
        [SubmissionId] [nvarchar](4000) NULL,
        [Decision] [nvarchar](4000) NULL,
        [RegulatorDecision] [nvarchar](4000) NULL,
        [FileId] [nvarchar](4000) NULL,
        [RejectionComments] [nvarchar](4000) NULL,
        [IsValid] [bit] NULL,
        [BlobName] [nvarchar](4000) NULL,
        [AntivirusScanResult] [nvarchar](4000) NULL,
        [id] [nvarchar](4000) NULL,
        [RequiresPartnershipsFile] [bit] NULL,
        [Errors] [nvarchar](4000) NULL,
        [FileName] [nvarchar](4000) NULL,
        [ResubmissionRequired] [nvarchar](4000) NULL,
        [FileType] [nvarchar](4000) NULL,
        [UserId] [nvarchar](4000) NULL,
        [ProducerId] [nvarchar](4000) NULL,
        [SubmittedBy] [nvarchar](4000) NULL,
        [RegulatorUserId] [nvarchar](4000) NULL,
        [Type] [nvarchar](4000) NULL,
        [BlobContainerName] [nvarchar](4000) NULL,
        [load_ts] [datetime2](7) NULL,
        [PackagingResubmissionReferenceNumber] [nvarchar](4000) NULL
        )
        WITH
            (
            DISTRIBUTION = HASH ( [SubmissionEventId] ),
        CLUSTERED COLUMNSTORE INDEX
    )
END;

IF NOT EXISTS (SELECT 1 FROM SYS.COLUMNS WHERE [Name] = N'PackagingResubmissionReferenceNumber' AND object_id = OBJECT_ID(N'[apps].[SubmissionEvents]'))
BEGIN
    ALTER TABLE [apps].[SubmissionEvents] ADD [PackagingResubmissionReferenceNumber] NVARCHAR (4000) NULL
END;

GO