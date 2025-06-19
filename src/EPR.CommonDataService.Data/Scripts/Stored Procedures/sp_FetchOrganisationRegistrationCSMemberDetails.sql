IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationCSMemberDetails]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationCSMemberDetails];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationCSMemberDetails]
    @SubmissionId [nvarchar](36),
    @ForProducer bit
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
    DECLARE @SubmissionPeriod nvarchar(100);
    DECLARE @ComplianceSchemeId nvarchar(50);
    DECLARE @IsComplianceScheme bit;
    DECLARE @LateFeeCutoffDate DATE;

    DECLARE @RegistrationDate datetime2(7);
    declare @FileId nvarchar(50) = null;
    DECLARE @SubmittedDateTime nvarchar(50);
    DECLARE @IsLateSubmission bit;

    SELECT
        @OrganisationUUIDForSubmission = O.ExternalId 
		, @IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
		, @ComplianceSchemeId = S.ComplianceSchemeId
		, @SubmissionPeriod = S.SubmissionPeriod
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;

    IF @IsComplianceScheme = 0
    BEGIN
        SELECT CAST(NULL as NVARCHAR(500)) as CSOOrgName
		   , CAST(NULL as NVARCHAR(20)) as CSOReference
		   , CAST(NULL as NVARCHAR(100)) as SubmissionPeriod
		   , CAST(NULL as NVARCHAR(20)) as ReferenceNumber
		   , CAST(NULL as NVARCHAR(20)) AS RelevantYear
		   , CAST(NULL as NVARCHAR(20)) as ProducerSize
		   , CAST(NULL as NVARCHAR(4000)) as SubmittedDate
		   , CAST(NULL as Bit) as IsLateFeeApplicable
		   , CAST(NULL as NVARCHAR(500)) as MemberName
		   , CAST(NULL as NVARCHAR(50)) as leaver_code
		   , CAST(NULL as NVARCHAR(50)) as leaver_date
		   , CAST(NULL as NVARCHAR(50)) as joiner_date
		   , CAST(NULL as NVARCHAR(50)) as organisation_change_reason
		   , CAST(NULL as Bit) as IsOnlineMarketPlace
		   , CAST(NULL as int) AS NumberOfSubsidiaries
		   , CAST(NULL as int) AS NumberOfSubsidiariesBeingOnlineMarketPlace
        WHERE 1=0
    END

    IF @IsComplianceScheme = 1
    BEGIN

        SET @LateFeeCutoffDate = DATEFROMPARTS(CONVERT( int, SUBSTRING(
                                @SubmissionPeriod,
                                PATINDEX('%[0-9][0-9][0-9][0-9]', @SubmissionPeriod),
                                4
                            )),4, 1);

        IF OBJECT_ID('tempdb..#SubmissionStatus') IS NOT NULL
		DROP TABLE #SubmissionStatus;
        IF OBJECT_ID('tempdb..#ComplianceMembers') IS NOT NULL
        DROP TABLE #ComplianceMembers;
        IF OBJECT_ID('tempdb..#PaycalProperties') IS NOT NULL
        DROP TABLE #PaycalProperties;
        IF OBJECT_ID('tempdb..#Jsonified') IS NOT NULL
		DROP TABLE #Jsonified;

        WITH
            Uploads
            AS
            (
                SELECT
                    FileId,
                    Created    AS UploadCreated
                FROM rpd.SubmissionEvents
                WHERE SubmissionId = @SubmissionId
                    AND Type = 'Submitted'
            ),

            PickedUpload
            AS
            (
                SELECT TOP 1
                    u.FileId,
                    u.UploadCreated,

                    COALESCE(sub.NextSubmitted, u.UploadCreated)   AS SubmittedOn,

                    CASE 
		WHEN COALESCE(sub.NextSubmitted, u.UploadCreated) > @LateFeeCutoffDate 
			THEN 1 
		ELSE 0 
		END                                           AS IsLateSubmission,

                    dec.MaxDecisionDate                           AS RegistrationDecisionDate

                FROM Uploads AS u

        OUTER APPLY
        (
        SELECT MIN(s.Created) AS NextSubmitted
                    FROM rpd.SubmissionEvents AS s
                    WHERE s.SubmissionId = @SubmissionId
                        AND s.Type = 'RegistrationApplicationSubmitted'
                        AND s.Created > u.UploadCreated
        ) AS sub

        OUTER APPLY
        (
        SELECT MAX(d.Created) AS MaxDecisionDate
                    FROM rpd.SubmissionEvents AS d
                    WHERE d.SubmissionId = @SubmissionId
                        AND d.Type = 'RegulatorRegistrationDecision'
                        AND ISNULL(d.IsResubmission,0) = 0
                        AND d.Decision = 'Accepted'
                        AND d.RegistrationReferenceNumber IS NOT NULL
        ) AS dec

                WHERE
        (
            @ForProducer = 1
                    AND sub.NextSubmitted IS NULL
        )
                    OR
                    (
            ISNULL(@ForProducer,0) = 0
                    AND sub.NextSubmitted IS NOT NULL
        )

                ORDER BY u.UploadCreated DESC
            )

        SELECT
            @FileId               = FileId,
            @SubmittedDateTime    = SubmittedOn,
            @RegistrationDate   = RegistrationDecisionDate,
            @IsLateSubmission = IsLateSubmission
        FROM PickedUpload;

        select distinct
            CSOOrgName
            , CSOReference
            , RelevantYear
            , @SubmittedDateTime as SubmittedOn
			, @IsLateSubmission as IsLateSubmission
			, csm.FileId as SubmittedFileId
			, MemberName 
            , ReferenceNumber 
            , ExternalId
            , SubmittedDate
            , EarliestSubmissionDate
            , LateFeeCutoffDate
            , IsLateSubmission as IsMemberLate
            , organisation_size
            , leaver_code
            , leaver_date
            , joiner_date
            , organisation_change_reason
            , CASE WHEN @RegistrationDate IS NULL THEN 1
					WHEN csm.EarliestSubmissionDate <= @RegistrationDate AND csm.joiner_date is null THEN 1
					WHEN csm.joiner_date is null THEN 1
					ELSE 0 END
			AS IsOriginal
			, CASE WHEN @RegistrationDate IS NULL THEN 0
					WHEN csm.EarliestSubmissionDate <= @RegistrationDate THEN 0
					WHEN ( csm.EarliestSubmissionDate > @RegistrationDate and csm.joiner_date is not null) THEN 1
					WHEN ( csm.EarliestSubmissionDate > @RegistrationDate and csm.joiner_date is null) THEN 0
			END as IsNewJoiner
        INTO #ComplianceMembers
        from dbo.fn_ComplianceSchemeMembers(@OrganisationUUIDForSubmission, @SubmissionPeriod, @ComplianceSchemeId) csm
        where csm.CSOExternalId = @OrganisationUUIDForSubmission
            and csm.SubmissionPeriod = @SubmissionPeriod
            and csm.ComplianceSchemeId = @ComplianceSchemeId
            and csm.FileId = @FileId;

        select DISTINCT
            OrganisationId
        , IsOnlineMarketPlace
        , OrganisationSize
        , ProducerSize
        , NationId
        , OnlineMarketPlaceSubsidiaries
        , NumberOfSubsidiaries
        INTO #PaycalProperties
        from dbo.fn_ProducerPaycalParameters(@FileId) ppp;

        WITH
            CompliancePaycalCTE
            AS
            (
                SELECT
                    CSOOrgName
            , CSOReference
            , @SubmissionPeriod as SubmissionPeriod
            , CONVERT(NVARCHAR(20), csm.ReferenceNumber) as ReferenceNumber
            , CONVERT(int, csm.RelevantYear) as RelevantYear
            , ppp.ProducerSize
            , CONVERT(NVARCHAR(60), csm.EarliestSubmissionDate, 126) as SubmittedDate
            , CONVERT(BIT, CASE WHEN csm.IsNewJoiner = 1 THEN csm.IsMemberLate
                    ELSE csm.IsLateSubmission END) 
                AS IsLateFeeApplicable
            , csm.MemberName
            , csm.leaver_code
            , csm.leaver_date
            , csm.joiner_date
            , csm.organisation_change_reason
            , CONVERT(bit, ppp.IsOnlineMarketPlace) as IsOnlineMarketPlace
            , ppp.NumberOfSubsidiaries
            , ppp.OnlineMarketPlaceSubsidiaries as NumberOfSubsidiariesBeingOnlineMarketPlace
                FROM
                    #ComplianceMembers csm
                    inner join #PaycalProperties ppp ON ppp.OrganisationId = csm.ReferenceNumber
            )
        SELECT *
        FROM CompliancePaycalCTE;
    END
END
GO
