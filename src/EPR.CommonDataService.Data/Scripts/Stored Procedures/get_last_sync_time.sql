IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[GetLastSyncTime]'))
DROP PROCEDURE [dbo].[GetLastSyncTime];
GO

create procedure [dbo].[GetLastSyncTime]
AS
BEGIN
    SELECT MAX(load_ts) as LastSyncTime
    from apps.SubmissionEvents
END

