IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub]')
)
    DROP VIEW [dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub];
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE VIEW [dbo].[V_FetchOrganisationRegistrationSubmissionDetails_resub] AS
WITH derivered_variables AS (
    SELECT O.Id AS OrganisationIDForSubmission,
        O.ExternalId AS OrganisationUUIDForSubmission,
        O.ReferenceNumber AS CSOReferenceNumber,
        CASE
            WHEN S.ComplianceSchemeId IS NOT NULL THEN 1
            ELSE 0
        END AS IsComplianceScheme,
        S.ComplianceSchemeId AS ComplianceSchemeId,
        S.SubmissionPeriod AS SubmissionPeriod,
        S.AppReferenceNumber AS ApplicationReferenceNumber,
        s.submissionid AS submissionid,
        CASE
            WHEN RIGHT(s.SubmissionPeriod, 4) LIKE '%[^0-9]%' THEN NULL
            ELSE CAST(RIGHT(s.SubmissionPeriod, 4) AS INT)
        END AS RelYear,
        CASE
            WHEN RIGHT(s.SubmissionPeriod, 4) LIKE '%[^0-9]%' THEN NULL
            ELSE DATEFROMPARTS(RIGHT(s.SubmissionPeriod, 4), 4, 1)
        END AS SmallLateFeeCutoffDate,
        CASE
            WHEN TRY_CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) IS NOT NULL
                AND RIGHT(s.SubmissionPeriod, 4) NOT LIKE '%[^0-9]%' THEN CASE
                WHEN RIGHT(s.SubmissionPeriod, 4) < '2026' THEN DATEFROMPARTS(CAST(RIGHT(s.SubmissionPeriod, 4) AS INT), 4, 1)
                ELSE DATEFROMPARTS(CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) - 1, 10, 11)
            END
            ELSE NULL
        END AS CSLLateFeeCutoffDate
    FROM [rpd].[Submissions] AS S
    INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE TRY_CAST(RIGHT(s.SubmissionPeriod, 4) AS INT) IS NOT NULL
),

SubmissionEventsCTE AS (
    SELECT subevents.*
    FROM (
        SELECT SubmissionId,
            SubmissionEventId AS SubmissionEventId,
            Created AS DecisionDate,
            Comments AS Comment,
            UserId,
            Type,
            FileId,
            CASE
                WHEN Type = 'RegulatorRegistrationDecision'
                    AND FileId IS NULL THEN CASE
                    WHEN TRIM(Decision) = 'Accepted' THEN 'Granted'
                    WHEN TRIM(Decision) = 'Rejected' THEN 'Refused'
                    WHEN Decision IS NULL THEN 'Pending'
                    ELSE Decision
                END
                ELSE NULL
            END AS SubmissionStatus,
            CASE
                WHEN Type = 'RegulatorRegistrationDecision'
                    AND FileId IS NOT NULL THEN CASE
                    WHEN Decision IS NULL THEN 'Pending'
                    ELSE Decision
                END
                ELSE NULL
            END AS ResubmissionStatus,
            CASE
                WHEN Type = 'RegulatorRegistrationDecision' AND FileId IS NULL
                    THEN 1
                ELSE 0
            END AS IsRegulatorDecision,
            CASE
                WHEN Type = 'RegulatorRegistrationDecision' AND FileId IS NOT NULL
                    THEN 1
                ELSE 0
            END AS IsRegulatorResubmissionDecision,
            CASE
                WHEN Type = 'Submitted' THEN 1
                ELSE 0
            END AS UploadEvent,
            CASE
                WHEN Type = 'RegistrationApplicationSubmitted' AND ISNULL(IsResubmission, 0) = 0
                    THEN 1
                ELSE 0
            END AS IsProducerSubmission,
            CASE
                WHEN Type = 'RegistrationApplicationSubmitted' AND ISNULL(IsResubmission, 0) = 1
                    THEN 1
                ELSE 0
            END AS IsProducerResubmission,
            RegistrationReferenceNumber AS RegistrationReferenceNumber,
            DecisionDate AS StatusPendingDate,
            ROW_NUMBER() OVER (
                PARTITION BY SubmissionId, SubmissionEventId
                ORDER BY Created DESC
            ) AS RowNum,
            IsResubmission
        FROM rpd.SubmissionEvents
        WHERE Type IN ('RegistrationApplicationSubmitted', 'RegulatorRegistrationDecision', 'Submitted')
    ) AS subevents
    WHERE RowNum = 1
),

