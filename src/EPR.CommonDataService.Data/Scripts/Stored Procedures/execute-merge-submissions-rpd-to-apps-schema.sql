-- Dropping stored procedure if it exists
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
