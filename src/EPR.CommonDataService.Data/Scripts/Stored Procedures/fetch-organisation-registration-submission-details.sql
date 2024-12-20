IF EXISTS (SELECT
    1
FROM
    sys.procedures
WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails] @SubmissionId [nvarchar](36) AS
BEGIN
SET NOCOUNT ON;

DECLARE @OrganisationIDForSubmission INT;
DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
DECLARE @SubmissionPeriod nvarchar(100);
DECLARE @CSOReferenceNumber nvarchar(100);
DECLARE @ApplicationReferenceNumber nvarchar(4000);
DECLARE @ComplianceSchemeId nvarchar(50);
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

    WITH
		ProdCommentsRegulatorDecisionsCTE as (
			SELECT
				CONVERT( uniqueidentifier, TRIM(decisions.SubmissionId)) as  Submissionid
				,decisions.SubmissionEventId AS DecisionEventId
				,decisions.Created as DecisionDate
				,decisions.Comments AS Comment
				,decisions.UserId
				,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
				,CASE
					WHEN LTRIM(RTRIM(decisions.Decision)) = 'Accepted' THEN 'Granted'
					WHEN LTRIM(RTRIM(decisions.Decision)) = 'Rejected' THEN 'Refused'
					WHEN decisions.decision IS NULL THEN 'Pending'
					ELSE decisions.Decision
				END AS SubmissionStatus
				,decisions.DecisionDate AS StatusPendingDate
				,CASE WHEN decisions.Type = 'RegistrationApplicationSubmitted'
					 THEN 1
					 ELSE 0
				 END AS IsProducerComment
				,ROW_NUMBER() OVER (
					PARTITION BY decisions.SubmissionId, decisions.Type
					ORDER BY decisions.Created DESC -- mark latest submissionEvent synced from cosmos
				) AS RowNum
			FROM
				rpd.SubmissionEvents as decisions
			WHERE decisions.Type IN ( 'RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision')		
				AND decisions.SubmissionId = @SubmissionId
		)
		,GrantedDecisionsCTE as (
			SELECT TOP 1 *
			FROM ProdCommentsRegulatorDecisionsCTE granteddecision
			WHERE IsProducerComment = 0
					AND SubmissionStatus = 'Granted'
			ORDER BY DecisionDate DESC
		)
		,UploadedDataCTE as (
			select *
			from dbo.fn_GetUploadedOrganisationDetails(@OrganisationUUIDForSubmission, @SubmissionPeriod)
		)
		,ProducerPaycalParametersCTE
			AS
			(
				SELECT
					ExternalId
				,ProducerSize
				,IsOnlineMarketplace
				,NumberOfSubsidiaries
				,NumberOfSubsidiariesBeingOnlineMarketPlace
				FROM
					[dbo].[v_ProducerPaycalParameters] AS ppp
			WHERE ppp.ExternalId = @OrganisationUUIDForSubmission
		)
        ,SubmissionDetails AS (
		    select a.* FROM (
				SELECT
					o.Name AS OrganisationName
					,org.UploadOrgName as UploadedOrganisationName
					,o.ReferenceNumber
					,org.SubmittingExternalId as OrganisationId
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,granteddecision.RegistrationReferenceNumber
					,granteddecision.SubmissionStatus
					,granteddecision.UserId as RegulatorUserId
					,granteddecision.DecisionDate as RegulatorDecisionDate
            		,s.SubmissionPeriod
					,s.SubmissionId
					,s.OrganisationId AS InternalOrgId
					,s.Created AS SubmittedDateTime
					,CASE 
						UPPER(org.NationCode)
						WHEN 'EN' THEN 1
						WHEN 'SC' THEN 3
						WHEN 'WA' THEN 4
						WHEN 'NI' THEN 2
					 END AS NationId
					,CASE
						UPPER(org.NationCode)

						WHEN 'EN' THEN 'GB-ENG'
						WHEN 'NI' THEN 'GB-NIR'
						WHEN 'SC' THEN 'GB-SCT'
						WHEN 'WA' THEN 'GB-WLS'
					END AS NationCode
					,s.SubmissionType
					,s.UserId AS SubmittedUserId
					,CAST(
						SUBSTRING(
							s.SubmissionPeriod,
							PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
							4
						) AS INT
					) AS RelevantYear
					,CAST(
						CASE
							WHEN s.Created > DATEFROMPARTS(CONVERT( int, SUBSTRING(
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
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId,
						s.SubmissionPeriod
						ORDER BY s.load_ts DESC -- mark latest submission synced from cosmos
					) AS RowNum
				FROM
					[rpd].[Submissions] AS s
					INNER JOIN UploadedDataCTE org ON org.SubmittingExternalId = s.OrganisationId
					INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
					LEFT JOIN GrantedDecisionsCTE granteddecision on granteddecision.SubmissionId = s.SubmissionId 
	                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.ExternalId = s.OrganisationId
				WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
		,LatestRelatedRegulatorDecisionsCTE AS
		(
			select a.SubmissionId
				,a.DecisionEventId
				,a.DecisionDate as RegulatorDecisionDate
				,a.UserId as RegulatorUserId
				,a.Comment as RegulatorComment
				,a.RegistrationReferenceNumber
				,a.SubmissionStatus
				,a.StatusPendingDate
			from ProdCommentsRegulatorDecisionsCTE as a
			where a.IsProducerComment = 0 and a.RowNum = 1
		)
		,LatestProducerCommentEventsCTE
        AS
        (
            SELECT DISTINCT
				comment.SubmissionId
				,comment.DecisionEventId
				,Comment AS ProducerComment
				,DecisionDate AS ProducerCommentDate
            FROM
                ProdCommentsRegulatorDecisionsCTE AS comment
			WHERE comment.IsProducerComment = 1 and comment.RowNum = 1
        )
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
            ,submission.SubmittedDateTime
            ,submission.IsLateSubmission
            ,submission.SubmissionPeriod
            ,ISNULL(ISNULL(submission.SubmissionStatus, decision.SubmissionStatus),'Pending') as SubmissionStatus
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
			FROM
                SubmissionDetails submission
                LEFT JOIN LatestRelatedRegulatorDecisionsCTE decision ON decision.SubmissionId = submission.SubmissionId
                LEFT JOIN LatestProducerCommentEventsCTE producer ON producer.SubmissionId = submission.SubmissionId
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
END
GO