LatestRegistrationApplicationSubmittedCTE AS (
    SELECT sev.SubmissionId,
        sev.SubmissionEventId,
        sev.DecisionDate AS LatestRegistrationApplicationSubmittedDate,
        ROW_NUMBER() OVER (
            PARTITION BY sev.submissionid, sev.SubmissionEventId
            ORDER BY sev.DecisionDate DESC
        ) AS RowNum
    FROM SubmissionEventsCTE sev
    WHERE sev.type = 'RegistrationApplicationSubmitted'
        AND RowNum = 1
),

LatestFirstUploadedSubmissionEventCTE AS (
    SELECT SubmissionId,
        SubmissionEventId,
        FileId,
        DecisionDate AS UploadDate,
        ROW_NUMBER() OVER (PARTITION BY submissionid ORDER BY DecisionDate DESC) AS RowNum
    FROM SubmissionEventsCTE p
    WHERE UploadEvent = 1
),

latest_file_id AS (
    SELECT x.FileId,
        x.SubmissionId,
        x.SubmissionEventId,
        RowNum
    FROM (
        SELECT upload.FileId,
            decision.SubmissionId,
            decision.SubmissionEventId,
            ROW_NUMBER() OVER (
                PARTITION BY decision.SubmissionId, decision.SubmissionEventId
                ORDER BY upload.RowNum ASC
            ) AS RowNum
        FROM SubmissionEventsCTE decision
        LEFT JOIN LatestFirstUploadedSubmissionEventCTE upload ON decision.submissionid = upload.submissionid
            AND upload.UploadDate < decision.DecisionDate
    ) x
    WHERE x.RowNum = 1
),

ReconciledSubmissionEvents AS (
    SELECT decision.SubmissionId,
        decision.SubmissionEventId,
        DecisionDate,
        Comment,
        UserId,
        [Type],
        lf.FileId,
        RegistrationReferenceNumber,
        SubmissionStatus,
        ResubmissionStatus,
        StatusPendingDate,
        IsRegulatorDecision,
        IsRegulatorResubmissionDecision,
        IsProducerSubmission,
        IsProducerResubmission,
        UploadEvent,
        Row_number() OVER (PARTITION BY decision.submissionid ORDER BY DecisionDate DESC) AS RowNum
    FROM SubmissionEventsCTE decision
    LEFT JOIN latest_file_id lf ON lf.submissionid = decision.submissionid
        AND lf.SubmissionEventId = decision.SubmissionEventId
    WHERE IsProducerSubmission = 1
        OR IsProducerResubmission = 1
        OR IsRegulatorDecision = 1
        OR IsRegulatorResubmissionDecision = 1
),

InitialSubmissionCTE AS (
    SELECT *
    FROM (
        SELECT rse.*,
            cd.organisation_size,
            Row_number() OVER (
                PARTITION BY rse.submissionid ORDER BY RowNum ASC
            ) AS RowNumber
        FROM ReconciledSubmissionEvents rse
        INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.FileId = rse.FileId
        INNER JOIN rpd.companydetails cd ON cd.filename = cfm.filename
        WHERE IsProducerSubmission = 1
            AND IsProducerResubmission = 0
    ) x
    WHERE x.RowNumber = 1
),

FirstSubmissionCTE AS (
    SELECT *
    FROM (
        SELECT *,
            Row_number() OVER (PARTITION BY submissionid ORDER BY RowNum DESC) AS RowNumber
        FROM ReconciledSubmissionEvents
        WHERE IsProducerSubmission = 1
            AND IsProducerResubmission = 0
    ) x
    WHERE x.RowNumber = 1
),

InitialDecisionCTE AS (
    SELECT *
    FROM (
        SELECT *,
            Row_number() OVER (PARTITION BY submissionid ORDER BY RowNum ASC) AS RowNumber
        FROM ReconciledSubmissionEvents
        WHERE IsRegulatorDecision = 1
            AND IsRegulatorResubmissionDecision = 0
    ) x
    WHERE x.RowNumber = 1
),

