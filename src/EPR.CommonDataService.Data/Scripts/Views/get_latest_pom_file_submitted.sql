SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP VIEW IF EXISTS [apps].[get_latest_pom_file_submitted]
GO

CREATE VIEW [apps].[get_latest_pom_file_submitted] AS with PomFiles_CTE as
(
    SELECT
        [OrganisationId]
        ,[SubmissionId]
        ,[FileId]
        ,[BlobName]
        ,[FileType]
        ,[created]
        ,[SubmissionPeriod]
        ,[SubmissionType]
        ,[FileName]
        ,ComplianceSchemeId
        ,ROW_NUMBER() OVER(
            PARTITION BY OrganisationId
            ORDER BY [OrganisationId] , Cast(Created as DATETIME2) DESC
        ) as RowNum
    FROM [dbo].[v_cosmos_file_metadata]
    where FileType = 'Pom'
)
, LatestPomFiles_CTE as
    (select * from PomFiles_CTE where RowNum = 1)

select * from LatestPomFiles_CTE;
GO
