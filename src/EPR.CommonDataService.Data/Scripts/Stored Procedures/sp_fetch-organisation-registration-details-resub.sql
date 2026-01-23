IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub] @SubmissionId [nvarchar](36) AS

BEGIN
	SET NOCOUNT ON;

	select o.*,
	       s.RegistrationJourney
	from dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub o
    join apps.Submissions s on s.SubmissionId = o.SubmissionId
    where o.SubmissionId = @SubmissionId;

END;
GO