RegistrationDecisionCTE AS (
    SELECT *
    FROM (
        SELECT *,
            Row_number() OVER (PARTITION BY submissionid ORDER BY RowNum ASC) AS RowNumber
        FROM ReconciledSubmissionEvents
        WHERE IsRegulatorDecision = 1
            AND IsRegulatorResubmissionDecision = 0
            AND SubmissionStatus = 'Granted'
    ) x
    WHERE x.RowNumber = 1
),

LatestDecisionCTE AS (
    SELECT *
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY DecisionDate DESC) AS RowNumber
        FROM ReconciledSubmissionEvents
        WHERE IsRegulatorDecision = 1
            AND IsRegulatorResubmissionDecision = 0
    ) t
    WHERE RowNumber = 1
),

ResubmissionCTE AS (
    SELECT *
    FROM (
        SELECT *,
            Row_number() OVER (PARTITION BY submissionid ORDER BY Rownum ASC) AS RowNumber
        FROM ReconciledSubmissionEvents
        WHERE IsProducerResubmission = 1
    ) x
    WHERE x.RowNumber = 1
),

ResubmissionDecisionCTE AS (
    SELECT *
    FROM ReconciledSubmissionEvents
    WHERE IsRegulatorResubmissionDecision = 1
),

SubmissionStatusCTE AS (
    SELECT *
    FROM (
        SELECT s.SubmissionId,
            CASE
                WHEN s.DecisionDate > id.DecisionDate THEN 'Pending'
                ELSE COALESCE(ld.SubmissionStatus, reg.SubmissionStatus, id.SubmissionStatus, 'Pending')
            END AS SubmissionStatus,
            s.SubmissionEventId,
            s.Comment AS SubmissionComment,
            s.DecisionDate AS SubmissionDate,
            fs.DecisionDate AS FirstSubmissionDate,
            CASE
                WHEN vars.IsComplianceScheme = 1 THEN 'C'
                ELSE s.organisation_size
            END AS OrganisationType,
            CAST(CASE
                WHEN vars.IsComplianceScheme = 1
                    OR TRIM(s.organisation_size) = 'L' THEN CASE
                    WHEN fs.DecisionDate > vars.CSLLateFeeCutoffDate THEN 1
                    ELSE 0
                END
                ELSE CASE
                    WHEN fs.DecisionDate > vars.SmallLateFeeCutoffDate THEN 1
                    ELSE 0
                END
            END AS BIT) AS IsLateSubmission,
            s.FileId AS SubmittedFileId,
            COALESCE(r.UserId, s.UserId) AS SubmittedUserId,
            COALESCE(ld.DecisionDate, reg.DecisionDate, id.DecisionDate) AS RegulatorDecisionDate,
            reg.DecisionDate AS RegistrationDecisionDate,
            id.StatusPendingDate,
            reg.SubmissionEventId AS RegistrationDecisionEventId,
            CASE
                WHEN r.SubmissionEventId IS NOT NULL AND rd.SubmissionEventId IS NOT NULL
                    THEN rd.ResubmissionStatus
                WHEN r.SubmissionEventId IS NOT NULL THEN 'Pending'
                ELSE NULL
            END AS ResubmissionStatus,
            r.Comment AS ResubmissionComment,
            r.SubmissionEventId AS ResubmissionEventId,
            r.DecisionDate AS ResubmissionDate,
            CAST(CASE
                WHEN vars.IsComplianceScheme = 1 OR s.organisation_size = 'L'
                THEN CASE
                        WHEN r.DecisionDate > vars.CSLLateFeeCutoffDate
                        THEN 1
                        ELSE 0
                    END
                ELSE CASE
                    WHEN r.DecisionDate > vars.SmallLateFeeCutoffDate THEN 1
                    ELSE 0
                END
            END AS BIT) AS IsResubmissionLate,
            r.UserId AS ResubmittedUserId,
            rd.DecisionDate AS ResubmissionDecisionDate,
            rd.SubmissionEventId AS ResubmissionDecisionEventId,
            COALESCE(rd.Comment, ld.Comment, id.Comment) AS RegulatorComment,
            COALESCE(r.FileId, s.FileId) AS FileId,
            COALESCE(rd.UserId, id.UserId) AS RegulatorUserId,
            COALESCE(r.UserId, s.UserId) AS LatestProducerUserId,
            reg.RegistrationReferenceNumber,
            -- row number to emulate TOP1 for each submission id by rd.DecisionDate aka ResubmissionDecisionDate as per the original query
            Row_number() OVER (PARTITION BY s.submissionid ORDER BY rd.DecisionDate DESC) AS RowNumber
        FROM InitialSubmissionCTE s
        LEFT JOIN FirstSubmissionCTE fs ON fs.SubmissionId = s.SubmissionId
        LEFT JOIN InitialDecisionCTE id ON id.SubmissionId = s.SubmissionId
        LEFT JOIN LatestDecisionCTE ld ON ld.SubmissionId = s.SubmissionId
        LEFT JOIN RegistrationDecisionCTE reg ON reg.SubmissionId = s.SubmissionId
        LEFT JOIN ResubmissionCTE r ON r.SubmissionId = s.SubmissionId
        LEFT JOIN ResubmissionDecisionCTE rd ON rd.SubmissionId = r.SubmissionId
            AND rd.FileId = r.FileId
        LEFT JOIN derivered_variables vars ON vars.SubmissionId = s.SubmissionId -- added join to variables CTE
    ) x
    WHERE x.RowNumber = 1
),

