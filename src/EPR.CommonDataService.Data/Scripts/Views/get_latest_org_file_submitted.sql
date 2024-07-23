SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP VIEW IF EXISTS [apps].[get_latest_org_file_submitted]
GO

CREATE VIEW [apps].[get_latest_org_file_submitted] AS
    WITH OrgFiles_CTE AS (
        SELECT
            [OrganisationId],
            [SubmissionId],
            [FileId],
            [BlobName],
            [FileType],
            [created],
            [SubmissionPeriod],
            [SubmissionType],
            [FileName],
            [ComplianceSchemeId],
            ROW_NUMBER() OVER (
                PARTITION BY [OrganisationId]
                ORDER BY CAST([created] AS DATETIME2) DESC
            ) AS RowNum
        FROM [dbo].[v_cosmos_file_metadata]
        WHERE [FileType] = 'CompanyDetails'
    )
    SELECT
        [OrganisationId],
        [SubmissionId],
        [FileId],
        [BlobName],
        [FileType],
        [created],
        [SubmissionPeriod],
        [SubmissionType],
        [FileName],
        [ComplianceSchemeId]
    FROM OrgFiles_CTE
    WHERE [RowNum] = 1;
    GO
