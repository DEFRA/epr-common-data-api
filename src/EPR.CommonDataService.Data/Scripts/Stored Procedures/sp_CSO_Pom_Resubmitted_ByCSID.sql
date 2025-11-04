IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_CSO_Pom_Resubmitted_ByCSID]'))
DROP PROCEDURE [dbo].[sp_CSO_Pom_Resubmitted_ByCSID];
GO

CREATE PROC [dbo].[sp_CSO_Pom_Resubmitted_ByCSID] @CSOrganisation_ID [INT],@ComplianceSchemeId [nvarchar](40),@SubmissionPeriod [Varchar](100),@MemberCount [INT] OUT AS
BEGIN
SET NOCOUNT ON;

select @MemberCount=MemberCount from [dbo].[t_CSO_Pom_Resubmitted_ByCSID] where 
CS_Reference_number= @CSOrganisation_ID and CSid=@ComplianceSchemeId and submissionperiod=@SubmissionPeriod;

END;
GO
