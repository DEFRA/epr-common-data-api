IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_R9]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_R9];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_R9] @SubmissionId [nvarchar](36) AS
BEGIN
SET NOCOUNT ON;
--DECLARE @SubmissionId nvarchar(50);

--set @SubmissionId = '8942bebb-34f2-494b-8f94-03a0f36e0a92';

DECLARE @OrganisationIDForSubmission INT;
DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
DECLARE @SubmissionPeriod nvarchar(100);
DECLARE @CSOReferenceNumber nvarchar(100);
DECLARE @ComplianceSchemeId nvarchar(50);
DECLARE @ApplicationReferenceNumber nvarchar(4000);
DECLARE @IsComplianceScheme bit;

    SELECT
        @OrganisationIDForSubmission = O.Id 
		,@OrganisationUUIDForSubmission = O.ExternalId 
		,@CSOReferenceNumber = O.ReferenceNumber 
		,@IsComplianceScheme = O.IsComplianceScheme
		,@ComplianceSchemeId = S.ComplianceSchemeId
		,@SubmissionPeriod = S.SubmissionPeriod
	    ,@ApplicationReferenceNumber = S.AppReferenceNumber
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;

    DECLARE @ProdCommentsSQL NVARCHAR(MAX);

	SET @ProdCommentsSQL = N'
		select *, ROW_NUMBER() OVER(
					  ORDER BY orderedsubevents.DecisionDate DESC
				  ) as OrderedRowNum
		INTO #ProdCommentsRegulatorDecisions
		from  (
			select subevents.*
			from (
				SELECT
					decisions.SubmissionId,
					decisions.SubmissionEventId AS SubmissionEventId,
					decisions.Created AS DecisionDate,
					decisions.Comments AS Comment,
					decisions.UserId,
					decisions.Type,
					decisions.FileId,
					CASE WHEN decisions.Type = ''RegulatorRegistrationDecision'' THEN
						CASE
							WHEN LTRIM(RTRIM(decisions.Decision)) = ''Accepted'' THEN ''Granted''
							WHEN LTRIM(RTRIM(decisions.Decision)) = ''Rejected'' THEN ''Refused''
							WHEN decisions.Decision IS NULL THEN ''Pending''
							ELSE decisions.Decision
						END
						ELSE NULL
					END AS SubmissionStatus
					,CASE 
						WHEN decisions.Type = ''RegistrationApplicationSubmitted'' THEN 1 ELSE 0
					END AS IsProducerComment
	';

	IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'RegistrationReferenceNumber' AND [object_id] = OBJECT_ID('rpd.SubmissionEvents')
	)
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        ,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
		')
	END
	ELSE
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        ,NULL AS RegistrationReferenceNumber
		');
	END;

	IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'DecisionDate' AND [object_id] = OBJECT_ID('rpd.SubmissionEvents')
	)
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'        ,decisions.DecisionDate AS StatusPendingDate
		');
	END
	ELSE
	BEGIN
		SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'    ,NULL AS StatusPendingDate
		');
	END;

	SET @ProdCommentsSQL = CONCAT(@ProdCommentsSQL, N'
					,ROW_NUMBER() OVER (
						PARTITION BY decisions.SubmissionId, decisions.Type, decisions.FileId
						ORDER BY decisions.Created DESC
					) AS RowNum
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN (''RegistrationApplicationSubmitted'', ''RegulatorRegistrationDecision'')	
	            AND decisions.SubmissionId = @SubId
			) as subevents
			--where RowNum = 1
		) as orderedsubevents
	');

	IF OBJECT_ID('tempdb..#ProdCommentsRegulatorDecisions') IS NOT NULL
	DROP TABLE #ProdCommentsRegulatorDecisions;
