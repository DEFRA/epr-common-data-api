-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_MergeSubmissionsSummaries]'))
DROP PROCEDURE [apps].[sp_MergeSubmissionsSummaries];
GO

CREATE PROCEDURE apps.sp_MergeSubmissionsSummaries
    AS
BEGIN

    BEGIN TRY
        -- Merge rpd.submissions into apps.submissions
        EXEC [apps].[sp_DynamicTableMerge]
            @sourceSchema = 'rpd',
            @sourceTableName = 'Submissions',
            @targetSchema = 'apps',
            @targetTableName = 'Submissions',
            @matchColumns = 'created,id,load_ts'
    
        -- Merge rpd.submissionEvents into apps.submissionEvents
        EXEC [apps].[sp_DynamicTableMerge]
            @sourceSchema = 'rpd',
            @sourceTableName = 'SubmissionEvents',
            @targetSchema = 'apps',
            @targetTableName = 'SubmissionEvents',
            @matchColumns = 'created,id,load_ts'
    
        -- If no errors occur, execute the next set of procedures
        BEGIN TRY
            EXEC [apps].[sp_AggregateAndMergePomData]
            --- EXEC [apps].[sp_AggregateAndMergeRegistrationData]    
        END TRY
        BEGIN CATCH
            PRINT 'Error occurred in the submissions to summaries merge'
        END CATCH
    
    END TRY
    BEGIN CATCH
        PRINT 'Error occurred in the rpd to apps merge'
    END CATCH

END;
GO