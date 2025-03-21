IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_CheckForCosmosData]'))
    DROP PROCEDURE [dbo].[sp_CheckForCosmosData];
GO

CREATE PROC [dbo].[sp_CheckForCosmosData] @SubmissionId [nvarchar](50),@FileId [nvarchar](50) AS
begin
	DECLARE @IsSynced BIT = 0; -- Default value

	IF @SubmissionId IS NOT NULL
	BEGIN
		SELECT @IsSynced = CAST(CASE WHEN EXISTS (
			SELECT 1 FROM rpd.cosmos_file_metadata 
			WHERE SubmissionId = @SubmissionId
		) THEN 1 ELSE 0 END AS BIT);
	END
	ELSE IF @FileId IS NOT NULL
	BEGIN
		SELECT @IsSynced = CAST(CASE WHEN EXISTS (
			SELECT 1 FROM rpd.cosmos_file_metadata 
			WHERE FileId = @FileId
		) THEN 1 ELSE 0 END AS BIT);
	END

	-- Return the result
	SELECT @IsSynced AS IsSynced;
end
GO