--print @ProdCommentsSQL
	EXEC sp_executesql @ProdCommentsSQL, N'@SubId nvarchar(50)', @SubId = @SubmissionId;
	--select * from #ProdCommentsRegulatorDecisions

    WITH
		ProdCommentsRegulatorDecisionsCTE as (
			SELECT
				decisions.SubmissionId
				,decisions.SubmissionEventId
				,decisions.DecisionDate
				,decisions.Comment
				,decisions.UserId
				,decisions.RegistrationReferenceNumber
				,decisions.SubmissionStatus
				,decisions.StatusPendingDate
				,IsProducerComment
				,[Type]
				,FileId
				,RowNum
				,OrderedRowNum
			FROM
				#ProdCommentsRegulatorDecisions as decisions
			WHERE decisions.SubmissionId = @SubmissionId
		)
--select * from ProdCommentsRegulatorDecisionsCTE
		,SubmittedCTE as (
			SELECT *
			FROM (
				SELECT SubmissionId, 
					   SubmissionEventId as SubmissionEventId, 
					   Comment as SubmissionComment, 
					   NULL as FileId, 
					   UserId as SubmittedUserId, 
					   DecisionDate as SubmissionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE granteddecision
				WHERE IsProducerComment = 1 and FileId IS NULL
			) as submittedevents WHERE RowNum = 1
		)
--select * from SubmittedCTE
		,ProducerReSubmissionCTE as (
			SELECT * from (
				SELECT SubmissionId, 
					   SubmissionEventId ResubmissionEventId, 
					   FileId, 
					   Comment as ResubmissionComment, 
					   DecisionDate as ResubmissionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE
				where IsProducerComment = 1 AND FileId IS NOT NULL
			) as resubmissions
			where RowNum = 1
			AND NOT EXISTS (
				  SELECT 1 
				  FROM SubmittedCTE s 
				  WHERE s.SubmissionEventId = resubmissions.ResubmissionEventId
			  )
		)
--select * from ProducerReSubmissionCTE 
		,RegistrationDecisionCTE as (
			SELECT TOP 1 *
			FROM (
				SELECT SubmissionId, 
					   SubmissionEventId as RegistrationEventId, 
					   Userid, 
					   RegistrationReferenceNumber,
					   SubmissionStatus,
					   Comment as RegistrationComment, 
					   DecisionDate as RegistrationDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE granteddecision
				WHERE IsProducerComment = 0 AND SubmissionStatus = 'Granted' AND RegistrationReferenceNumber IS NOT NULL
			) as grantedevents WHERE RowNum = 1
		)
--select * from  RegistrationDecisionCTE 
		,ResubmissionRegulatorDecisionCTE as (
			SELECT * FROM (
				SELECT SubmissionId, 
					   SubmissionEventId as ResubmissionEventId, 
					   UserId, 
					   SubmissionStatus as ResubmissionStatus, 
					   Comment as ResubmissionComment, 
					   DecisionDate as ResubmissionDecisionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE
				where IsProducerComment = 0
			) as resubmissions
			WHERE RowNum = 1
			AND NOT EXISTS (
				  SELECT 1 
				  FROM RegistrationDecisionCTE r 
				  WHERE r.RegistrationEventId = resubmissions.ResubmissionEventId
			)
			AND EXISTS (
				SELECT 1
				FROM ProducerReSubmissionCTE prs
			)
		)
--select * from ResubmissionRegulatorDecisionCTE
		,RegulatorDecisionsCTE as (
			SELECT *
			FROM (
				SELECT SubmissionId, SubmissionEventId, Userid, 
						RegistrationReferenceNumber,
						SubmissionStatus,
						Comment as RegulatorComment, 
						DecisionDate as RegulatorDecisionDate,
						StatusPendingDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE granteddecision
				WHERE IsProducerComment = 0 AND SubmissionStatus <> 'Granted'
			) as regulatorevents 
			--WHERE RowNum = 1
		)
--select * from RegulatorDecisionsCTE
		,MostRecentRegulatorDecisionCTE as (
			select * from RegulatorDecisionsCTE
			WHERE RowNum = 1
			AND NOT EXISTS (
				  SELECT 1 
				  FROM RegistrationDecisionCTE r 
				  WHERE r.RegistrationEventId = RegulatorDecisionsCTE.SubmissionEventId
			)
		)
