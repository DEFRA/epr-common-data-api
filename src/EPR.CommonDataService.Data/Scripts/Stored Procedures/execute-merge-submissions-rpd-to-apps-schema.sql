/****** Object:  StoredProcedure [apps].[sp_MergeSubmissionsSummaries_629288]    Script Date: 04/11/2025 17:38:58 ******/
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_MergeSubmissionsSummaries]'))
	DROP PROCEDURE [apps].[sp_MergeSubmissionsSummaries];
GO

CREATE PROC [apps].[sp_MergeSubmissionsSummaries] AS
BEGIN
DECLARE @start_dt datetime;
DECLARE @batch_id INT;
Declare @msg nvarchar(4000);
DECLARE @cnt int;
select @batch_id  = ISNULL(max(batch_id),0)+1 from [dbo].[batch_log]

    BEGIN TRY


	
		set @start_dt = getdate()
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge Submissions', NULL, @start_dt, getdate(), 'Started',@batch_id


--New changes for the table = t_FetchOrganisationRegistrationSubmissionDetails_resub  from view = V_FetchOrganisationRegistrationSubmissionDetails_resub

		set @start_dt = getdate()
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[t_FetchOrganisationRegistrationSubmissionDetails_resub]') AND type in (N'U'))
		BEGIN
			CREATE TABLE [dbo].[t_FetchOrganisationRegistrationSubmissionDetails_resub]
			(
			[SubmissionId] [nvarchar](4000) NULL,
			[OrganisationId] [nvarchar](4000) NULL,
			[OrganisationName] [nvarchar](4000) NULL,
			[OrganisationReference] [nvarchar](20) NULL,
			[ApplicationReferenceNumber] [nvarchar](4000) NULL,
			[RegistrationReferenceNumber] [nvarchar](4000) NULL,
			[SubmissionStatus] [nvarchar](4000) NULL,
			[StatusPendingDate] [nvarchar](4000) NULL,
			[SubmittedDateTime] [nvarchar](4000) NULL,
			[IsLateSubmission] [bit] NULL,
			[IsResubmission] [bit] NULL,
			[ResubmissionStatus] [nvarchar](4000) NULL,
			[RegistrationDate] [nvarchar](4000) NULL,
			[ResubmissionDate] [nvarchar](4000) NULL,
			[ResubmissionFileId] [nvarchar](4000) NULL,
			[SubmissionPeriod] [nvarchar](4000) NULL,
			[RelevantYear] [int] NULL,
			[IsComplianceScheme] [bit] NULL,
			[OrganisationSize] [varchar](5) NULL,
			[OrganisationType] [varchar](10) NULL,
			[NationId] [int] NULL,
			[NationCode] [varchar](6) NULL,
			[RegulatorComment] [nvarchar](4000) NULL,
			[ProducerComment] [nvarchar](4000) NULL,
			[RegulatorDecisionDate] [nvarchar](4000) NULL,
			[RegulatorResubmissionDecisionDate] [nvarchar](4000) NULL,
			[RegulatorUserId] [nvarchar](4000) NULL,
			[CompaniesHouseNumber] [nvarchar](4000) NULL,
			[BuildingName] [nvarchar](4000) NULL,
			[SubBuildingName] [nvarchar](4000) NULL,
			[BuildingNumber] [nvarchar](4000) NULL,
			[Street] [nvarchar](4000) NULL,
			[Locality] [nvarchar](4000) NULL,
			[DependentLocality] [nvarchar](4000) NULL,
			[Town] [nvarchar](4000) NULL,
			[County] [nvarchar](4000) NULL,
			[Country] [nvarchar](4000) NULL,
			[Postcode] [nvarchar](4000) NULL,
			[SubmittedUserId] [nvarchar](4000) NULL,
			[FirstName] [nvarchar](4000) NULL,
			[LastName] [nvarchar](4000) NULL,
			[Email] [nvarchar](4000) NULL,
			[Telephone] [nvarchar](4000) NULL,
			[ServiceRole] [nvarchar](100) NULL,
			[ServiceRoleId] [int] NULL,
			[IsOnlineMarketplace] [bit] NULL,
			[NumberOfSubsidiaries] [int] NOT NULL,
			[NumberOfOnlineSubsidiaries] [int] NOT NULL,
			[CompanyDetailsFileId] [nvarchar](4000) NULL,
			[CompanyDetailsFileName] [nvarchar](4000) NULL,
			[CompanyDetailsBlobName] [nvarchar](4000) NULL,
			[PartnershipFileId] [nvarchar](4000) NULL,
			[PartnershipFileName] [nvarchar](4000) NULL,
			[PartnershipBlobName] [nvarchar](4000) NULL,
			[BrandsFileId] [nvarchar](4000) NULL,
			[BrandsFileName] [nvarchar](4000) NULL,
			[BrandsBlobName] [nvarchar](4000) NULL,
			[ComplianceSchemeId] [nvarchar](4000) NULL,
			[CSId] [nvarchar](4000) NULL,
			[CSOJson] [nvarchar](max) NULL
			)
			WITH
			(
			DISTRIBUTION = HASH ( [SubmissionId] ),
			HEAP
			);
			insert into dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub 
			select * from dbo.V_FetchOrganisationRegistrationSubmissionDetails_resub;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create t_FetchOrganisationRegistrationSubmissionDetails_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		ELSE
		BEGIN
			set @start_dt = getdate()
			--removing duplicates from t_FetchOrganisationRegistrationSubmissionDetails_resub;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','remove dup t_FetchOrganisationRegistrationSubmissionDetails_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
			delete from t_FetchOrganisationRegistrationSubmissionDetails_resub
			where SubmissionID in 
			(
				select SubmissionId
				from dbo.V_FetchOrganisationRegistrationSubmissionDetails_resub
				group by SubmissionId
				having count(1) > 1
			);
			
			set @start_dt = getdate()
			--truncate table t_FetchOrganisationRegistrationSubmissionDetails_resub;  *** removed 
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge start t_FetchOrganisationRegistrationSubmissionDetails_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
			--***Added to Merge instead of truncate and insert

			MERGE INTO t_FetchOrganisationRegistrationSubmissionDetails_resub AS Target
			 USING V_FetchOrganisationRegistrationSubmissionDetails_resub AS Source
			 ON Target.SubmissionID = Source.SubmissionID

			 WHEN MATCHED THEN
			UPDATE SET
			 Target.[SubmissionId]						= Source.[SubmissionId]
			,Target.[OrganisationId]					= Source.[OrganisationId]
			,Target.[OrganisationName]					= Source.[OrganisationName]	
			,Target.[OrganisationReference]				= Source.[OrganisationReference]	
			,Target.[ApplicationReferenceNumber]		= Source.[ApplicationReferenceNumber]
			,Target.[RegistrationReferenceNumber]		= Source.[RegistrationReferenceNumber]
			,Target.[SubmissionStatus]					= Source.[SubmissionStatus]	
			,Target.[StatusPendingDate]					= Source.[StatusPendingDate]
			,Target.[SubmittedDateTime]					= Source.[SubmittedDateTime]	
			,Target.[IsLateSubmission]					= Source.[IsLateSubmission]	
			,Target.[IsResubmission]					= Source.[IsResubmission]
			,Target.[ResubmissionStatus]				= Source.[ResubmissionStatus]
			,Target.[RegistrationDate]					= Source.[RegistrationDate]
			,Target.[ResubmissionDate]					= Source.[ResubmissionDate]
			,Target.[ResubmissionFileId]				= Source.[ResubmissionFileId]
			,Target.[SubmissionPeriod]					= Source.[SubmissionPeriod]
			,Target.[RelevantYear]						= Source.[RelevantYear]
			,Target.[IsComplianceScheme]				= Source.[IsComplianceScheme]
			,Target.[OrganisationSize]					= Source.[OrganisationSize]
			,Target.[OrganisationType]					= Source.[OrganisationType]
			,Target.[NationId]							= Source.[NationId]
			,Target.[NationCode]						= Source.[NationCode]
			,Target.[RegulatorComment]					= Source.[RegulatorComment]
			,Target.[ProducerComment]					= Source.[ProducerComment]
			,Target.[RegulatorDecisionDate]				= Source.[RegulatorDecisionDate]
			,Target.[RegulatorResubmissionDecisionDate]	= Source.[RegulatorResubmissionDecisionDate]
			,Target.[RegulatorUserId]					= Source.[RegulatorUserId]
			,Target.[CompaniesHouseNumber]				= Source.[CompaniesHouseNumber]
			,Target.[BuildingName]						= Source.[BuildingName]
			,Target.[SubBuildingName]					= Source.[SubBuildingName]
			,Target.[BuildingNumber]					= Source.[BuildingNumber]
			,Target.[Street]							= Source.[Street]
			,Target.[Locality]							= Source.[Locality]
			,Target.[DependentLocality]					= Source.[DependentLocality]
			,Target.[Town]								= Source.[Town]
			,Target.[County]							= Source.[County]
			,Target.[Country]							= Source.[Country]
			,Target.[Postcode]							= Source.[Postcode]
			,Target.[SubmittedUserId]					= Source.[SubmittedUserId]
			,Target.[FirstName]							= Source.[FirstName]
			,Target.[LastName]							= Source.[LastName]
			,Target.[Email]								= Source.[Email]
			,Target.[Telephone]							= Source.[Telephone]
			,Target.[ServiceRole]						= Source.[ServiceRole]
			,Target.[ServiceRoleId]						= Source.[ServiceRoleId]
			,Target.[IsOnlineMarketplace]				= Source.[IsOnlineMarketplace]
			,Target.[NumberOfSubsidiaries]				= Source.[NumberOfSubsidiaries]
			,Target.[NumberOfOnlineSubsidiaries]		= Source.[NumberOfOnlineSubsidiaries]
			,Target.[CompanyDetailsFileId]				= Source.[CompanyDetailsFileId]
			,Target.[CompanyDetailsFileName]			= Source.[CompanyDetailsFileName]
			,Target.[CompanyDetailsBlobName]			= Source.[CompanyDetailsBlobName]
			,Target.[PartnershipFileId]					= Source.[PartnershipFileId]
			,Target.[PartnershipFileName]				= Source.[PartnershipFileName]
			,Target.[PartnershipBlobName]				= Source.[PartnershipBlobName]
			,Target.[BrandsFileId]						= Source.[BrandsFileId]
			,Target.[BrandsFileName]					= Source.[BrandsFileName]
			,Target.[BrandsBlobName]					= Source.[BrandsBlobName]
			,Target.[ComplianceSchemeId]				= Source.[ComplianceSchemeId]
			,Target.[CSId]								= Source.[CSId]
			,Target.[CSOJson]							= Source.[CSOJson]

			WHEN NOT MATCHED BY TARGET THEN
		INSERT (
		[SubmissionId]
      ,[OrganisationId]
      ,[OrganisationName]
      ,[OrganisationReference]
      ,[ApplicationReferenceNumber]
      ,[RegistrationReferenceNumber]
      ,[SubmissionStatus]
      ,[StatusPendingDate]
      ,[SubmittedDateTime]
      ,[IsLateSubmission]
      ,[IsResubmission]
      ,[ResubmissionStatus]
      ,[RegistrationDate]
      ,[ResubmissionDate]
      ,[ResubmissionFileId]
      ,[SubmissionPeriod]
      ,[RelevantYear]
      ,[IsComplianceScheme]
      ,[OrganisationSize]
      ,[OrganisationType]
      ,[NationId]
      ,[NationCode]
      ,[RegulatorComment]
      ,[ProducerComment]
      ,[RegulatorDecisionDate]
      ,[RegulatorResubmissionDecisionDate]
      ,[RegulatorUserId]
      ,[CompaniesHouseNumber]
      ,[BuildingName]
      ,[SubBuildingName]
      ,[BuildingNumber]
      ,[Street]
      ,[Locality]
      ,[DependentLocality]
      ,[Town]
      ,[County]
      ,[Country]
      ,[Postcode]
      ,[SubmittedUserId]
      ,[FirstName]
      ,[LastName]
      ,[Email]
      ,[Telephone]
      ,[ServiceRole]
      ,[ServiceRoleId]
      ,[IsOnlineMarketplace]
      ,[NumberOfSubsidiaries]
      ,[NumberOfOnlineSubsidiaries]
      ,[CompanyDetailsFileId]
      ,[CompanyDetailsFileName]
      ,[CompanyDetailsBlobName]
      ,[PartnershipFileId]
      ,[PartnershipFileName]
      ,[PartnershipBlobName]
      ,[BrandsFileId]
      ,[BrandsFileName]
      ,[BrandsBlobName]
      ,[ComplianceSchemeId]
      ,[CSId]
      ,[CSOJson]
	)
	VALUES (
		Source.[SubmissionId]
		,Source.[OrganisationId]
		,Source.[OrganisationName]
		,Source.[OrganisationReference]
		,Source.[ApplicationReferenceNumber]
		,Source.[RegistrationReferenceNumber]
		,Source.[SubmissionStatus]
		,Source.[StatusPendingDate]
		,Source.[SubmittedDateTime]
		,Source.[IsLateSubmission]
		,Source.[IsResubmission]
		,Source.[ResubmissionStatus]
		,Source.[RegistrationDate]
		,Source.[ResubmissionDate]
		,Source.[ResubmissionFileId]
		,Source.[SubmissionPeriod]
		,Source.[RelevantYear]
		,Source.[IsComplianceScheme]
		,Source.[OrganisationSize]
		,Source.[OrganisationType]
		,Source.[NationId]
		,Source.[NationCode]
		,Source.[RegulatorComment]
		,Source.[ProducerComment]
		,Source.[RegulatorDecisionDate]
		,Source.[RegulatorResubmissionDecisionDate]
		,Source.[RegulatorUserId]
		,Source.[CompaniesHouseNumber]
		,Source.[BuildingName]
		,Source.[SubBuildingName]
		,Source.[BuildingNumber]
		,Source.[Street]
		,Source.[Locality]
		,Source.[DependentLocality]
		,Source.[Town]
		,Source.[County]
		,Source.[Country]
		,Source.[Postcode]
		,Source.[SubmittedUserId]
		,Source.[FirstName]
		,Source.[LastName]
		,Source.[Email]
		,Source.[Telephone]
		,Source.[ServiceRole]
		,Source.[ServiceRoleId]
		,Source.[IsOnlineMarketplace]
		,Source.[NumberOfSubsidiaries]
		,Source.[NumberOfOnlineSubsidiaries]
		,Source.[CompanyDetailsFileId]
		,Source.[CompanyDetailsFileName]
		,Source.[CompanyDetailsBlobName]
		,Source.[PartnershipFileId]
		,Source.[PartnershipFileName]
		,Source.[PartnershipBlobName]
		,Source.[BrandsFileId]
		,Source.[BrandsFileName]
		,Source.[BrandsBlobName]
		,Source.[ComplianceSchemeId]
		,Source.[CSId]
		,Source.[CSOJson]
		)
	    WHEN NOT MATCHED BY SOURCE THEN
        DELETE; -- delete from table when no longer in source

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge complete t_FetchOrganisationRegistrationSubmissionDetails_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','t_FetchOrganisationRegistrationSubmissionDetails_resub', @cnt, @start_dt, getdate(), 'count',@batch_id;






	--New changes for the table dbo.t_CSO_Pom_Resubmitted_ByCSID
		set @start_dt = getdate()
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[t_CSO_Pom_Resubmitted_ByCSID]') AND type in (N'U'))
		BEGIN
			select * into dbo.t_CSO_Pom_Resubmitted_ByCSID from dbo.v_CSO_Pom_Resubmitted_ByCSID;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create t_CSO_Pom_Resubmitted_ByCSID', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		ELSE
		BEGIN
			set @start_dt = getdate()
			truncate table dbo.t_CSO_Pom_Resubmitted_ByCSID;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','truncate t_CSO_Pom_Resubmitted_ByCSID', NULL, @start_dt, getdate(), 'Completed',@batch_id
			

			insert into dbo.t_CSO_Pom_Resubmitted_ByCSID
			select * from dbo.v_CSO_Pom_Resubmitted_ByCSID;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','generate t_CSO_Pom_Resubmitted_ByCSID', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from dbo.t_CSO_Pom_Resubmitted_ByCSID;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','dbo.t_CSO_Pom_Resubmitted_ByCSID', @cnt, @start_dt, getdate(), 'count',@batch_id;


		--New changes for the table = apps.OrgRegistrationsSummaries  from view = [apps].[v_OrganisationRegistrationSummaries]
		IF OBJECT_ID('tempdb..#OrgRegistrationsSummaries') IS NOT NULL
			DROP TABLE #OrgRegistrationsSummaries;

		--If table exists but is incorrect distribution then drop
		IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'apps.OrgRegistrationsSummaries') AND type in (N'U')) AND NOT EXISTS( SELECT * FROM sys.pdw_table_distribution_properties where OBJECT_SCHEMA_NAME( object_id )='apps' AND OBJECT_NAME( object_id ) ='OrgRegistrationsSummaries' and distribution_policy_desc='HASH')
		BEGIN
			DROP TABLE [apps].[OrgRegistrationsSummaries]
		END
		
		set @start_dt = getdate()
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'apps.OrgRegistrationsSummaries') AND type in (N'U'))
		BEGIN

			CREATE TABLE [apps].[OrgRegistrationsSummaries]
			(
				[SubmissionId] [nvarchar](4000) NULL,
				[OrganisationId] [nvarchar](4000) NULL,
				[OrganisationInternalId] [int] NULL,
				[OrganisationName] [nvarchar](4000) NULL,
				[UploadedOrganisationName] [nvarchar](4000) NULL,
				[OrganisationReference] [nvarchar](4000) NULL,
				[SubmittedUserId] [nvarchar](4000) NULL,
				[IsComplianceScheme] [int] NOT NULL,
				[OrganisationType] [varchar](10) NULL,
				[ProducerSize] [varchar](5) NULL,
				[ApplicationReferenceNumber] [nvarchar](4000) NULL,
				[RegistrationReferenceNumber] [nvarchar](4000) NULL,
				[SubmittedDateTime] [nvarchar](4000) NULL,
				[FirstSubmissionDate] [nvarchar](4000) NULL,
				[RegistrationDate] [nvarchar](4000) NULL,
				[IsResubmission] [int] NOT NULL,
				[ResubmissionDate] [nvarchar](4000) NULL,
				[RelevantYear] [int] NULL,
				[SubmissionPeriod] [nvarchar](4000) NULL,
				[IsLateSubmission] [bit] NULL,
				[SubmissionStatus] [nvarchar](4000) NOT NULL,
				[ResubmissionStatus] [nvarchar](4000) NULL,
				[ResubmissionDecisionDate] [nvarchar](4000) NULL,
				[RegulatorDecisionDate] [nvarchar](4000) NULL,
				[StatusPendingDate] [nvarchar](4000) NULL,
				[NationId] [int] NULL,
				[NationCode] [varchar](6) NULL,
				[ComplianceSchemeId] [nvarchar](4000) NULL,
				[ProducerComment] [nvarchar](4000) NULL,
				[RegulatorComment] [nvarchar](4000) NULL,
				[FileId] [nvarchar](4000) NULL,
				[ResubmissionComment] [nvarchar](4000) NULL,
				[ResubmittedUserId] [nvarchar](4000) NULL,
				[ProducerUserId] [nvarchar](4000) NULL,
				[RegulatorUserId] [nvarchar](4000) NULL
			)
			WITH
			(
				DISTRIBUTION = HASH ( [FileId] ),
				CLUSTERED COLUMNSTORE INDEX
			);

			insert into apps.OrgRegistrationsSummaries
			select * from [apps].[v_OrganisationRegistrationSummaries];

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create apps.OrgRegistrationsSummaries', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		ELSE
		BEGIN
			set @start_dt = getdate()
			--truncate table apps.OrgRegistrationsSummaries;  *** removed as part of 596708
			--INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			--select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','truncate apps.OrgRegistrationsSummaries', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
			--***Added as part of 596708 to Merge instead of truncate and insert
	
			select * INTO #OrgRegistrationsSummaries from [apps].[v_OrganisationRegistrationSummaries] ;

			MERGE INTO apps.OrgRegistrationsSummaries AS Target
				USING #OrgRegistrationsSummaries AS Source
			 	ON Target.SubmissionID = Source.SubmissionID and Target.OrganisationID = Source.OrganisationID
			WHEN MATCHED THEN
        		UPDATE SET
					Target.[SubmissionId] = Source.SubmissionId
					,Target.[OrganisationId] = Source.OrganisationId
					,Target.[OrganisationInternalId] = Source.OrganisationInternalId
					,Target.[OrganisationName] = Source.OrganisationName
					,Target.[UploadedOrganisationName] = Source.UploadedOrganisationName
					,Target.[OrganisationReference] = Source.OrganisationReference
					,Target.[SubmittedUserId] = Source.SubmittedUserId
					,Target.[IsComplianceScheme] = Source.IsComplianceScheme
					,Target.[OrganisationType] = Source.OrganisationType
					,Target.[ProducerSize] = Source.ProducerSize
					,Target.[ApplicationReferenceNumber] = Source.ApplicationReferenceNumber
					,Target.[RegistrationReferenceNumber] = Source.RegistrationReferenceNumber
					,Target.[SubmittedDateTime] = Source.SubmittedDateTime
					,Target.[FirstSubmissionDate] = Source.FirstSubmissionDate
					,Target.[RegistrationDate] = Source.RegistrationDate
					,Target.[IsResubmission] = Source.IsResubmission
					,Target.[ResubmissionDate] = Source.ResubmissionDate
					,Target.[RelevantYear] = Source.RelevantYear
					,Target.[SubmissionPeriod] = Source.SubmissionPeriod
					,Target.[IsLateSubmission] = Source.IsLateSubmission
					,Target.[SubmissionStatus] = Source.SubmissionStatus
					,Target.[ResubmissionStatus] = Source.ResubmissionStatus
					,Target.[ResubmissionDecisionDate] = Source.ResubmissionDecisionDate
					,Target.[RegulatorDecisionDate] = Source.RegulatorDecisionDate
					,Target.[StatusPendingDate] = Source.StatusPendingDate
					,Target.[NationId] = Source.NationId
					,Target.[NationCode] = Source.NationCode
					,Target.[ComplianceSchemeId] = Source.ComplianceSchemeId
					,Target.[ProducerComment] = Source.ProducerComment
					,Target.[RegulatorComment] = Source.RegulatorComment
					,Target.[FileId] = Source.FileId
					,Target.[ResubmissionComment] = Source.ResubmissionComment
					,Target.[ResubmittedUserId] = Source.ResubmittedUserId
					,Target.[ProducerUserId] = Source.ProducerUserId
					,Target.[RegulatorUserId] = Source.RegulatorUserId
        	WHEN NOT MATCHED BY TARGET THEN
        		INSERT (
					[SubmissionId]
					,[OrganisationId]
					,[OrganisationInternalId]
					,[OrganisationName]
					,[UploadedOrganisationName]
					,[OrganisationReference]
					,[SubmittedUserId]
					,[IsComplianceScheme]
					,[OrganisationType]
					,[ProducerSize]
					,[ApplicationReferenceNumber]
					,[RegistrationReferenceNumber]
					,[SubmittedDateTime]
					,[FirstSubmissionDate]
					,[RegistrationDate]
					,[IsResubmission]
					,[ResubmissionDate]
					,[RelevantYear]
					,[SubmissionPeriod]
					,[IsLateSubmission]
					,[SubmissionStatus]
					,[ResubmissionStatus]
					,[ResubmissionDecisionDate]
					,[RegulatorDecisionDate]
					,[StatusPendingDate]
					,[NationId]
					,[NationCode]
					,[ComplianceSchemeId]
					,[ProducerComment]
					,[RegulatorComment]
					,[FileId]
					,[ResubmissionComment]
					,[ResubmittedUserId]
					,[ProducerUserId]
					,[RegulatorUserId]
				)
				VALUES (
					Source.[SubmissionId]
					,Source.[OrganisationId]
					,Source.[OrganisationInternalId]
					,Source.[OrganisationName]
					,Source.[UploadedOrganisationName]
					,Source.[OrganisationReference]
					,Source.[SubmittedUserId]
					,Source.[IsComplianceScheme]
					,Source.[OrganisationType]
					,Source.[ProducerSize]
					,Source.[ApplicationReferenceNumber]
					,Source.[RegistrationReferenceNumber]
					,Source.[SubmittedDateTime]
					,Source.[FirstSubmissionDate]
					,Source.[RegistrationDate]
					,Source.[IsResubmission]
					,Source.[ResubmissionDate]
					,Source.[RelevantYear]
					,Source.[SubmissionPeriod]
					,Source.[IsLateSubmission]
					,Source.[SubmissionStatus]
					,Source.[ResubmissionStatus]
					,Source.[ResubmissionDecisionDate]
					,Source.[RegulatorDecisionDate]
					,Source.[StatusPendingDate]
					,Source.[NationId]
					,Source.[NationCode]
					,Source.[ComplianceSchemeId]
					,Source.[ProducerComment]
					,Source.[RegulatorComment]
					,Source.[FileId]
					,Source.[ResubmissionComment]
					,Source.[ResubmittedUserId]
					,Source.[ProducerUserId]
					,Source.[RegulatorUserId]
				)
	    	WHEN NOT MATCHED BY SOURCE THEN
            	DELETE; -- delete from table when no longer in source

    	DROP TABLE #OrgRegistrationsSummaries;
        INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
           select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge apps.OrgRegistrationsSummaries', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from apps.OrgRegistrationsSummaries;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.OrgRegistrationsSummaries', @cnt, @start_dt, getdate(), 'count',@batch_id;





		--New changes for the table dbo.t_ProducerPayCalParameters_resub
		set @start_dt = getdate()
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[t_ProducerPayCalParameters_resub]') AND type in (N'U'))
		BEGIN
			select * into dbo.t_ProducerPayCalParameters_resub from dbo.v_ProducerPayCalParameters_resub;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create t_ProducerPayCalParameters_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		ELSE
		BEGIN
			set @start_dt = getdate()
			truncate table dbo.t_ProducerPayCalParameters_resub;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','truncate t_ProducerPayCalParameters_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
			

			insert into dbo.t_ProducerPayCalParameters_resub
			select * from dbo.v_ProducerPayCalParameters_resub;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','generate t_ProducerPayCalParameters_resub', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from dbo.t_ProducerPayCalParameters_resub;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','dbo.t_ProducerPayCalParameters_resub', @cnt, @start_dt, getdate(), 'count',@batch_id;


		--New changes for the table = dbo.t_submitted_pom_org_file_status  from view = [dbo].[v_submitted_pom_org_file_status]
		set @start_dt = getdate()
		--If table exists but is incorrect distribution then drop table
		IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.t_submitted_pom_org_file_status') AND type in (N'U')) AND NOT EXISTS( SELECT * FROM sys.pdw_table_distribution_properties where OBJECT_SCHEMA_NAME( object_id )='dbo' AND OBJECT_NAME( object_id ) ='t_submitted_pom_org_file_status' and distribution_policy_desc='HASH')
		BEGIN
			DROP TABLE [dbo].[t_submitted_pom_org_file_status];
		END

		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.t_submitted_pom_org_file_status') AND type in (N'U'))
		BEGIN

			CREATE TABLE [dbo].[t_submitted_pom_org_file_status]
			(
				[SubmissionId] [nvarchar](4000) NULL,
				[RegistrationSetId] [nvarchar](4000) NULL,
				[OrganisationId] [nvarchar](4000) NULL,
				[FileName] [nvarchar](4000) NULL,
				[FileType] [nvarchar](4000) NULL,
				[OriginalFileName] [nvarchar](4000) NULL,
				[TargetDirectoryName] [nvarchar](4000) NULL,
				[Decision_Date] [nvarchar](4000) NULL,
				[Regulator_Status] [nvarchar](4000) NULL,
				[RegulatorDecision] [varchar](1) NOT NULL,
				[Regulator_User_Name] [nvarchar](4000) NOT NULL,
				[Regulator_Rejection_Comments] [nvarchar](4000) NULL,
				[RejectionComments] [varchar](1) NOT NULL,
				[Type] [nvarchar](4000) NULL,
				[UserId] [nvarchar](4000) NULL,
				[RowNumber] [bigint] NULL,
				[Created] [nvarchar](4000) NULL,
				[Application_submitted_ts] [nvarchar](4000) NULL,
				[RegistrationType] [int] NULL,
				[SubmissionPeriod] [nvarchar](4000) NULL,
				[ApplicationReferenceNo] [nvarchar](4000) NULL,
				[registrationreferencenumber] [nvarchar](4000) NULL,
				[Original_Regulator_Status] [nvarchar](4000) NULL,
				[SubmissionType] [nvarchar](4000) NULL,
				[IsResubmission_identifier] [bit] NOT NULL,
				[Is_resubmitted_POM_identifier] [int] NOT NULL,
				[cfm_FileId] [nvarchar](4000) NULL,
				[FileId] [nvarchar](4000) NULL,
				[fileid_new] [nvarchar](4000) NULL,
				[submitted_Fileid] [nvarchar](4000) NULL,
				[SubmissionEventId_of_submitted_record] [nvarchar](4000) NULL,
				[app_submitted_Fileid] [nvarchar](4000) NULL,
				[SubmissionEventId_of_application_submitted_record] [nvarchar](4000) NULL
			)
			WITH
			(
				DISTRIBUTION = HASH ( [FileName] ),
				CLUSTERED COLUMNSTORE INDEX
			);
			--select * into dbo.t_submitted_pom_org_file_status from [dbo].[v_submitted_pom_org_file_status];
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create blank dbo.t_submitted_pom_org_file_status', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		
		BEGIN
			set @start_dt = getdate()

			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.t_submitted_pom_org_file_status_temp') AND type in (N'U'))
			BEGIN
				drop table dbo.t_submitted_pom_org_file_status_temp;
				INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
				select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','dropped dbo.t_submitted_pom_org_file_status_temp', NULL, @start_dt, getdate(), 'Completed',@batch_id
			END;

			select * into dbo.t_submitted_pom_org_file_status_temp from [dbo].[v_submitted_pom_org_file_status];
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create dbo.t_submitted_pom_org_file_status_temp', NULL, @start_dt, getdate(), 'Completed',@batch_id

			MERGE INTO dbo.t_submitted_pom_org_file_status AS Target
				USING dbo.t_submitted_pom_org_file_status_temp AS Source
				ON Target.FileName = Source.FileName
				WHEN MATCHED THEN
					UPDATE SET
						Target.SubmissionId = Source.SubmissionId,
						Target.RegistrationSetId = Source.RegistrationSetId,
						Target.OrganisationId = Source.OrganisationId,
						Target.FileName = Source.FileName,
						Target.FileType = Source.FileType,
						Target.OriginalFileName = Source.OriginalFileName,
						Target.TargetDirectoryName = Source.TargetDirectoryName,
						Target.Decision_Date = Source.Decision_Date,
						Target.Regulator_Status = Source.Regulator_Status,
						Target.RegulatorDecision = Source.RegulatorDecision,
						Target.Regulator_User_Name = Source.Regulator_User_Name,
						Target.Regulator_Rejection_Comments = Source.Regulator_Rejection_Comments,
						Target.RejectionComments = Source.RejectionComments,
						Target.Type = Source.Type,
						Target.UserId = Source.UserId,
						Target.RowNumber = Source.RowNumber,
						Target.Created = Source.Created,
						Target.Application_submitted_ts = Source.Application_submitted_ts,
						Target.RegistrationType = Source.RegistrationType,
						Target.SubmissionPeriod = Source.SubmissionPeriod,
						Target.ApplicationReferenceNo = Source.ApplicationReferenceNo,
						Target.registrationreferencenumber = Source.registrationreferencenumber,
						Target.Original_Regulator_Status = Source.Original_Regulator_Status,
						Target.SubmissionType = Source.SubmissionType,
						Target.IsResubmission_identifier = Source.IsResubmission_identifier,
						Target.Is_resubmitted_POM_identifier = Source.Is_resubmitted_POM_identifier,
						Target.cfm_FileId = Source.cfm_FileId,
						Target.FileId = Source.FileId,
						Target.fileid_new = Source.fileid_new,
						Target.submitted_Fileid = Source.submitted_Fileid,
						Target.SubmissionEventId_of_submitted_record = Source.SubmissionEventId_of_submitted_record,
						Target.app_submitted_Fileid = Source.app_submitted_Fileid,
						Target.SubmissionEventId_of_application_submitted_record = Source.SubmissionEventId_of_application_submitted_record
				WHEN NOT MATCHED BY TARGET THEN
					INSERT ([SubmissionId]
								   ,[RegistrationSetId]
								   ,[OrganisationId]
								   ,[FileName]
								   ,[FileType]
								   ,[OriginalFileName]
								   ,[TargetDirectoryName]
								   ,[Decision_Date]
								   ,[Regulator_Status]
								   ,[RegulatorDecision]
								   ,[Regulator_User_Name]
								   ,[Regulator_Rejection_Comments]
								   ,[RejectionComments]
								   ,[Type]
								   ,[UserId]
								   ,[RowNumber]
								   ,[Created]
								   ,[Application_submitted_ts]
								   ,[RegistrationType]
								   ,[SubmissionPeriod]
								   ,[ApplicationReferenceNo]
								   ,[registrationreferencenumber]
								   ,[Original_Regulator_Status]
								   ,[SubmissionType]
								   ,[IsResubmission_identifier]
								   ,[Is_resubmitted_POM_identifier]
								   ,[cfm_FileId]
								   ,[FileId]
								   ,[fileid_new]
								   ,[submitted_Fileid]
								   ,[SubmissionEventId_of_submitted_record]
								   ,[app_submitted_Fileid]
								   ,[SubmissionEventId_of_application_submitted_record])
								  VALUES (
								  Source.[SubmissionId]
								   ,Source.[RegistrationSetId]
								   ,Source.[OrganisationId]
								   ,Source.[FileName]
								   ,Source.[FileType]
								   ,Source.[OriginalFileName]
								   ,Source.[TargetDirectoryName]
								   ,Source.[Decision_Date]
								   ,Source.[Regulator_Status]
								   ,Source.[RegulatorDecision]
								   ,Source.[Regulator_User_Name]
								   ,Source.[Regulator_Rejection_Comments]
								   ,Source.[RejectionComments]
								   ,Source.[Type]
								   ,Source.[UserId]
								   ,Source.[RowNumber]
								   ,Source.[Created]
								   ,Source.[Application_submitted_ts]
								   ,Source.[RegistrationType]
								   ,Source.[SubmissionPeriod]
								   ,Source.[ApplicationReferenceNo]
								   ,Source.[registrationreferencenumber]
								   ,Source.[Original_Regulator_Status]
								   ,Source.[SubmissionType]
								   ,Source.[IsResubmission_identifier]
								   ,Source.[Is_resubmitted_POM_identifier]
								   ,Source.[cfm_FileId]
								   ,Source.[FileId]
								   ,Source.[fileid_new]
								   ,Source.[submitted_Fileid]
								   ,Source.[SubmissionEventId_of_submitted_record]
								   ,Source.[app_submitted_Fileid]
								   ,Source.[SubmissionEventId_of_application_submitted_record]
								    )
				WHEN NOT MATCHED BY SOURCE THEN
					DELETE;

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge dbo.t_submitted_pom_org_file_status', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from dbo.t_submitted_pom_org_file_status
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','dbo.t_submitted_pom_org_file_status', @cnt, @start_dt, getdate(), 'count',@batch_id;



		select @cnt =count(1) from rpd.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','rpd.submissions', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

		select @cnt =count(1) from apps.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.submissions', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

		delete from apps.Submissions where id in 
		(
			select id from apps.Submissions group by created,id,load_ts having count(1) > 1 
		);

        -- Merge rpd.submissions into apps.submissions
        EXEC [apps].[sp_DynamicTableMerge]
            @sourceSchema = 'rpd',
            @sourceTableName = 'Submissions',
            @targetSchema = 'apps',
            @targetTableName = 'Submissions',
            @matchColumns = 'created,id,load_ts'
    
		select @cnt =count(1) from rpd.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','rpd.submissions', @cnt, @start_dt, getdate(), 'count-after',@batch_id;

		select @cnt =count(1) from apps.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.submissions', @cnt, @start_dt, getdate(), 'count-after',@batch_id;

		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge Submissions', NULL, @start_dt, getdate(), 'Completed',@batch_id



		

		set @start_dt = getdate()
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge SubmissionEvents', NULL, @start_dt, getdate(), 'Started',@batch_id

		select @cnt =count(1) from rpd.submissionEvents;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','rpd.submissionEvents', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

		select @cnt =count(1) from apps.submissionEvents;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.submissionEvents', @cnt, @start_dt, getdate(), 'count-before',@batch_id;


		delete from apps.SubmissionEvents where id in 
		(
			select id from apps.SubmissionEvents group by created,id,load_ts having count(1) > 1 
		);

        -- Merge rpd.submissionEvents into apps.submissionEvents
        EXEC [apps].[sp_DynamicTableMerge]
            @sourceSchema = 'rpd',
            @sourceTableName = 'SubmissionEvents',
            @targetSchema = 'apps',
            @targetTableName = 'SubmissionEvents',
            @matchColumns = 'created,id,load_ts'
 
		select @cnt =count(1) from rpd.submissionEvents;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','rpd.submissionEvents', @cnt, @start_dt, getdate(), 'count-after',@batch_id;

		select @cnt =count(1) from apps.submissionEvents;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.submissionEvents', @cnt, @start_dt, getdate(), 'count-after',@batch_id;

		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','merge SubmissionEvents', NULL, @start_dt, getdate(), 'Completed',@batch_id