SubmittedCTE AS (
    SELECT SubmissionId,
        SubmissionEventId,
        SubmissionComment,
        SubmittedFileId AS FileId,
        SubmittedUserId,
        SubmissionDate,
        SubmissionStatus
    FROM SubmissionStatusCTE
),

ResubmissionDetailsCTE AS (
    SELECT SubmissionId,
        ResubmissionEventId,
        ResubmissionComment,
        FileId,
        ResubmittedUserId,
        ResubmissionDate
    FROM SubmissionStatusCTE
),

UploadedDataForOrganisationCTE AS (
    SELECT DISTINCT org.*,
        ss.SubmissionId
    FROM [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] org
    INNER JOIN SubmissionStatusCTE ss ON ss.FileId = org.CompanyFileId
    LEFT JOIN derivered_variables dv ON dv.submissionid = ss.submissionid
        AND dv.OrganisationUUIDForSubmission = org.UploadingOrgExternalId
    WHERE org.SubmissionPeriod = dv.SubmissionPeriod
        AND (
            dv.ComplianceSchemeId IS NULL
            OR org.ComplianceSchemeId = dv.ComplianceSchemeId
        )
        AND (
            org.CompanyFileId IN (
                SELECT FileId
                FROM SubmissionStatusCTE
            )
        )
),

UploadedViewCTE AS (
    SELECT DISTINCT org.UploadingOrgName,
        org.UploadingOrgExternalId,
        CASE
            WHEN org.IsComplianceScheme = 1 THEN NULL
            ELSE org.OrganisationSize
        END AS OrganisationSize,
        org.NationCode,
        org.IsComplianceScheme,
        org.CompanyFileId,
        org.CompanyUploadFileName,
        org.CompanyBlobName,
        org.BrandFileId,
        org.BrandUploadFileName,
        org.BrandBlobName,
        org.PartnerUploadFileName,
        org.PartnerFileId,
        org.PartnerBlobName,
        org.SubmissionId
    FROM UploadedDataForOrganisationCTE org
),

ProducerPaycalParametersCTE AS (
    SELECT OrganisationExternalId,
        ppp.OrganisationId,
        ppp.RegistrationSetId,
        ppp.FileId,
        ppp.FileName,
        ProducerSize,
        IsOnlineMarketplace,
        NumberOfSubsidiaries,
        OnlineMarketPlaceSubsidiaries,
        dv.SubmissionId
    FROM [dbo].[t_ProducerPaycalParameters_resub] AS ppp
    LEFT JOIN [rpd].[cosmos_file_metadata] c ON c.FileName = ppp.FileName -- added to join to derivered_variables
    LEFT JOIN derivered_variables dv ON dv.SubmissionId = c.SubmissionId -- added join to derived variables to get submissionId
    WHERE ppp.FileId IN (
            SELECT FileId
            FROM SubmissionStatusCTE
        )
),

