-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_MergeSubmissionsSummaries]'))
DROP PROCEDURE [apps].[sp_MergeSubmissionsSummaries];
GO

CREATE PROCEDURE apps.sp_MergeSubmissionsSummaries
    AS
BEGIN

IF OBJECT_ID('tempdb..#SubmissionsSummariesTemp') IS NOT NULL
DROP TABLE #SubmissionsSummariesTemp;
	

-- Create temp table
CREATE TABLE #SubmissionsSummariesTemp
(
    [SubmissionId] NVARCHAR(4000),
    [OrganisationId] NVARCHAR(4000),
    [ComplianceSchemeId] NVARCHAR(4000),
    [OrganisationName] NVARCHAR(4000),
    [OrganisationReference] NVARCHAR(4000),
    [OrganisationType] NVARCHAR(4000),
    [ProducerType] NVARCHAR(4000),
    [UserId] NVARCHAR(4000),
    [FirstName] NVARCHAR(4000),
    [LastName] NVARCHAR(4000),
    [Email] NVARCHAR(4000),
    [Telephone] NVARCHAR(4000),
    [ServiceRole] NVARCHAR(4000),
    [FileId] NVARCHAR(4000),
    [SubmissionPeriod] NVARCHAR(4000),
    [SubmittedDate] NVARCHAR(4000),
    [Decision] NVARCHAR(4000),
    [IsResubmissionRequired] BIT,
    [Comments] NVARCHAR(4000),
    [IsResubmission] BIT,
    [PreviousRejectionComments] NVARCHAR(4000),
    [NationId] INT
	);

INSERT INTO #SubmissionsSummariesTemp
SELECT
    [SubmissionId],
    [OrganisationId],
    [ComplianceSchemeId],
    [OrganisationName],
    [OrganisationReference],
    [OrganisationType],
    [ProducerType],
    [UserId],
    [FirstName],
    [LastName],
    [Email],
    [Telephone],
    [ServiceRole],
    [FileId],
    [SubmissionPeriod],
    [SubmittedDate],
    [Decision],
    [IsResubmissionRequired],
    [Comments],
    [IsResubmission],
    [PreviousRejectionComments],
    [NationId]
FROM apps.v_SubmissionsSummaries;

MERGE INTO apps.SubmissionsSummaries AS Target
    USING #SubmissionsSummariesTemp AS Source
    ON Target.FileId = Source.FileId
    WHEN MATCHED THEN
        UPDATE SET
            Target.SubmissionId = Source.SubmissionId,
            Target.OrganisationId = Source.OrganisationId,
            Target.ComplianceSchemeId = Source.ComplianceSchemeId,
            Target.OrganisationName = Source.OrganisationName,
            Target.OrganisationReference = Source.OrganisationReference,
            Target.OrganisationType = Source.OrganisationType,
            Target.ProducerType = Source.ProducerType,
            Target.UserId = Source.UserId,
            Target.FirstName = Source.FirstName,
            Target.LastName = Source.LastName,
            Target.Email = Source.Email,
            Target.Telephone = Source.Telephone,
            Target.ServiceRole = Source.ServiceRole,
            Target.FileId = Source.FileId,
            Target.SubmissionPeriod = Source.SubmissionPeriod,
            Target.SubmittedDate = Source.SubmittedDate,
            Target.Decision = Source.Decision,
            Target.IsResubmissionRequired = Source.IsResubmissionRequired,
            Target.Comments = Source.Comments,
            Target.IsResubmission = Source.IsResubmission,
            Target.PreviousRejectionComments = Source.PreviousRejectionComments,
            Target.NationId = Source.NationId
    WHEN NOT MATCHED BY TARGET THEN
    INSERT (
    SubmissionId,
    OrganisationId,
    ComplianceSchemeId,
    OrganisationName,
    OrganisationReference,
    OrganisationType,
    ProducerType,
    UserId,
    FirstName,
    LastName,
    Email,
    Telephone,
    ServiceRole,
    FileId,
    SubmissionPeriod,
    SubmittedDate,
    Decision,
    IsResubmissionRequired,
    Comments,
    IsResubmission,
    PreviousRejectionComments,
    NationId
    )
    VALUES (
    Source.Submissionid,
    Source.OrganisationId,
    Source.ComplianceSchemeId,
    Source.OrganisationName,
    Source.OrganisationReference,
    Source.OrganisationType,
    Source.ProducerType,
    Source.UserId,
    Source.FirstName,
    Source.LastName,
    Source.Email,
    Source.Telephone,
    Source.ServiceRole,
    Source.FileId,
    Source.SubmissionPeriod,
    Source.SubmittedDate,
    Source.Decision,
    Source.IsResubmissionRequired,
    Source.Comments,
    Source.IsResubmission,
    Source.PreviousRejectionComments,
    Source.NationId
    )
    WHEN NOT MATCHED BY SOURCE THEN
        DELETE; -- delete from table when no longer in source

DROP TABLE #SubmissionsSummariesTemp;

END;
GO