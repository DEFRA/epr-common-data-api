/****** Object:  StoredProcedure [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub]    Script Date: 24/04/2025 10:26:16 ******/
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_resub] @SubmissionId [nvarchar](36) AS

BEGIN
	SET NOCOUNT ON;

	select * from dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub where SubmissionId = @SubmissionId;
END;
GO