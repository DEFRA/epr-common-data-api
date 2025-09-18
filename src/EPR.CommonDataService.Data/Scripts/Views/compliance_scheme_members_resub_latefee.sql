IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[v_ComplianceSchemeMembers_resub_latefee]')
) DROP VIEW [dbo].[v_ComplianceSchemeMembers_resub_latefee];
GO


	--InsertViewHere
GO