--select * from MostRecentRegulatorDecisionCTE
		,UploadedViewCTE as (
			select * FROM
				[dbo].[v_UploadedRegistrationDataBySubmissionPeriod] org 
			WHERE org.SubmittingExternalId = @OrganisationUUIDForSubmission
				and org.SubmissionPeriod = @SubmissionPeriod
				and org.SubmissionId = @SubmissionId )
--select * from UploadedViewCTE
		,UploadedDataCTE as (
			select *
			from dbo.fn_GetUploadedOrganisationDetails(@OrganisationUUIDForSubmission, @SubmissionPeriod)
			--where SubmissionId = @SubmissionId
		)
--select * from UploadedDataCTE
		,ProducerPaycalParametersCTE
			AS
			(
				SELECT
				ExternalId
				,FileName
				,ProducerSize
				,IsOnlineMarketplace
				,NumberOfSubsidiaries
				,NumberOfSubsidiariesBeingOnlineMarketPlace
				FROM
					[dbo].[v_ProducerPaycalParameters] AS ppp
				inner join UploadedDataCTE udc on udc.CompanyFileName = ppp.FileName
			WHERE ppp.ExternalId = @OrganisationUUIDForSubmission
		)
--select * from ProducerPaycalParametersCTE
		,SubmissionDetails AS (
		    select a.* FROM (
				SELECT
					s.SubmissionId
					,o.Name AS OrganisationName
					,org.UploadOrgName as UploadedOrganisationName
					,o.ReferenceNumber as OrganisationReferenceNumber
					,org.SubmittingExternalId as OrganisationId
					,SubmittedCTE.SubmissionDate as SubmittedDateTime
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,registrationdecision.RegistrationReferenceNumber
					,registrationdecision.RegistrationDate
					,registrationdecision.RegistrationEventId
            		,resubmission.ResubmissionDate
					,CASE WHEN regulatordecisions.RegulatorDecisionDate > registrationdecision.RegistrationDate 
						  THEN CASE WHEN RegulatorDecisions.SubmissionStatus IS NULL Then 'Pending'
									ELSE RegulatorDecisions.SubmissionStatus 
								END
						  ELSE
							   CASE when registrationdecision.RegistrationDate IS NOT NULL THEN 'Granted'
							   ELSE CASE WHEN RegulatorDecisions.SubmissionStatus IS NULL Then 'Pending'
									ELSE RegulatorDecisions.SubmissionStatus 
									END
							   END
					 END as SubmissionStatus
					,CASE WHEN resubmission.ResubmissionDate IS NOT NULL THEN
							CASE WHEN regulatorresubmissiondecision.ResubmissionDecisionDate > resubmission.ResubmissionDate 
								THEN CASE WHEN regulatorresubmissiondecision.ResubmissionStatus = 'Granted' THEN 'Accepted'
										  WHEN regulatorresubmissiondecision.ResubmissionStatus = 'Refused' THEN 'Rejected'
									 END
							ELSE 'Pending' END
					      ELSE NULL
					 END as ResubmissionStatus
					,CASE WHEN resubmission.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
					 END as IsResubmission
					,CASE 
						WHEN cs.NationId IS NOT NULL THEN cs.NationId
						ELSE
						CASE UPPER(org.NationCode)
							WHEN 'EN' THEN 1
							WHEN 'NI' THEN 2
							WHEN 'SC' THEN 3
							WHEN 'WS' THEN 4
							WHEN 'WA' THEN 4
						 END
					 END AS NationId
					,CASE
						WHEN cs.NationId IS NOT NULL THEN
							CASE cs.NationId
								WHEN 1 THEN 'GB-ENG'
								WHEN 2 THEN 'GB-NIR'
								WHEN 3 THEN 'GB-SCT'
								WHEN 4 THEN 'GB-WLS'
							END
						ELSE
						CASE UPPER(org.NationCode)
							WHEN 'EN' THEN 'GB-ENG'
							WHEN 'NI' THEN 'GB-NIR'
							WHEN 'SC' THEN 'GB-SCT'
							WHEN 'WS' THEN 'GB-WLS'
							WHEN 'WA' THEN 'GB-WLS'
						END
					 END AS NationCode
					,ISNULL(regulatorresubmissiondecision.UserId,  ISNULL(registrationdecision.UserId, regulatordecisions.UserId)) 
						as RegulatorUserId
					,resubmission.ResubmissionEventId as ResubmissionEventId
					,GREATEST(RegistrationDate,GREATEST(ResubmissionDecisionDate, RegulatorDecisionDate))
						as RegulatorDecisionDate
					,CASE WHEN regulatordecisions.SubmissionStatus = 'Cancelled' 
						  THEN regulatordecisions.StatusPendingDate
						  ELSE null
					 END as StatusPendingDate
					,ISNULL(registrationdecision.RegistrationComment, ISNULL(regulatorresubmissiondecision.ResubmissionComment, regulatordecisions.RegulatorComment)) 
						as RegulatorComment
					,ISNULL(resubmission.ResubmissionComment, SubmittedCTE.SubmissionComment) 
						as ProducerComment
					,s.SubmissionPeriod
					,CAST(
						SUBSTRING(
							s.SubmissionPeriod,
							PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
							4
						) AS INT
					) AS RelevantYear
					,CAST(
						CASE
							WHEN SubmittedCTE.SubmissionDate > DATEFROMPARTS(CONVERT( int, SUBSTRING(
											s.SubmissionPeriod,
											PATINDEX('%[0-9][0-9][0-9][0-9]', s.SubmissionPeriod),
											4
										)),4,1) THEN 1
							ELSE 0
						END AS BIT
					) AS IsLateSubmission
					,CASE UPPER(TRIM(org.organisationsize))
						WHEN 'S' THEN 'Small'
						WHEN 'L' THEN 'Large'
					 END as ProducerSize
					,o.IsComplianceScheme
					,CASE 
						WHEN o.IsComplianceScheme = 1 THEN 'Compliance'
						WHEN UPPER(TRIM(org.organisationsize)) = 'S' THEN 'Small'
						WHEN UPPER(TRIM(org.organisationsize)) = 'L' THEN 'Large'
					 END AS OrganisationType
					,CONVERT(bit, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace
					,ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
					,ISNULL(ppp.NumberOfSubsidiariesBeingOnlineMarketPlace,0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
					,org.CompanyFileId AS CompanyDetailsFileId
					,org.CompanyUploadFileName AS CompanyDetailsFileName
					,org.CompanyBlobName AS CompanyDetailsBlobName
					,org.BrandFileId AS BrandsFileId
					,org.BrandUploadFileName AS BrandsFileName
					,org.BrandBlobName BrandsBlobName
					,org.PartnerUploadFileName AS PartnershipFileName
					,org.PartnerFileId AS PartnershipFileId
					,org.PartnerBlobName AS PartnershipBlobName
					,SubmittedCTE.SubmittedUserId
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId
								     ,s.SubmissionPeriod
									 ,s.ComplianceSchemeId
						ORDER BY s.load_ts DESC
					) AS RowNum
				FROM
					[rpd].[Submissions] AS s
						INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
						INNER JOIN UploadedViewCTE org on org.SubmissionId = s.SubmissionId
						INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
						LEFT JOIN MostRecentRegulatorDecisionCTE regulatordecisions on regulatordecisions.SubmissionId = s.SubmissionId
						LEFT JOIN RegistrationDecisionCTE as registrationdecision on registrationdecision.submissionid = s.SubmissionId
						LEFT JOIN ProducerReSubmissionCTE resubmission on resubmission.SubmissionId = s.SubmissionId
						LEFT JOIN ResubmissionRegulatorDecisionCTE regulatorresubmissiondecision on regulatorresubmissiondecision.SubmissionId = s.SubmissionId 
		                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.ExternalId = s.OrganisationId
						LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
	    		WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
		,ComplianceSchemeMembersCTE as (
			select *
			from dbo.v_ComplianceSchemeMembers csm
			where csm.CSOReference = @CSOReferenceNumber
				  and csm.SubmissionPeriod = @SubmissionPeriod
				  and csm.ComplianceSchemeId = @ComplianceSchemeId
		)
		,CompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
				,csm.ReferenceNumber
				,csm.RelevantYear
				,ppp.ProducerSize
				,csm.SubmittedDate
				,csm.IsLateFeeApplicable
				,ppp.IsOnlineMarketPlace
				,ppp.NumberOfSubsidiaries
				,ppp.NumberOfSubsidiariesBeingOnlineMarketPlace
				,csm.submissionperiod
				,@SubmissionPeriod AS WantedPeriod
            FROM
                dbo.v_ComplianceSchemeMembers csm
                INNER JOIN dbo.v_ProducerPayCalParameters ppp ON ppp.OrganisationReference = csm.ReferenceNumber
				  			AND ppp.FileName = csm.FileName
            WHERE @IsComplianceScheme = 1
                AND csm.CSOReference = @CSOReferenceNumber
                AND csm.SubmissionPeriod = @SubmissionPeriod
				AND csm.ComplianceSchemeId = @ComplianceSchemeId
        ) 
		,JsonifiedCompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
            ,ReferenceNumber
            ,'{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' + '"MemberType": "' + ProducerSize + '", ' + '"IsOnlineMarketPlace": ' + CASE
            WHEN IsOnlineMarketPlace = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(6)) + ', ' + '"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(
            NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(6)
        ) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS nvarchar(16)) + '", ' + '"IsLateFeeApplicable": ' + CASE
            WHEN IsLateFeeApplicable = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"SubmissionPeriodDescription": "' + submissionperiod + '"}' AS OrganisationDetailsJsonString
            FROM
                CompliancePaycalCTE
        )
    ,AllCompliancePaycalParametersAsJSONCTE
        AS
        (
            SELECT
                CSOReference
            ,'[' + STRING_AGG(OrganisationDetailsJsonString, ', ') + ']' AS FinalJson
            FROM
                JsonifiedCompliancePaycalCTE
            WHERE CSOReference = @CSOReferenceNumber
            GROUP BY CSOReference
        )
	SELECT DISTINCT
        r.SubmissionId
        ,r.OrganisationId
        ,r.OrganisationName AS OrganisationName
        ,CONVERT(nvarchar(20), r.OrganisationReferenceNumber) AS OrganisationReference
        ,r.ApplicationReferenceNumber
        ,r.RegistrationReferenceNumber
        ,r.SubmissionStatus
        ,r.StatusPendingDate
        ,r.SubmittedDateTime
        ,r.IsLateSubmission
		,CONVERT(bit, r.IsResubmission) as IsResubmission
        ,r.ResubmissionStatus
		,r.RegistrationDate
		,r.ResubmissionDate
		,r.SubmissionPeriod
        ,r.RelevantYear
        ,r.IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
        ,r.RegulatorUserId
        ,o.CompaniesHouseNumber
        ,o.BuildingName
        ,o.SubBuildingName
        ,o.BuildingNumber
        ,o.Street
        ,o.Locality
        ,o.DependentLocality
        ,o.Town
        ,o.County
        ,o.Country
        ,o.Postcode
        ,r.SubmittedUserId
        ,p.FirstName
        ,p.LastName
        ,p.Email
        ,p.Telephone
        ,sr.Name AS ServiceRole
        ,sr.Id AS ServiceRoleId
        ,r.IsOnlineMarketplace
        ,r.NumberOfSubsidiaries
        ,r.NumberOfSubsidiariesBeingOnlineMarketPlace AS NumberOfOnlineSubsidiaries
        ,r.CompanyDetailsFileId
        ,r.CompanyDetailsFileName
        ,r.CompanyDetailsBlobName
        ,r.PartnershipFileId
        ,r.PartnershipFileName
        ,r.PartnershipBlobName
        ,r.BrandsFileId
        ,r.BrandsFileName
        ,r.BrandsBlobName
        ,acpp.FinalJson AS CSOJson
    FROM
        SubmissionDetails r
        INNER JOIN [rpd].[Organisations] o
			LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber 
			ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
END;
GO
