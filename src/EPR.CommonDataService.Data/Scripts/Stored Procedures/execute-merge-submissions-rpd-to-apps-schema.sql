﻿-- Dropping stored procedure if it exists
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





		select @cnt =count(1) from rpd.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','rpd.submissions', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

		select @cnt =count(1) from apps.submissions;
		INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
		select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'sp_MergeSubmissionsSummaries','apps.submissions', @cnt, @start_dt, getdate(), 'count-before',@batch_id;

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


