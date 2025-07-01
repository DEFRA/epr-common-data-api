IF EXISTS (SELECT 1 FROM SYS.PROCEDURES WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_nopaycal]'))
	DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_nopaycal];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails_nopaycal] @SubmissionId [NVARCHAR](36) AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @OrganisationIDForSubmission INT;
	DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
	DECLARE @SubmissionPeriod NVARCHAR(100);
	DECLARE @CSOReferenceNumber NVARCHAR(100);
	DECLARE @ComplianceSchemeId NVARCHAR(50);
	DECLARE @ApplicationReferenceNumber NVARCHAR(4000);
	DECLARE @IsComplianceScheme BIT;
    DECLARE @LateFeeCutoffDate DATE; 

    SELECT
        @OrganisationIDForSubmission = O.Id 
		,@OrganisationUUIDForSubmission = O.ExternalId 
		,@CSOReferenceNumber = O.ReferenceNumber 
		,@IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
		,@ComplianceSchemeId = S.ComplianceSchemeId
		,@SubmissionPeriod = S.SubmissionPeriod
	    ,@ApplicationReferenceNumber = S.AppReferenceNumber
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;

	SET @LateFeeCutoffDate = DATEFROMPARTS(CONVERT(INT, SUBSTRING(
                                @SubmissionPeriod,
                                PATINDEX('%[0-9][0-9][0-9][0-9]', @SubmissionPeriod),
                                4
                            )),4, 1);

    WITH
		SubmissionEventsCTE AS (
			SELECT subevents.*
			FROM (
				SELECT
					decisions.SubmissionId,
					decisions.SubmissionEventId AS SubmissionEventId,
					decisions.Created AS DecisionDate,
					decisions.Comments AS Comment,
					decisions.UserId,
					decisions.Type,
					decisions.FileId,
					CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NULL THEN
						CASE
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Accepted' THEN 'Granted'
							WHEN LTRIM(RTRIM(decisions.Decision)) = 'Rejected' THEN 'Refused'
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
						ELSE NULL
					END AS SubmissionStatus
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND decisions.FileId IS NOT NULL THEN
						CASE
							WHEN decisions.Decision IS NULL THEN 'Pending'
							ELSE decisions.Decision
						END
						ELSE NULL
					END AS ResubmissionStatus
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NULL THEN 1 ELSE 0 END AS IsRegulatorDecision
					,CASE WHEN decisions.Type = 'RegulatorRegistrationDecision' AND FileId IS NOT NULL THEN 1 ELSE 0 END AS IsRegulatorResubmissionDecision
					,CASE WHEN decisions.Type = 'Submitted' THEN 1 ELSE 0 END AS UploadEvent 
					,CASE 
						WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 0 THEN 1 ELSE 0
					END AS IsProducerSubmission
					,CASE 
						WHEN decisions.Type = 'RegistrationApplicationSubmitted' AND ISNULL(decisions.IsResubmission,0) = 1 THEN 1 ELSE 0
					END AS IsProducerResubmission
					,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
					,decisions.DecisionDate AS StatusPendingDate
					,ROW_NUMBER() OVER (
						PARTITION BY decisions.SubmissionId, decisions.SubmissionEventId
						ORDER BY decisions.Created DESC
					) AS RowNum
				FROM rpd.SubmissionEvents AS decisions
				WHERE decisions.Type IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision', 'Submitted')	
				AND decisions.SubmissionId = @SubmissionId
			) AS subevents
			WHERE RowNum = 1
		)
		,ProdSubmissionsRegulatorDecisionsCTE AS (
			SELECT
				decisions.SubmissionId
				,decisions.SubmissionEventId
				,decisions.DecisionDate
				,decisions.Comment
				,decisions.UserId
				,decisions.RegistrationReferenceNumber
				,decisions.SubmissionStatus
				,decisions.ResubmissionStatus
				,decisions.StatusPendingDate
				,IsRegulatorDecision
				,IsRegulatorResubmissionDecision
				,IsProducerSubmission
				,IsProducerResubmission
				,UploadEvent
				,[Type]
				,FileId
				,RowNum
			FROM
				SubmissionEventsCTE AS decisions
			WHERE decisions.SubmissionId = @SubmissionId
		)
		,LatestFirstUploadedSubmissionEventCTE AS (
			SELECT * 
			FROM (
				SELECT SubmissionId, FileId, DecisionDate AS UploadDate, ROW_NUMBER() OVER (ORDER BY DecisionDate DESC) AS RowNum
				FROM ProdSubmissionsRegulatorDecisionsCTE p
				WHERE UploadEvent = 1
			) x
		)
		,ReconciledSubmissionEvents AS (		-- applies fileId to corresponding events
			SELECT
				SubmissionId
				,SubmissionEventId
				,DecisionDate
				,Comment
				,UserId
				,[Type]
				,(SELECT TOP 1 FileId 
				  FROM LatestFirstUploadedSubmissionEventCTE upload
				  WHERE upload.UploadDate < decision.DecisionDate
				  ORDER BY upload.RowNum ASC
				 ) AS FileId
				,RegistrationReferenceNumber
				,SubmissionStatus
				,ResubmissionStatus
				,StatusPendingDate
				,IsRegulatorDecision
				,IsRegulatorResubmissionDecision
				,IsProducerSubmission
				,IsProducerResubmission
				,UploadEvent
				,Row_number() OVER (ORDER BY DecisionDate DESC) AS RowNum
			FROM ProdSubmissionsRegulatorDecisionsCTE decision
			WHERE IsProducerSubmission = 1 OR IsProducerResubmission = 1 OR IsRegulatorDecision = 1	OR IsRegulatorResubmissionDecision = 1
		)
		,InitialSubmissionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			ORDER BY RowNum ASC
		)
		,FirstSubmissionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerSubmission = 1 AND IsProducerResubmission = 0
			ORDER BY RowNum DESC
		)
		,InitialDecisionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			ORDER BY RowNum ASC
		)
		,RegistrationDecisionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			AND SubmissionStatus = 'Granted'
			ORDER BY RowNum ASC
		)
		,LatestDecisionCTE AS (
			SELECT * FROM (
				SELECT *, ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNumber
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorDecision = 1 AND IsRegulatorResubmissionDecision = 0
			) t WHERE RowNumber = 1
		)
	    ,ResubmissionCTE AS (
			SELECT TOP 1 *
			FROM ReconciledSubmissionEvents
			WHERE IsProducerResubmission = 1
			ORDER BY Rownum ASC
		)
		,ResubmissionDecisionCTE AS (
			SELECT * 
				FROM ReconciledSubmissionEvents
				WHERE IsRegulatorResubmissionDecision = 1
		)
		,SubmissionStatusCTE AS (
			SELECT TOP 1
				s.SubmissionId
				,CASE WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
				      ELSE COALESCE(ld.SubmissionStatus, reg.SubmissionStatus, id.SubmissionStatus, 'Pending')
				 END AS SubmissionStatus
				,s.SubmissionEventId
				,s.Comment AS SubmissionComment
				,s.DecisionDate AS SubmissionDate
				,fs.DecisionDate AS FirstSubmissionDate
				,CAST(
                    CASE
                        WHEN fs.DecisionDate > @LateFeeCutoffDate THEN 1
                        ELSE 0
                    END AS BIT
                ) AS IsLateSubmission
				,s.FileId AS SubmittedFileId
				,COALESCE(r.UserId, s.UserId) AS SubmittedUserId			
				,COALESCE(ld.DecisionDate, reg.DecisionDate, id.DecisionDate) AS RegulatorDecisionDate
				,reg.DecisionDate AS RegistrationDecisionDate
				,id.StatusPendingDate
				,reg.SubmissionEventId AS RegistrationDecisionEventId

				,CASE
					WHEN r.SubmissionEventId IS NOT NULL AND rd.SubmissionEventId IS NOT NULL THEN rd.ResubmissionStatus
					WHEN r.SubmissionEventId IS NOT NULL THEN 'Pending'
					ELSE NULL
				END AS ResubmissionStatus
				,r.Comment AS ResubmissionComment
				,r.SubmissionEventId AS ResubmissionEventId
				,r.DecisionDate AS ResubmissionDate
				,r.UserId AS ResubmittedUserId
				,rd.DecisionDate AS ResubmissionDecisionDate
				,rd.SubmissionEventId AS ResubmissionDecisionEventId

				,COALESCE(rd.Comment, ld.Comment, id.Comment) AS RegulatorComment
				,COALESCE(r.FileId, s.FileId) AS FileId
				,COALESCE(rd.UserId, id.UserId) AS RegulatorUserId
				,COALESCE(r.UserId, s.UserId) AS LatestProducerUserId
				,reg.RegistrationReferenceNumber
			FROM InitialSubmissionCTE s
			LEFT JOIN FirstSubmissionCTE fs ON fs.SubmissionId = s.SubmissionId
			LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
			LEFT JOIN LatestDecisionCTE ld ON ld.SubmissionId = s.SubmissionId
			LEFT JOIN RegistrationDecisionCTE reg ON reg.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionCTE r ON r.SubmissionId = s.SubmissionId
			LEFT JOIN ResubmissionDecisionCTE rd ON rd.SubmissionId = r.SubmissionId AND rd.FileId = r.FileId
			ORDER BY resubmissiondecisiondate DESC
		)
	,SubmittedCTE AS (
			SELECT SubmissionId, 
					SubmissionEventId, 
					SubmissionComment, 
					SubmittedFileId AS FileId, 
					SubmittedUserId,
					SubmissionDate,
					SubmissionStatus
			FROM SubmissionStatusCTE 
		)
		,ResubmissionDetailsCTE AS (
			SELECT SubmissionId, 
					ResubmissionEventId, 
					ResubmissionComment, 
					FileId, 
					ResubmittedUserId,
					ResubmissionDate
			FROM SubmissionStatusCTE
		)
		,UploadedDataForOrganisationCTE AS (
			SELECT DISTINCT org.*
			FROM
				[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org
				INNER JOIN SubmissionStatusCTE ss ON ss.FileId = org.CompanyFileId
			WHERE org.UploadingOrgExternalId = @OrganisationUUIDForSubmission
				AND org.SubmissionPeriod = @SubmissionPeriod
				AND (@ComplianceSchemeId IS NULL OR org.ComplianceSchemeId = @ComplianceSchemeId)
				AND (org.CompanyFileId IN (SELECT FileId FROM SubmissionStatusCTE))
		)
		,UploadedViewCTE AS (
			SELECT DISTINCT
				org.UploadingOrgName
				,org.UploadingOrgExternalId
				,CASE WHEN org.IsComplianceScheme = 1 THEN NULL
					  ELSE org.OrganisationSize
				 END AS OrganisationSize
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
		,SubmissionDetails AS (
		    SELECT a.* FROM (
				SELECT
					s.SubmissionId
					,o.Name AS OrganisationName
					,org.UploadingOrgName AS UploadedOrganisationName
					,o.ReferenceNumber AS OrganisationReferenceNumber
					,org.UploadingOrgExternalId AS OrganisationId
					,SubmittedCTE.SubmissionDate AS SubmittedDateTime
					,s.AppReferenceNumber AS ApplicationReferenceNumber
					,ss.RegistrationReferenceNumber
					,ss.RegistrationDecisionDate AS RegistrationDate
					,ss.RegistrationDecisionEventId AS RegistrationEventId
            		,ss.ResubmissionDate
					,ss.SubmissionStatus
					,ss.ResubmissionStatus
					,CASE WHEN ss.ResubmissionDate IS NOT NULL 
						  THEN 1
						  ELSE 0
					 END AS IsResubmission
					,CASE WHEN ss.ResubmissionDate IS NOT NULL
						THEN ss.FileId 
						ELSE NULL
					 END AS ResubmissionFileId
					,ss.RegulatorComment
					,COALESCE(ss.ResubmissionComment, ss.SubmissionComment) AS ProducerComment
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
					,ss.ResubmissionEventId
					,GREATEST(ss.RegistrationDecisionDate, ss.RegulatorDecisionDate) AS RegulatorDecisionDate
					,ss.ResubmissionDecisionDate AS RegulatorResubmissionDecisionDate
					,CASE WHEN ss.SubmissionStatus = 'Cancelled' 
						  THEN ss.StatusPendingDate
						  ELSE NULL
					 END AS StatusPendingDate
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
					 END AS ProducerSize
					,CONVERT(BIT, org.IsComplianceScheme) AS IsComplianceScheme
					,CASE 
						WHEN org.IsComplianceScheme = 1 THEN 'Compliance'
						WHEN UPPER(TRIM(org.organisationsize)) = 'S' THEN 'Small'
						WHEN UPPER(TRIM(org.organisationsize)) = 'L' THEN 'Large'
					 END AS OrganisationType
					,org.CompanyFileId AS CompanyDetailsFileId
					,org.CompanyUploadFileName AS CompanyDetailsFileName
					,org.CompanyBlobName AS CompanyDetailsBlobName
					,org.BrandFileId AS BrandsFileId
					,org.BrandUploadFileName AS BrandsFileName
					,org.BrandBlobName BrandsBlobName
					,org.PartnerUploadFileName AS PartnershipFileName
					,org.PartnerFileId AS PartnershipFileId
					,org.PartnerBlobName AS PartnershipBlobName
					,ss.LatestProducerUserId AS SubmittedUserId
					,s.ComplianceSchemeId
					,@ComplianceSchemeId AS CSId
					,ROW_NUMBER() OVER (
						PARTITION BY s.OrganisationId
								     ,s.SubmissionPeriod
									 ,s.ComplianceSchemeId
						ORDER BY s.load_ts DESC
					) AS RowNum
				FROM
					[rpd].[Submissions] AS s
						INNER JOIN SubmittedCTE ON SubmittedCTE.SubmissionId = s.SubmissionId 
						INNER JOIN UploadedViewCTE org ON org.UploadingOrgExternalId = s.OrganisationId
						INNER JOIN [rpd].[Organisations] o ON o.ExternalId = s.OrganisationId
						INNER JOIN SubmissionStatusCTE ss ON ss.SubmissionId = s.SubmissionId
						LEFT JOIN [rpd].[ComplianceSchemes] cs ON cs.ExternalId = s.ComplianceSchemeId 
	    		WHERE s.SubmissionId = @SubmissionId
			) as a
			WHERE a.RowNum = 1
		)
	SELECT DISTINCT
		 r.SubmissionId
		 --CONVERT(UNIQUEIDENTIFIER, r.SubmissionId) AS SubmissionId
		,r.OrganisationId
		-- ,CONVERT(UNIQUEIDENTIFIER, r.OrganisationId) AS OrganisationId
        ,r.OrganisationName AS OrganisationName
        ,CONVERT(NVARCHAR(20), r.OrganisationReferenceNumber) AS OrganisationReference
        ,r.ApplicationReferenceNumber
        ,r.RegistrationReferenceNumber
        ,r.SubmissionStatus
        ,r.StatusPendingDate
        ,r.SubmittedDateTime
		,CONVERT(BIT, r.IsResubmission) AS IsResubmission
        ,CASE WHEN r.IsResubmission = 1 THEN ISNULL(r.ResubmissionStatus, 'Pending') ELSE NULL END AS ResubmissionStatus
		,r.RegistrationDate -- Granted date
		,r.ResubmissionDate
		,r.ResubmissionFileId
		,r.SubmissionPeriod
        ,r.RelevantYear
        ,CONVERT(BIT, r.IsComplianceScheme) AS IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
		,r.RegulatorResubmissionDecisionDate
        ,r.RegulatorUserId
		--,CONVERT(UNIQUEIDENTIFIER, r.RegulatorUserId) AS RegulatorUserId
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
		--,CONVERT(UNIQUEIDENTIFIER, r.SubmittedUserId) AS SubmittedUserId
        ,p.FirstName
        ,p.LastName
        ,p.Email
        ,p.Telephone
        ,sr.Name AS ServiceRole
        ,sr.Id AS ServiceRoleId
        ,r.CompanyDetailsFileId
		,CONVERT(UNIQUEIDENTIFIER, r.CompanyDetailsFileId) AS CompanyDetailsFileId
        ,r.CompanyDetailsFileName
        ,r.CompanyDetailsBlobName
		--,CONVERT(UNIQUEIDENTIFIER, r.CompanyDetailsFileId) AS CompanyDetailsFileId
		,r.PartnershipFileId
        --,CONVERT(UNIQUEIDENTIFIER, r.PartnershipFileId) AS PartnershipFileId
        ,r.PartnershipFileName
        ,r.PartnershipBlobName
		,r.BrandsFileId
        --,CONVERT(UNIQUEIDENTIFIER, r.BrandsFileId) AS BrandsFileId
        ,r.BrandsFileName
        ,r.BrandsBlobName
		--,CONVERT(UNIQUEIDENTIFIER, r.BrandsBlobName) AS BrandsBlobName
		,r.ComplianceSchemeId
		--,CONVERT(UNIQUEIDENTIFIER, r.ComplianceSchemeId) AS ComplianceSchemeId
    FROM
        SubmissionDetails r 
		INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
END;
GO