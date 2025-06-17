IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_FetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [apps].[sp_FetchOrganisationRegistrationSubmissionDetails];
GO

CREATE PROC [apps].[sp_FetchOrganisationRegistrationSubmissionDetails] @SubmissionId [nvarchar](36) AS

BEGIN
	SET NOCOUNT ON;
	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod nvarchar(100);
	DECLARE @CSOReferenceNumber nvarchar(100);
	DECLARE @ComplianceSchemeId nvarchar(50);
	DECLARE @ApplicationReferenceNumber nvarchar(4000);
	DECLARE @IsComplianceScheme bit;
    DECLARE @LateFeeCutoffDate DATE; 

    SELECT
        @OrganisationIDForSubmission = O.Id 
		,@OrganisationUUIDForSubmission = O.ExternalId 
		,@CSOReferenceNumber = O.ReferenceNumber 
		,@IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
		,@ComplianceSchemeId = S.ComplianceSchemeId
		,@SubmissionPeriod = S.SubmissionPeriod
	    ,@ApplicationReferenceNumber = S.ApplicationReferenceNumber
    FROM
        [apps].[OrgRegistrationsSummaries] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;

	SET @LateFeeCutoffDate = DATEFROMPARTS(CONVERT( int, SUBSTRING(
                                @SubmissionPeriod,
                                PATINDEX('%[0-9][0-9][0-9][0-9]', @SubmissionPeriod),
                                4
                            )),4, 1);
    WITH
        OriginCTE as (
            select *
            from [apps].[OrgRegistrationsSummaries]
            where submissionid = @SubmissionId
        )
		,SubmissionStatusCTE AS (
			SELECT 
                ss.SubmissionId,
				ss.SubmissionStatus
				,ss.ProducerComment as SubmissionComment
				,ss.SubmittedDateTime as SubmissionDate
				,ss.FirstSubmissionDate
				,ss.IsLateSubmission
            	,ss.FileId as SubmittedFileId
				,ss.SubmittedUserId			
				,ss.RegulatorDecisionDate
				,ss.RegistrationDate as RegistrationDecisionDate
				,ss.StatusPendingDate
				,ss.ResubmissionStatus
				,ss.ResubmissionComment
				,ss.ResubmissionDate
				,ss.ResubmittedUserId
				,ss.ResubmissionDecisionDate
				
				,ss.RegulatorComment
				,ss.FileId
				,ss.RegulatorUserId
				,ss.ProducerUserId as LatestProducerUserId

				,ss.RegistrationReferenceNumber
            FROM OriginCTE as ss
		)
