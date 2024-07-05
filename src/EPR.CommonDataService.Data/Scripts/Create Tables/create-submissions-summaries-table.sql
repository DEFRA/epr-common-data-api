IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[SubmissionsSummaries]') AND type in (N'U'))
BEGIN

CREATE TABLE [apps].[SubmissionsSummaries]
(
	[SubmissionId] [nvarchar](4000) NULL,
	[OrganisationId] [nvarchar](4000) NULL,
	[ComplianceSchemeId] [nvarchar](4000) NULL,
	[OrganisationName] [nvarchar](4000) NULL,
	[OrganisationReference] [nvarchar](4000) NULL,
	[OrganisationType] [nvarchar](4000) NULL,
	[ProducerType] [nvarchar](4000) NULL,
	[UserId] [nvarchar](4000) NULL,
	[FirstName] [nvarchar](4000) NULL,
	[LastName] [nvarchar](4000) NULL,
	[Email] [nvarchar](4000) NULL,
	[Telephone] [nvarchar](4000) NULL,
	[ServiceRole] [nvarchar](4000) NULL,
	[FileId] [nvarchar](4000) NULL,
	[SubmissionYear] [int] NULL,
	[SubmissionCode] [nvarchar](4000) NULL,
	[ActualSubmissionPeriod] [nvarchar](4000) NULL,
	[Combined_SubmissionCode] [nvarchar](4000) NULL,
	[Combined_ActualSubmissionPeriod] [nvarchar](4000) NULL,
	[SubmissionPeriod] [nvarchar](4000) NULL,
	[SubmittedDate] [nvarchar](4000) NULL,
	[Decision] [nvarchar](4000) NULL,
	[IsResubmissionRequired] [bit] NULL,
	[Comments] [nvarchar](4000) NULL,
	[IsResubmission] [bit] NULL,
	[PreviousRejectionComments] [nvarchar](4000) NULL,
	[NationId] [int] NULL
)
WITH
(
	DISTRIBUTION = HASH ( [SubmissionId] ),
	CLUSTERED COLUMNSTORE INDEX
);

END;
GO