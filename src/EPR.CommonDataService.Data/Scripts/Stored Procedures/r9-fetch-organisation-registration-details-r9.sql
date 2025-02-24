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
					CASE
						WHEN LTRIM(RTRIM(decisions.Decision)) = ''Accepted'' THEN ''Granted''
						WHEN LTRIM(RTRIM(decisions.Decision)) = ''Rejected'' THEN ''Refused''
						WHEN decisions.Decision IS NULL THEN ''Pending''
						ELSE decisions.Decision
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
						PARTITION BY decisions.SubmissionId, decisions.SubmissionEventId, decisions.Type
						ORDER BY decisions.Created DESC
					) AS RowNum
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN (''RegistrationApplicationSubmitted'', ''RegulatorRegistrationDecision'')	
	            AND decisions.SubmissionId = @SubId
			) as subevents
			where RowNum = 1
		) as orderedsubevents
	');

	IF OBJECT_ID('tempdb..#ProdCommentsRegulatorDecisions') IS NOT NULL
	DROP TABLE #ProdCommentsRegulatorDecisions;

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
				,RowNum
				,OrderedRowNum
			FROM
				#ProdCommentsRegulatorDecisions as decisions
			WHERE decisions.SubmissionId = @SubmissionId
		)
--select * from ProdCommentsRegulatorDecisionsCTE
		,RegistrationDecisionCTE as (
			SELECT *
			FROM (
				SELECT SubmissionId, SubmissionEventId, Userid, RegistrationReferenceNumber, DecisionDate as RegistrationDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE granteddecision
				WHERE IsProducerComment = 0 AND SubmissionStatus = 'Granted' AND RegistrationReferenceNumber IS NOT NULL
			) as grantedevents WHERE RowNum = 1
		)
		,SubmittedCTE as (
			SELECT *
			FROM (
				SELECT SubmissionId, SubmissionEventId, Comment, UserId as SubmittedUserId, DecisionDate as SubmissionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate ASC) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE granteddecision
				WHERE IsProducerComment = 1
			) as submittedevents WHERE RowNum = 1
		)
		,ResubmissionRegulatorDecisionCTE as (
			SELECT * FROM (
				SELECT SubmissionId, SubmissionEventId, UserId, SubmissionStatus, StatusPendingDate, DecisionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE
				where IsProducerComment = 0
			) as resubmissions
			WHERE RowNum = 1
		)
		,ProducerReSubmissionCTE as (
			SELECT * from (
				SELECT SubmissionId, SubmissionEventId, Comment, DecisionDate
					   ,ROW_NUMBER() OVER ( PARTITION BY SubmissionId ORDER BY DecisionDate DESC ) as RowNum
				FROM ProdCommentsRegulatorDecisionsCTE
				where IsProducerComment = 1
			) as resubmissions
			where RowNum = 1
		)
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
					,o.ReferenceNumber
					,org.SubmittingExternalId as OrganisationId
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,registrationdecision.RegistrationReferenceNumber
					,registrationdecision.RegistrationDate
            		,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
							AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
							resubmission.DecisionDate END as ResubmissionDate
					,SubmittedCTE.SubmissionDate as SubmittedDateTime
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
					,registrationdecision.UserId as RegulatorUserId
					,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
							AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
							CASE WHEN regulatorresubmissiondecision.DecisionDate IS NULL THEN 1
								 WHEN regulatorresubmissiondecision.DecisionDate > resubmission.DecisionDate AND regulatorresubmissiondecision.SubmissionStatus = 'Granted' 
								 THEN 0
								 ELSE 1 END
						  ELSE 0
					 END as IsResubmission
					,CASE when registrationdecision.RegistrationDate IS NOT NULL THEN 'Granted'
						  else CASE WHEN regulatorresubmissiondecision.SubmissionStatus IS NULL Then 'Pending'
							   ELSE regulatorresubmissiondecision.SubmissionStatus END
					 END as SubmissionStatus
					,CASE WHEN resubmission.DecisionDate IS NOT NULL AND registrationdecision.RegistrationDate IS NOT NULL 
							AND resubmission.DecisionDate > registrationdecision.RegistrationDate THEN
							CASE WHEN regulatorresubmissiondecision.DecisionDate > resubmission.DecisionDate THEN regulatorresubmissiondecision.SubmissionStatus
								 ELSE 'Pending' END
						  ELSE NULL
					 END as ResubmissionStatus
					,resubmission.SubmissionEventId as ResubmissionEventId
					,regulatorresubmissiondecision.DecisionDate as RegulatorDecisionDate
					,regulatorresubmissiondecision.StatusPendingDate
					,ISNULL(resubmission.Comment, SubmittedCTE.Comment) 
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
						INNER JOIN [dbo].[v_UploadedRegistrationDataBySubmissionPeriod] org 
							ON org.SubmittingExternalId = s.OrganisationId 
							and org.SubmissionPeriod = s.SubmissionPeriod
							and org.SubmissionId = s.SubmissionId
						INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
						INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
						LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
						LEFT JOIN RegistrationDecisionCTE as registrationdecision on registrationdecision.submissionid = s.SubmissionId
						LEFT JOIN ProducerReSubmissionCTE resubmission on resubmission.SubmissionId = s.SubmissionId
						LEFT JOIN ResubmissionRegulatorDecisionCTE regulatorresubmissiondecision on regulatorresubmissiondecision.SubmissionId = s.SubmissionId 
		                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.ExternalId = s.OrganisationId
					--INNER JOIN ProducerSubmissionCTE se on se.SubmissionId = s.SubmissionId
					--INNER JOIN UploadedDataCTE org ON org.SubmittingExternalId = s.OrganisationId and org.submissionid = @SubmissionId
					--INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
					--LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
					--LEFT JOIN GrantedDecisionsCTE granteddecision on granteddecision.SubmissionId = s.SubmissionId 
	    		WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