SubmissionDetails AS (
    SELECT a.*
    FROM (
        SELECT s.SubmissionId,
            o.Name AS OrganisationName,
            org.UploadingOrgName AS UploadedOrganisationName,
            o.ReferenceNumber AS OrganisationReferenceNumber,
            org.UploadingOrgExternalId AS OrganisationId,
            SubmittedCTE.SubmissionDate AS SubmittedDateTime,
            s.AppReferenceNumber AS ApplicationReferenceNumber,
            ss.RegistrationReferenceNumber,
            ss.RegistrationDecisionDate AS RegistrationDate,
            ss.RegistrationDecisionEventId AS RegistrationEventId,
            ss.ResubmissionDate,
            ss.SubmissionStatus,
            ss.ResubmissionStatus,
            CASE
                WHEN ss.ResubmissionDate IS NOT NULL THEN 1
                ELSE 0
            END AS IsResubmission,
            CASE
                WHEN ss.ResubmissionDate IS NOT NULL THEN ss.FileId
                ELSE NULL
            END AS ResubmissionFileId,
            ss.RegulatorComment,
            COALESCE(ss.ResubmissionComment, ss.SubmissionComment) AS ProducerComment,
            CASE
                WHEN cs.NationId IS NOT NULL THEN cs.NationId
                ELSE CASE org.NationCode
                    WHEN 'EN' THEN 1
                    WHEN 'NI' THEN 2
                    WHEN 'SC' THEN 3
                    WHEN 'WS' THEN 4
                    WHEN 'WA' THEN 4
                END
            END AS NationId,
            CASE
                WHEN cs.NationId IS NOT NULL THEN CASE cs.NationId
                    WHEN 1 THEN 'GB-ENG'
                    WHEN 2 THEN 'GB-NIR'
                    WHEN 3 THEN 'GB-SCT'
                    WHEN 4 THEN 'GB-WLS'
                END
                ELSE CASE org.NationCode
                    WHEN 'EN' THEN 'GB-ENG'
                    WHEN 'NI' THEN 'GB-NIR'
                    WHEN 'SC' THEN 'GB-SCT'
                    WHEN 'WS' THEN 'GB-WLS'
                    WHEN 'WA' THEN 'GB-WLS'
                END
            END AS NationCode,
            ss.RegulatorUserId,
            ss.ResubmissionEventId,
            GREATEST(ss.RegistrationDecisionDate, ss.RegulatorDecisionDate) AS RegulatorDecisionDate,
            ss.ResubmissionDecisionDate AS RegulatorResubmissionDecisionDate,
            CASE
                WHEN ss.SubmissionStatus = 'Cancelled' THEN ss.StatusPendingDate
                ELSE NULL
            END AS StatusPendingDate,
            s.SubmissionPeriod,
            CAST(SUBSTRING(s.SubmissionPeriod, PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod), 4) AS INT) AS RelevantYear,
            CAST(ss.IsLateSubmission AS BIT) AS IsLateSubmission,
            CASE TRIM(org.organisationsize)
                WHEN 'S' THEN 'Small'
                WHEN 'L' THEN 'Large'
            END AS ProducerSize,
            CONVERT(BIT, org.IsComplianceScheme) AS IsComplianceScheme,
            CASE
                WHEN org.IsComplianceScheme = 1 THEN 'Compliance'
                WHEN TRIM(org.organisationsize) = 'S' THEN 'Small'
                WHEN TRIM(org.organisationsize) = 'L' THEN 'Large'
            END AS OrganisationType,
            CONVERT(BIT, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace,
            ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries,
            ISNULL(ppp.OnlineMarketPlaceSubsidiaries, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
            org.CompanyFileId AS CompanyDetailsFileId,
            org.CompanyUploadFileName AS CompanyDetailsFileName,
            org.CompanyBlobName AS CompanyDetailsBlobName,
            org.BrandFileId AS BrandsFileId,
            org.BrandUploadFileName AS BrandsFileName,
            org.BrandBlobName BrandsBlobName,
            org.PartnerUploadFileName AS PartnershipFileName,
            org.PartnerFileId AS PartnershipFileId,
            org.PartnerBlobName AS PartnershipBlobName,
            ss.LatestProducerUserId AS SubmittedUserId,
            s.ComplianceSchemeId,
            d.ComplianceSchemeId AS CSId,
            ROW_NUMBER() OVER (
                PARTITION BY s.OrganisationId,
                s.SubmissionPeriod,
                s.ComplianceSchemeId,
                s.submissionId -- needed to partition by
                ORDER BY s.load_ts DESC
            ) AS RowNum
        FROM [rpd].[Submissions] AS s
        INNER JOIN SubmittedCTE ON SubmittedCTE.SubmissionId = s.SubmissionId
        LEFT JOIN UploadedViewCTE org ON org.UploadingOrgExternalId = s.OrganisationId
            AND org.SubmissionId = s.SubmissionId
        INNER JOIN [rpd].[Organisations] o ON o.ExternalId = s.OrganisationId
        INNER JOIN SubmissionStatusCTE ss ON ss.SubmissionId = s.SubmissionId
        LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.OrganisationExternalId = s.OrganisationId
            AND ppp.SubmissionId = s.SubmissionId
        LEFT JOIN [rpd].[ComplianceSchemes] cs ON cs.ExternalId = s.ComplianceSchemeId
        LEFT JOIN derivered_variables d ON d.SubmissionId = s.SubmissionId --and d.ComplianceSchemeId=s.ComplianceSchemeId
        WHERE s.SubmissionId = d.SubmissionId
    ) AS a
    WHERE a.RowNum = 1
),

CSSchemeDetailsCTE AS (
    SELECT DISTINCT csm.*,
        re.DecisionDate AS FirstApplicationSubmittedDate
    FROM dbo.v_ComplianceSchemeMembers_resub_latefee csm,
        ReconciledSubmissionEvents re,
        derivered_variables vars
    WHERE vars.IsComplianceScheme = 1
        AND csm.CSOReference = vars.CSOReferenceNumber
        AND csm.SubmissionPeriod = vars.SubmissionPeriod
        AND csm.ComplianceSchemeId = vars.ComplianceSchemeId
        AND csm.EarliestFileId = re.FileId
        AND re.Type = 'RegistrationApplicationSubmitted'
        AND vars.SubmissionId = re.SubmissionId
),

ComplianceSchemeMembersCTE AS (
    SELECT s.*
    FROM (
        SELECT csm.*,
            ss.SubmissionId,
            ss.SubmissionDate AS SubmittedOn,
            ss.IsLateSubmission,
            ss.IsResubmissionLate,
            ss.FileId AS SubmittedFileId,
            ss.FirstSubmissionDate AS FirstApplicationSubmissionDate,
            CASE
                WHEN ss.RegistrationDecisionDate IS NULL THEN 1
                WHEN csm.EarliestSubmissionDate <= ss.RegistrationDecisionDate
                    AND csm.joiner_date IS NULL THEN 1
                WHEN csm.joiner_date IS NULL THEN 1
                ELSE 0
            END AS IsOriginal,
            CASE
                WHEN ss.RegistrationDecisionDate IS NULL THEN 0
                WHEN csm.EarliestSubmissionDate <= ss.RegistrationDecisionDate THEN 0
                WHEN (
                        csm.EarliestSubmissionDate > ss.RegistrationDecisionDate
                        AND csm.joiner_date IS NOT NULL
                    ) THEN 1
                WHEN (
                        csm.EarliestSubmissionDate > ss.RegistrationDecisionDate
                        AND csm.joiner_date IS NULL
                    ) THEN 0
            END AS IsNewJoiner
        FROM CSSchemeDetailsCTE csm
            ,
            SubmissionStatusCTE ss
        WHERE csm.FileId = ss.FileId
    ) s
    LEFT JOIN derivered_variables vars ON vars.SubmissionId = s.SubmissionId
    WHERE vars.IsComplianceScheme = 1
        AND s.CSOReference = vars.CSOReferenceNumber
        AND s.SubmissionPeriod = vars.SubmissionPeriod
        AND s.ComplianceSchemeId = vars.ComplianceSchemeId
),

CompliancePaycalCTE AS (
    SELECT DISTINCT CSOReference,
        csm.ReferenceNumber,
        csm.RelevantYear,
        ppp.ProducerSize,
        csm.SubmittedDate,
        CASE
            --Resubmission - Use pre-existing Logic
            WHEN ss.ResubmissionDate IS NOT NULL THEN CASE
                WHEN csm.IsNewJoiner = 1 THEN csm.IsResubmissionLate
                ELSE csm.IsLateSubmission
            END

            -- Latest Submission On Time for Member Type
            WHEN TRIM(csm.organisation_size) = 'L' AND lras.LatestRegistrationApplicationSubmittedDate <= vars.CSLLateFeeCutoffDate
                THEN 0 -- no late fee

            -- Latest Submission On Time for Member Type
            WHEN TRIM(csm.organisation_size) = 'S' AND lras.LatestRegistrationApplicationSubmittedDate <= vars.SmallLateFeeCutoffDate
                 THEN 0 -- no late fee

            --Original Submission Was Late So All Members are late
            WHEN TRIM(csm.organisation_size) = 'L' AND csm.FirstApplicationSubmissionDate > vars.CSLLateFeeCutoffDate
                THEN 1

            --Original Submission Was Late So All Members are late
            WHEN TRIM(csm.organisation_size) = 'S' AND csm.FirstApplicationSubmissionDate > vars.SmallLateFeeCutoffDate
                THEN 1

            --Original Submission Was On Time So Calculate LateFee if joiner_date presesnt
            ELSE CASE
                -- Check if the first application submission date is later than the first application submitted date
                -- and if the joiner date is null
                WHEN csm.FirstApplicationSubmittedDate > csm.FirstApplicationSubmissionDate AND csm.joiner_date IS NULL
                    THEN 0 -- no late fee

                WHEN csm.FirstApplicationSubmittedDate > csm.FirstApplicationSubmissionDate AND csm.joiner_date IS NOT NULL
                    THEN 1 -- late fee

                ELSE CASE
                    WHEN TRIM(csm.organisation_size) = 'S' THEN CASE
                        -- Check if the first application submitted date is after the small late fee cutoff date
                        WHEN csm.FirstApplicationSubmittedDate > vars.SmallLateFeeCutoffDate
                            THEN 1 -- late fee
                        ELSE 0 -- no late fee
                    END
                    -- For large organizations
                    WHEN TRIM(csm.organisation_size) = 'L' THEN CASE
                        WHEN csm.FirstApplicationSubmittedDate > vars.CSLLateFeeCutoffDate
                            THEN 1
                        ELSE 0
                    END
                    ELSE csm.IsLateSubmission
                END
            END
        END AS IsLateFeeApplicable_Post2025
        -- code end
        ,
        CASE
            WHEN csm.IsNewJoiner = 1
                THEN csm.IsResubmissionLate
            ELSE csm.IsLateSubmission
        END AS IsLateFeeApplicable,
        csm.OrganisationName,
        csm.leaver_code,
        csm.leaver_date,
        csm.joiner_date,
        csm.organisation_change_reason,
        ppp.IsOnlineMarketPlace,
        ppp.NumberOfSubsidiaries,
        ppp.OnlineMarketPlaceSubsidiaries AS NumberOfSubsidiariesBeingOnlineMarketPlace,
        csm.submissionperiod,
        csm.SubmissionId
    FROM ComplianceSchemeMembersCTE csm
    INNER JOIN dbo.t_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
        AND ppp.FileName = csm.FileName
    LEFT JOIN derivered_variables vars ON vars.SubmissionId = csm.SubmissionId
    LEFT JOIN SubmissionStatusCTE ss ON ss.SubmissionId = csm.SubmissionId
    LEFT JOIN LatestRegistrationApplicationSubmittedCTE lras ON lras.SubmissionId = csm.SubmissionId
    WHERE vars.IsComplianceScheme = 1
),

JsonifiedCompliancePaycalCTE AS (
    SELECT cs.CSOReference,
        cs.ReferenceNumber,
        cs.SubmissionId,
        '{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' + '"MemberType": "' + ProducerSize + '", ' + '"IsOnlineMarketPlace": ' + CASE
            WHEN IsOnlineMarketPlace = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(6)) + ', ' + '"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(6)) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS NVARCHAR(16)) + '", ' + '"IsLateFeeApplicable": ' + CASE
            WHEN vars.RelYear < 2026 THEN CASE
                WHEN IsLateFeeApplicable = 1 THEN 'true'
                ELSE 'false'
            END
            ELSE CASE
                WHEN IsLateFeeApplicable_Post2025 = 1 THEN 'true'
                ELSE 'false'
            END
        END + ', ' + '"SubmissionPeriodDescription": "' + cs.submissionperiod + '"}' AS OrganisationDetailsJsonString
    FROM CompliancePaycalCTE cs
    LEFT JOIN derivered_variables vars ON vars.SubmissionId = cs.SubmissionId
),

