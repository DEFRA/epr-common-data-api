/****** Object:  Table [dbo].[t_CSO_Pom_Resubmitted_ByCSID]    Script Date: 04/11/2025 15:26:27 ******/
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[t_CSO_Pom_Resubmitted_ByCSID]') AND type in (N'U'))
BEGIN

	CREATE TABLE [dbo].[t_CSO_Pom_Resubmitted_ByCSID]
	(
		[CS_Reference_number] [nvarchar](4000) NULL,
		[CSid] [nvarchar](4000) NULL,
		[submissionperiod] [nvarchar](4000) NULL,
		[MemberCount] [int] NOT NULL
	)
	WITH
	(
		DISTRIBUTION = ROUND_ROBIN,
		CLUSTERED COLUMNSTORE INDEX
	)
END;
GO
