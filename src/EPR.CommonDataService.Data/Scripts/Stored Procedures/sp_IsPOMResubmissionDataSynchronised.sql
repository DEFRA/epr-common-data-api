IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_IsPOMResubmissionDataSynchronised]'))
    DROP PROCEDURE [dbo].[sp_IsPOMResubmissionDataSynchronised];
GO

CREATE PROCEDURE [dbo].[sp_IsPOMResubmissionDataSynchronised]
    @FileId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @SubmissionId NVARCHAR(50),
        @FileName NVARCHAR(255),
        @Reference NVARCHAR(255) = NULL;

    -- Retrieve SubmissionId and FileName
    SELECT 
        @SubmissionId = SubmissionId, 
        @FileName = FileName
    FROM rpd.cosmos_file_metadata 
    WHERE FileId = @FileId;

    -- Exit with false if no SubmissionId found
    IF @SubmissionId IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS IsSynced;
    END
    ELSE IF EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'apps'
          AND TABLE_NAME = 'SubmissionEvents'
          AND COLUMN_NAME = 'PackagingResubmissionReferenceNumber'
    )
    BEGIN
        DECLARE @sql NVARCHAR(MAX);

        SET @sql = N'
            SELECT TOP 1 @Reference = PackagingResubmissionReferenceNumber
            FROM apps.SubmissionEvents
            WHERE [Type] = ''PackagingResubmissionReferenceNumberCreated''
              AND SubmissionId = @SubmissionId
            ORDER BY Created DESC;
        ';

        EXEC sp_executesql 
            @sql,
            N'@SubmissionId NVARCHAR(50), @Reference NVARCHAR(255) OUTPUT',
            @SubmissionId = @SubmissionId,
            @Reference = @Reference OUTPUT;

        SELECT 
            CAST(
                CASE 
                    WHEN @Reference IS NOT NULL AND LEN(@Reference) > 0 THEN 1 
                    ELSE 0 
                END AS BIT
            ) AS IsSynced;
    END
    ELSE
    BEGIN
        -- Column doesn't exist; treat as not synced
        SELECT CAST(0 AS BIT) AS IsSynced;
    END
END

