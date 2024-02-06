IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[SubmissionsSummaries]') AND type in (N'U'))
BEGIN

    CREATE TABLE apps.SubmissionsSummaries (
        [SubmissionId] NVARCHAR(4000),
        [OrganisationId] NVARCHAR(4000),
        [ComplianceSchemeId] NVARCHAR(4000),
        [OrganisationName] NVARCHAR(4000),
        [OrganisationReference] NVARCHAR(4000),
        [OrganisationType] NVARCHAR(4000),
        [ProducerType] NVARCHAR(4000),
        [UserId] NVARCHAR(4000),
        [FirstName] NVARCHAR(4000),
        [LastName] NVARCHAR(4000),
        [Email] NVARCHAR(4000),
        [Telephone] NVARCHAR(4000),
        [ServiceRole] NVARCHAR(4000),
        [FileId] NVARCHAR(4000),
        [SubmissionPeriod] NVARCHAR(4000),
        [SubmittedDate] NVARCHAR(4000),
        [Decision] NVARCHAR(4000),
        [IsResubmissionRequired] BIT,
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