----New code for dbo.t_PomResubmissionPaycalEvents ticket 629288
	IF OBJECT_ID('tempdb..#PomResubmissionPaycalEvents') IS NOT NULL
		DROP TABLE #PomResubmissionPaycalEvents;
		--If table exists but is incorrect distribution then drop
		IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.t_PomResubmissionPaycalEvents') AND type in (N'U')) AND NOT EXISTS( SELECT * FROM sys.pdw_table_distribution_properties where OBJECT_SCHEMA_NAME( object_id )='dbo' AND OBJECT_NAME( object_id ) ='t_PomResubmissionPaycalEvents' and distribution_policy_desc='HASH')
		BEGIN
			DROP TABLE dbo.t_PomResubmissionPaycalEvents
		END

		set @start_dt = getdate()
		IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.t_PomResubmissionPaycalEvents') AND type in (N'U')) 
		BEGIN

			CREATE TABLE dbo.t_PomResubmissionPaycalEvents
			(
				[SubmissionId] [nvarchar](4000) NULL,
				[PackagingResubmissionReferenceNumber] [nvarchar](4000) NULL
				
			)
			WITH
			(
				DISTRIBUTION = HASH ( [SubmissionId] ),
				CLUSTERED COLUMNSTORE INDEX
			);

			insert into dbo.t_PomResubmissionPaycalEvents
			Select SubmissionID, PackagingResubmissionReferenceNumber from
					(
  					select  SubmissionID, PackagingResubmissionReferenceNumber,created, ROW_NUMBER() OVER (PARTITION BY SubmissionID Order By created desc)  as RowNum FROM apps.SubmissionEvents se 
					where se.[Type] = 'PackagingResubmissionReferenceNumberCreated'
					)se2 where RowNum=1;

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','create dbo.t_PomResubmissionPaycalEvents', NULL, @start_dt, getdate(), 'Completed',@batch_id
		END;	
		ELSE
		BEGIN
			set @start_dt = getdate()

	

			Select SubmissionID, PackagingResubmissionReferenceNumber  INTO #PomResubmissionPaycalEvents from 
					(
  					select  SubmissionID, PackagingResubmissionReferenceNumber,created, ROW_NUMBER() OVER (PARTITION BY SubmissionID Order By created desc)  as RowNum FROM apps.SubmissionEvents se 
					where se.[Type] = 'PackagingResubmissionReferenceNumberCreated'
					)se2 where RowNum=1;

			MERGE INTO dbo.t_PomResubmissionPaycalEvents AS Target
			 USING #PomResubmissionPaycalEvents AS Source
			 ON Target.SubmissionID = Source.SubmissionID

			 WHEN MATCHED THEN
        UPDATE SET
	   Target.[SubmissionId] = Source.SubmissionId
      ,Target.PackagingResubmissionReferenceNumber = Source.PackagingResubmissionReferenceNumber


		WHEN NOT MATCHED BY TARGET THEN
    INSERT (
		[SubmissionId]
      ,PackagingResubmissionReferenceNumber
	  )
	VALUES (
	   Source.[SubmissionId]
      ,Source.PackagingResubmissionReferenceNumber
     
	)
	    WHEN NOT MATCHED BY SOURCE THEN
        DELETE; -- delete from table when no longer in source

	DROP TABLE #PomResubmissionPaycalEvents
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','generate dbo.t_PomResubmissionPaycalEvents', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
		END;	

		select @cnt =count(1) from dbo.t_PomResubmissionPaycalEvents;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','dbo.t_PomResubmissionPaycalEvents', @cnt, @start_dt, getdate(), 'count',@batch_id;


 ---End of new code for dbo.t_PomResubmissionPaycalEvents ticket 629288

 
        -- If no errors occur, execute the next set of procedures
        BEGIN TRY

			set @start_dt = getdate()
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','sp_AggregateAndMergePomData', NULL, @start_dt, getdate(), 'Started',@batch_id

			select @cnt =count(1) from apps.SubmissionsSummaries;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.SubmissionsSummaries', @cnt, @start_dt, getdate(), 'count-before',@batch_id;
			
            EXEC [apps].[sp_AggregateAndMergePomData]

			select @cnt =count(1) from apps.SubmissionsSummaries;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.SubmissionsSummaries', @cnt, @start_dt, getdate(), 'count-after',@batch_id;

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','sp_AggregateAndMergePomData', NULL, @start_dt, getdate(), 'Completed',@batch_id



			set @start_dt = getdate()
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','sp_AggregateAndMergeRegistrationData', NULL, @start_dt, getdate(), 'Started',@batch_id

			select @cnt =count(1) from apps.RegistrationsSummaries;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.RegistrationsSummaries', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

            EXEC [apps].[sp_AggregateAndMergeRegistrationData]   

			select @cnt =count(1) from apps.RegistrationsSummaries;
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.RegistrationsSummaries', @cnt, @start_dt, getdate(), 'count-after',@batch_id;
		
			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','sp_AggregateAndMergeRegistrationData', NULL, @start_dt, getdate(), 'Completed',@batch_id

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','All', NULL, @start_dt, getdate(), 'Completed',@batch_id
			
        END TRY
        BEGIN CATCH

			select @msg = error_message();

			INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
			select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','Error', NULL, @start_dt, getdate(), @msg,@batch_id;

			throw 60000, @msg, 1

        END CATCH
    
    END TRY
    BEGIN CATCH

		select @msg = error_message();
		
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','Error', NULL, @start_dt, getdate(), @msg,@batch_id;

		throw 60000, @msg, 1

    END CATCH
END;
GO