--select * from SubmissionStatusCTE
	,SubmittedCTE as (
			SELECT SubmissionId, 
					SubmissionComment, 
					SubmittedFileId as FileId, 
					SubmittedUserId,
					SubmissionDate,
					SubmissionStatus
			FROM SubmissionStatusCTE 
		)
		,ResubmissionDetailsCTE as (
			SELECT SubmissionId, 
					ResubmissionComment, 
					FileId, 
					ResubmittedUserId,
					ResubmissionDate
			FROM SubmissionStatusCTE
		)
		,UploadedDataForOrganisationCTE as (
			select distinct org.*
			FROM
				[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org
				inner join SubmissionStatusCTE ss on ss.FileId = org.CompanyFileId
			WHERE org.UploadingOrgExternalId = @OrganisationUUIDForSubmission
				and org.SubmissionPeriod = @SubmissionPeriod
				and (@ComplianceSchemeId IS NULL OR org.ComplianceSchemeId = @ComplianceSchemeId)
				and (org.CompanyFileId IN (SELECT FileId from SubmissionStatusCTE))
		)
		,UploadedViewCTE as (
			select distinct
				org.UploadingOrgName
				,org.UploadingOrgExternalId
				,CASE WHEN org.IsComplianceScheme = 1 THEN NULL
					  ELSE org.OrganisationSize
				 END as OrganisationSize
				,org.NationCode
				,org.IsComplianceScheme
				,org.CompanyFileId
				,org.CompanyUploadFileName
				,org.CompanyBlobName
				,org.BrandFileId
				,org.BrandUploadFileName
				,org.BrandBlobName
				,org.PartnerUploadFileName
				,org.PartnerFileId
				,org.PartnerBlobName
			FROM
				UploadedDataForOrganisationCTE org 
		)
		,ProducerPaycalParametersCTE
			AS
			(
				SELECT
				OrganisationExternalId
				,OrganisationId
				,ppp.RegistrationSetId
				,FileId
				,FileName
				,ProducerSize
				,IsOnlineMarketplace
				,NumberOfSubsidiaries
				,OnlineMarketPlaceSubsidiaries
				FROM
					[dbo].[v_ProducerPaycalParameters_resub] AS ppp
				WHERE ppp.FileId in (SELECT FileId from SubmissionStatusCTE)
		)
		,SubmissionDetails AS (
		    select a.* FROM (
				SELECT
					s.SubmissionId
					,o.Name AS OrganisationName
					,org.UploadingOrgName as UploadedOrganisationName
					,o.ReferenceNumber as OrganisationReferenceNumber
					,org.UploadingOrgExternalId as OrganisationId
					,SubmittedCTE.SubmissionDate as SubmittedDateTime
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,ss.RegistrationReferenceNumber
					,ss.RegistrationDecisionDate as RegistrationDate
            		,ss.ResubmissionDate
					,ss.SubmissionStatus
					,ss.ResubmissionStatus
					,CASE WHEN ss.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
					 END as IsResubmission
					,CASE WHEN ss.ResubmissionDate IS NOT NULL
						THEN ss.FileId 
						ELSE NULL
					 END as ResubmissionFileId
					,ss.RegulatorComment
					,COALESCE(ss.ResubmissionComment, ss.SubmissionComment) as ProducerComment
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
					,ss.RegulatorUserId
					,GREATEST(ss.RegistrationDecisionDate, ss.RegulatorDecisionDate) as RegulatorDecisionDate
					,ss.ResubmissionDecisionDate as RegulatorResubmissionDecisionDate
					,CASE WHEN ss.SubmissionStatus = 'Cancelled' 
						  THEN ss.StatusPendingDate
						  ELSE null
					 END as StatusPendingDate
					,s.SubmissionPeriod
					,CAST(
						SUBSTRING(
							s.SubmissionPeriod,
							PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
							4
						) AS INT
					) AS RelevantYear
					,CAST(ss.IsLateSubmission AS BIT) AS IsLateSubmission
					,CASE UPPER(TRIM(org.organisationsize))
						WHEN 'S' THEN 'Small'
						WHEN 'L' THEN 'Large'
					 END as ProducerSize
					,CONVERT(bit, org.IsComplianceScheme) as IsComplianceScheme
					,CASE 
						WHEN org.IsComplianceScheme = 1 THEN 'Compliance'
						WHEN UPPER(TRIM(org.organisationsize)) = 'S' THEN 'Small'
						WHEN UPPER(TRIM(org.organisationsize)) = 'L' THEN 'Large'
					 END AS OrganisationType
					,CONVERT(bit, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace
					,ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
					,ISNULL(ppp.OnlineMarketPlaceSubsidiaries,0) AS NumberOfSubsidiariesBeingOnlineMarketPlace
					,org.CompanyFileId AS CompanyDetailsFileId
					,org.CompanyUploadFileName AS CompanyDetailsFileName
					,org.CompanyBlobName AS CompanyDetailsBlobName
					,org.BrandFileId AS BrandsFileId
					,org.BrandUploadFileName AS BrandsFileName
					,org.BrandBlobName BrandsBlobName
					,org.PartnerUploadFileName AS PartnershipFileName
					,org.PartnerFileId AS PartnershipFileId
					,org.PartnerBlobName AS PartnershipBlobName
					,ss.LatestProducerUserId as SubmittedUserId
					,s.ComplianceSchemeId
					,@ComplianceSchemeId as CSId
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId
								     ,s.SubmissionPeriod
									 ,s.ComplianceSchemeId
						ORDER BY s.load_ts DESC
					) AS RowNum
				FROM
					[rpd].[Submissions] AS s
						INNER JOIN SubmittedCTE on SubmittedCTE.SubmissionId = s.SubmissionId 
						INNER JOIN UploadedViewCTE org on org.UploadingOrgExternalId = s.OrganisationId
						INNER JOIN [rpd].[Organisations] o on o.ExternalId = s.OrganisationId
						INNER JOIN SubmissionStatusCTE ss on ss.SubmissionId = s.SubmissionId
		                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.OrganisationExternalId = s.OrganisationId
						LEFT JOIN [rpd].[ComplianceSchemes] cs on cs.ExternalId = s.ComplianceSchemeId 
	    		WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
		,ComplianceSchemeMembersCTE as (
			select csm.*
				   ,ss.SubmissionDate as SubmittedOn
				   ,ss.IsLateSubmission
				   ,ss.FileId as SubmittedFileId
				   ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 1
						 WHEN csm.SubmittedDate <= ss.RegistrationDecisionDate AND csm.joiner_date is null THEN 1
						 WHEN csm.joiner_date is null THEN 1
						 ELSE 0 END
					AS IsOriginal
				   ,CASE WHEN ss.RegistrationDecisionDate IS NULL THEN 0
						 WHEN csm.SubmittedDate <= ss.RegistrationDecisionDate THEN 0
					     WHEN ( csm.SubmittedDate > ss.RegistrationDecisionDate and csm.joiner_date is not null) THEN 1
					     WHEN ( csm.SubmittedDate > ss.RegistrationDecisionDate and csm.joiner_date is null) THEN 0
					END as IsNewJoiner
			from dbo.v_ComplianceSchemeMembers_resub csm
				,SubmissionStatusCTE ss
			where @IsComplianceScheme = 1
				  and csm.CSOReference = @CSOReferenceNumber
				  and csm.SubmissionPeriod = @SubmissionPeriod
				  and csm.ComplianceSchemeId = @ComplianceSchemeId
				  and csm.FileId = ss.FileId
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
				,CASE WHEN csm.IsNewJoiner = 1 THEN csm.IsLateFeeApplicable
					  ELSE csm.IsLateSubmission END 
			     AS IsLateFeeApplicable
				,csm.OrganisationName
				,csm.leaver_code
				,csm.leaver_date
				,csm.joiner_date
				,csm.organisation_change_reason
				,ppp.IsOnlineMarketPlace
				,ppp.NumberOfSubsidiaries
				,ppp.OnlineMarketPlaceSubsidiaries as NumberOfSubsidiariesBeingOnlineMarketPlace
				,csm.submissionperiod
            FROM
				ComplianceSchemeMembersCTE csm
				INNER JOIN dbo.v_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
				  			AND ppp.FileName = csm.FileName
            WHERE @IsComplianceScheme = 1
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
            ,'[' + STRING_AGG(CONVERT(nvarchar(max),OrganisationDetailsJsonString), ', ') + ']' AS FinalJson
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
        ,CASE WHEN r.IsResubmission = 1 THEN ISNULL(r.ResubmissionStatus, 'Pending') ELSE NULL END as ResubmissionStatus
		,r.RegistrationDate
		,r.ResubmissionDate
		,r.ResubmissionFileId
		,r.SubmissionPeriod
        ,r.RelevantYear
        ,CONVERT(bit, r.IsComplianceScheme) as IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
		,r.RegulatorResubmissionDecisionDate
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
		,r.ComplianceSchemeId
		,r.CSId
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
