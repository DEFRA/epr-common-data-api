IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_GetAggregatedPomData]'))
BEGIN
	DROP PROCEDURE [rpd].[sp_GetAggregatedPomData]
END
GO

CREATE PROCEDURE [rpd].[sp_GetAggregatedPomData] (@SubmissionId UNIQUEIDENTIFIER)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @FileId NVARCHAR(4000);

	SET @FileId = (
		SELECT TOP 1 FileId
		FROM rpd.SubmissionEvents
		WHERE SubmissionId = @SubmissionId 
		AND FileId IS NOT NULL
		ORDER BY Created DESC
	)

	DECLARE @FileName NVARCHAR(4000);

	SELECT @FileName = [FileName]
	FROM rpd.cosmos_file_metadata
	WHERE FileId = @FileId
	
	SELECT 
		submission_period,
		packaging_material,
		SUM(packaging_material_weight) AS packaging_material_weight
	FROM rpd.Pom
	WHERE [FileName] = @FileName
	GROUP BY 
		p.submission_period,
		p.packaging_material
END
GO