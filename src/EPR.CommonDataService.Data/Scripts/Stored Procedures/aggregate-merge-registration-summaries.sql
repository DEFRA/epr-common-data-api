IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_MergeRegistrationsSummaries]'))
DROP PROCEDURE [apps].[sp_MergeRegistrationsSummaries];
GO

CREATE PROC [apps].[sp_MergeRegistrationsSummaries] AS
BEGIN
    exec [apps].[sp_AggregateAndMergeOrgRegSummaries]
END;
