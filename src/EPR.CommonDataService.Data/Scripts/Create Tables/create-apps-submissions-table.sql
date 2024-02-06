IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[Submissions]') AND type in (N'U'))
BEGIN

    CREATE TABLE [apps].[Submissions]
    (
        [OrganisationMembers] [int] NULL,
        [Created] [nvarchar](4000) NULL,
        [OrganisationId] [nvarchar](4000) NULL,
        [IsSubmitted] [bit] NULL,
        [DataSourceType] [nvarchar](4000) NULL,
        [SubmissionEventId] [nvarchar](4000) NULL,
        [SubmissionPeriod] [nvarchar](4000) NULL,
        [SubmissionType] [nvarchar](4000) NULL,
        [SubmissionId] [nvarchar](4000) NULL,
        [RegulatorDecision] [nvarchar](4000) NULL,
        [RejectionComments] [nvarchar](4000) NULL,
        [id] [nvarchar](4000) NULL,
        [UserId] [nvarchar](4000) NULL,
        [Type] [nvarchar](4000) NULL,
        [ComplianceSchemeId] [nvarchar](4000) NULL,
        [load_ts] [datetime2](7) NULL
        )
        WITH
            (
            DISTRIBUTION = HASH ( [SubmissionId] ),
        CLUSTERED COLUMNSTORE INDEX
        )
END;
GO