--select * from SubmissionDetails
		,LatestRelatedRegulatorDecisionsCTE AS
		(
			select a.SubmissionId
				,a.SubmissionEventId as DecisionEventId
				,a.DecisionDate as RegulatorDecisionDate
				,a.UserId as RegulatorUserId
				,a.Comment as RegulatorComment
				,a.RegistrationReferenceNumber
				,a.SubmissionStatus
				,a.StatusPendingDate
			from ProdCommentsRegulatorDecisionsCTE as a
			where a.IsProducerComment = 0 and a.RowNum = 1
		)
--select * from LatestRelatedRegulatorDecisionsCTE
	   ,LatestProducerCommentEventsCTE
        AS
        (
            SELECT DISTINCT
				comment.SubmissionId
				,comment.SubmissionEventId as DecisionEventId
				,Comment AS ProducerComment
				,DecisionDate AS ProducerCommentDate
            FROM
                ProdCommentsRegulatorDecisionsCTE AS comment
			WHERE comment.IsProducerComment = 1 and comment.RowNum = 1
        )
--select * from LatestProducerCommentEventsCTE
		,SubmissionOrganisationCommentsDetailsCTE
        AS
        (
            SELECT DISTINCT 
             submission.SubmissionId
            ,submission.OrganisationId
            ,submission.OrganisationName
            ,submission.ReferenceNumber as OrganisationReferenceNumber
            ,submission.IsComplianceScheme
            ,submission.ProducerSize
            ,submission.OrganisationType
            ,submission.RelevantYear
            ,submission.RegistrationDate
			,submission.ResubmissionDate
			,submission.SubmittedDateTime
            ,submission.IsLateSubmission
            ,submission.SubmissionPeriod
			,CASE WHEN submission.IsResubmission = 1
						THEN 'Granted' 
						ELSE ISNULL(submission.SubmissionStatus,'Pending')
  			 END as SubmissionStatus
            ,submission.ResubmissionStatus
			,decision.StatusPendingDate
			,submission.ApplicationReferenceNumber
            ,submission.RegistrationReferenceNumber
            ,submission.NationId
            ,submission.NationCode
            ,submission.SubmittedUserId
            ,ISNULL(submission.RegulatorDecisionDate, decision.RegulatorDecisionDate) as RegulatorDecisionDate
            ,decision.RegulatorComment
            ,producer.ProducerComment
            ,producer.ProducerCommentDate
            ,submission.IsOnlineMarketplace
            ,submission.NumberOfSubsidiaries
            ,submission.NumberOfSubsidiariesBeingOnlineMarketPlace
            ,decision.DecisionEventId as RegulatorSubmissionEventId
            ,ISNULL(submission.RegulatorUserId, decision.RegulatorUserId) as RegulatorUserId
            ,producer.DecisionEventId as ProducerSubmissionEventId
			,CompanyDetailsFileId
			,CompanyDetailsFileName
			,CompanyDetailsBlobName
			,BrandsFileId
			,BrandsFileName
			,BrandsBlobName
			,PartnershipFileName
			,PartnershipFileId
			,PartnershipBlobName
			,IsResubmission
			FROM
                SubmissionDetails submission
                LEFT JOIN LatestRelatedRegulatorDecisionsCTE decision ON decision.SubmissionId = submission.SubmissionId
                LEFT JOIN LatestProducerCommentEventsCTE producer ON producer.SubmissionId = submission.SubmissionId
        ) 
--select * from SubmissionOrganisationCommentsDetailsCTE
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
        ,r.ProducerCommentDate
        ,r.ProducerSubmissionEventId
        ,r.RegulatorSubmissionEventId
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
        SubmissionOrganisationCommentsDetailsCTE r
        INNER JOIN [rpd].[Organisations] o
			LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber 
			ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
END;
GO
