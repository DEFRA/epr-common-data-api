IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[apps].[SubmissionsSummaries]') AND type in (N'U'))
BEGIN
	DROP TABLE [apps].[SubmissionsSummaries]
END;

CREATE TABLE [apps].[SubmissionsSummaries]
(
	[SubmissionId] [nvarchar](38) NOT NULL,
	[OrganisationId] [nvarchar](38) NULL,
	[ComplianceSchemeId] [nvarchar](38) NULL,
	[UserId] [nvarchar](38) NULL,
	[FileId] [nvarchar](38) NULL,
	[OrganisationName] [nvarchar](255) NULL,
	[OrganisationReference] [int] NULL,
	[OrganisationType] [nvarchar](25) NULL,
	[ProducerType] [nvarchar](30) NULL,
	[FirstName] [nvarchar](255) NULL,
	[LastName] [nvarchar](255) NULL,
	[Email] [nvarchar](255) NULL,
	[Telephone] [nvarchar](25) NULL,
	[ServiceRole] [nvarchar](30) NULL,
	[SubmissionYear] [smallint] NULL,
	[SubmissionCode] [nvarchar](10) NULL,
	[ActualSubmissionPeriod] [nvarchar](50) NULL,
	[Combined_SubmissionCode] [nvarchar](55) NULL,
	[Combined_ActualSubmissionPeriod] [nvarchar](255) NULL,
	[SubmissionPeriod] [nvarchar](30) NULL,
	[SubmittedDate] [nvarchar](55) NULL,
	[Decision] [nvarchar](20) NULL,
	[IsResubmissionRequired] [bit] NULL,
	[Comments] [nvarchar](4000) NULL,
	[IsResubmission] [bit] NULL,
	[PreviousRejectionComments] [nvarchar](4000) NULL,
	[NationId] [tinyint] NULL,
	[PomFileName] [nvarchar](150) NULL,
	[PomBlobName] [nvarchar](38) NULL,
	[NEW_FLAG] [bit] NULL
)
WITH
(
	DISTRIBUTION = HASH ( [SubmissionId] ),
	CLUSTERED INDEX
	(
		[SubmissionId] ASC
	)
);
