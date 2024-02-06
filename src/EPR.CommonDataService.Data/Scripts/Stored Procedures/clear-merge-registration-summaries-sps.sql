-- deprecated sps that needs to exist but be empty as part of release 2.9 as we cannot remove from pipeline at present
-- should be addressed and cleaned up/removed once it is no longer run on an hourly schedule in a synapse pipeline

-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_MergeRegistrationsSummaries]'))
DROP PROCEDURE [apps].[sp_MergeRegistrationsSummaries];
GO

CREATE PROCEDURE apps.sp_MergeRegistrationsSummaries
    AS
BEGIN
    PRINT 'Skipped'
END;
GO