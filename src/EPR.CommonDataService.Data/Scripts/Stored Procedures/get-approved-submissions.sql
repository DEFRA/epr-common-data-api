IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetApprovedSubmissions]'))
BEGIN
	DROP PROCEDURE [rpd].[sp_GetApprovedSubmissions]
END
GO

CREATE PROCEDURE sp_GetApprovedSubmissions (@ApprovedAfter DATETIME2)
AS
BEGIN
	SELECT [SubmissionId]
	FROM [rpd].[SubmissionEvents]
	WHERE TRY_CAST([Created] AS datetime2) > @ApprovedAfter
	AND RegulatorDecision = 'Accepted'
END
GO