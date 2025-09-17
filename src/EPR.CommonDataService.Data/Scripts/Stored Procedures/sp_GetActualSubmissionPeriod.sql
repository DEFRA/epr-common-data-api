IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_GetActualSubmissionPeriod]'))
    DROP PROCEDURE [apps].[sp_GetActualSubmissionPeriod];
GO

CREATE PROCEDURE [apps].[sp_GetActualSubmissionPeriod]
    @SubmissionId       NVARCHAR(50),
    @SubmissionPeriod   NVARCHAR(50)
AS
BEGIN
	SELECT TOP 10 ActualSubmissionPeriod 
	FROM apps.SubmissionsSummaries 
	WHERE SubmissionId=@SubmissionId AND SubmissionPeriod=@SubmissionPeriod
END