AllCompliancePaycalParametersAsJSONCTE AS (
    SELECT vars.SubmissionId,
        js.CSOReference,
        '[' + STRING_AGG(CONVERT(NVARCHAR(MAX), OrganisationDetailsJsonString), ', ') + ']' AS FinalJson
    FROM JsonifiedCompliancePaycalCTE js
    LEFT JOIN derivered_variables vars ON vars.SubmissionId = js.SubmissionId
    WHERE js.CSOReference = vars.CSOReferenceNumber
    GROUP BY vars.SubmissionId,
        js.CSOReference
)

SELECT DISTINCT r.SubmissionId,
    r.OrganisationId,
    r.OrganisationName AS OrganisationName,
    CONVERT(NVARCHAR(20), r.OrganisationReferenceNumber) AS OrganisationReference,
    r.ApplicationReferenceNumber,
    r.RegistrationReferenceNumber,
    r.SubmissionStatus,
    r.StatusPendingDate,
    r.SubmittedDateTime,
    r.IsLateSubmission,
    CONVERT(BIT, r.IsResubmission) AS IsResubmission,
    CASE
        WHEN r.IsResubmission = 1 THEN ISNULL(r.ResubmissionStatus, 'Pending')
        ELSE NULL
    END AS ResubmissionStatus,
    r.RegistrationDate,
    r.ResubmissionDate,
    r.ResubmissionFileId,
    r.SubmissionPeriod,
    r.RelevantYear,
    CONVERT(BIT, r.IsComplianceScheme) AS IsComplianceScheme,
    r.ProducerSize AS OrganisationSize,
    r.OrganisationType,
    r.NationId,
    r.NationCode,
    r.RegulatorComment,
    r.ProducerComment,
    r.RegulatorDecisionDate,
    r.RegulatorResubmissionDecisionDate,
    r.RegulatorUserId,
    o.CompaniesHouseNumber,
    o.BuildingName,
    o.SubBuildingName,
    o.BuildingNumber,
    o.Street,
    o.Locality,
    o.DependentLocality,
    o.Town,
    o.County,
    o.Country,
    o.Postcode,
    r.SubmittedUserId,
    p.FirstName,
    p.LastName,
    p.Email,
    p.Telephone,
    sr.Name AS ServiceRole,
    sr.Id AS ServiceRoleId,
    r.IsOnlineMarketplace,
    r.NumberOfSubsidiaries,
    r.NumberOfSubsidiariesBeingOnlineMarketPlace AS NumberOfOnlineSubsidiaries,
    r.CompanyDetailsFileId,
    r.CompanyDetailsFileName,
    r.CompanyDetailsBlobName,
    r.PartnershipFileId,
    r.PartnershipFileName,
    r.PartnershipBlobName,
    r.BrandsFileId,
    r.BrandsFileName,
    r.BrandsBlobName,
    r.ComplianceSchemeId,
    r.CSId,
    acpp.FinalJson AS CSOJson
FROM SubmissionDetails r
INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId
LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber
    AND acpp.SubmissionId = r.SubmissionId
INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId;
GO
