IF EXISTS (SELECT 1 FROM SYS.PROCEDURES WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata]'))
    DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmission_Paycal_Metadata] @BeforeProducerSubmits [bit],@SubmissionId [nvarchar](50),@FileId [nvarchar](50) AS
BEGIN

    SET NOCOUNT ON;
    declare @targetFileId nvarchar(50);
    declare @targetSubmissionId nvarchar(50);

    DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
    DECLARE @SubmissionPeriod nvarchar(100);
    DECLARE @CSOReferenceNumber nvarchar(100);
    DECLARE @ComplianceSchemeId nvarchar(50);
    DECLARE @IsComplianceScheme bit;

    DECLARE @FirstSubmittedOn datetime2(7);
    DECLARE @SubmittedOn datetime2(7);
    DECLARE @CancelledOn datetime2(7);
    DECLARE @RegistrationDecisionDate datetime2(7);

    IF OBJECT_ID('tempdb..#PaycalParams') IS NOT NULL
    DROP TABLE #PaycalParams;

    CREATE TABLE #PaycalParams
    (
        SubmissionId NVARCHAR(50),
        IsCSO bit,
        CSOReference nvarchar(50),
        CSOExternalId UNIQUEIDENTIFIER,
        ComplianceSchemeId UNIQUEIDENTIFIER,
        SubmissionPeriod nvarchar(50),
        FirstSubmittedOn datetime2(7),
        ReferenceNumber int,
        ExternalId nvarchar(50),
        OrganisationName nvarchar(250),
        IsOriginal bit,
        IsNewJoiner bit,
        RelevantYear int,
        SubmittedDate datetime2(7),
        EarliestSubmissionDate datetime2(7),
        OrganisationSize VARCHAR(1),
        LeaverCode nvarchar(20),
        LeaverDate nvarchar(20),
        JoinerDate nvarchar(20),
        OrganisationChangeReason nvarchar(20),
        IsOnlineMarketPlace bit,
        NumberOfSubsidiaries int,
        NumberOfSubsidiariesBeingOnlineMarketPlace int,    
        FileName UNIQUEIDENTIFIER,
        FileId UNIQUEIDENTIFIER
    );

    IF (@FileId IS NOT NULL AND @SubmissionId IS NULL)
    BEGIN
        set @targetFileId  = @FileId;
        select @targetSubmissionId = se.SubmissionId
        from rpd.SubmissionEvents se
        where se.FileId = @FileId 
        and se.Type = 'Submitted'
    END

    IF (@SubmissionId IS NOT NULL)
    BEGIN
        set @targetSubmissionId = @SubmissionId;
    END
    if @SubmissionId IS NULL AND @FileId IS NULL
    BEGIN
        select * from #PaycalParams
        where 1=0;
    END
    ELSE
    BEGIN
        -- For the given submission id, get the metadata of the submission and the FileId
        -- for that submission
        -- there is either a file that has no RegistrationApplicationSubmitted event
        -- or ones that do have that event
        -- For Producers - they need a FileId that is not yet Submitted, so the paycal metadata
        -- can be extracted for that file
        -- and for regulators - it is required that they see ONLY those files that have a RegistrationApplicationSubmitted event
        -- this block extracts the targetFileId according to this logic

        SELECT TOP 1 @targetFileId = upload.FileId,
                    @SubmittedOn = COALESCE(
                        (
                            SELECT MAX(submitted.Created)
                            FROM rpd.SubmissionEvents submitted
                            WHERE submitted.SubmissionId = upload.SubmissionId
                            AND submitted.Type = 'RegistrationApplicationSubmitted'
                            AND submitted.Created > upload.Created
                        ),
                        upload.Created
                    )
                    ,@FirstSubmittedOn = COALESCE(
                        (
                            SELECT MIN(submitted.Created)
                            FROM rpd.SubmissionEvents submitted
                            WHERE submitted.SubmissionId = upload.SubmissionId
                            AND submitted.Type = 'RegistrationApplicationSubmitted'
                            AND submitted.Created > upload.Created
                        ),
                        upload.Created
                    )
                    ,@RegistrationDecisionDate = (
                        SELECT MAX(sub.Created)
                        FROM rpd.SubmissionEvents sub
                        WHERE sub.SubmissionId = upload.SubmissionId
                            AND sub.Type = 'RegulatorRegistrationDecision'
                            AND ISNULL(sub.IsResubmission,0) = 0
                            AND sub.Decision = 'Accepted'
                            AND sub.RegistrationReferenceNumber IS NOT NULL
                    )
                    ,@CancelledOn = (
                        SELECT Min(sub.Created)
                        from rpd.SubmissionEvents sub
                        WHERE sub.SubmissionId = upload.SubmissionId
                            AND sub.Type = 'RegulatorRegistrationDecision'
                            AND sub.Decision = 'Cancelled'
                    )
        FROM rpd.SubmissionEvents upload
        WHERE upload.SubmissionId = @targetSubmissionId
        AND upload.Type = 'Submitted'
        AND ( (@FileId is null) OR (upload.FileId = @FileId))
        AND (
                (ISNULL(@BeforeProducerSubmits,0) = 1 AND NOT EXISTS (
                    SELECT 1
                    FROM rpd.SubmissionEvents submitted
                    WHERE submitted.SubmissionId = upload.SubmissionId
                    AND submitted.Type = 'RegistrationApplicationSubmitted'
                    AND submitted.Created > upload.Created
                ))
                OR
                ((ISNULL(@BeforeProducerSubmits,0) = 0 OR @FileId IS NULL) AND EXISTS (
                    SELECT 1
                    FROM rpd.SubmissionEvents submitted
                    WHERE submitted.SubmissionId = upload.SubmissionId
                    AND submitted.Type = 'RegistrationApplicationSubmitted'
                    AND submitted.Created > upload.Created
                ))
            )
        ORDER BY upload.Created DESC;

    --select @targetFileId as TargetFileId, @FirstSubmittedOn as FirstSubmittedOn, @SubmittedOn as SubmittedOn, @CancelledOn as CancelledOn, @RegistrationDecisionDate as RegistrationDecisionDate;

        -- Get Submission Meta-data - registrationdates, ComplianceScheme status etc
        SELECT
            @OrganisationUUIDForSubmission = O.ExternalId 
            ,@CSOReferenceNumber = O.ReferenceNumber 
            ,@IsComplianceScheme = CASE WHEN S.ComplianceSchemeId IS NOT NULL THEN 1 ELSE 0 END
            ,@ComplianceSchemeId = S.ComplianceSchemeId
            ,@SubmissionPeriod = S.SubmissionPeriod
        FROM
            [rpd].[Submissions] AS S
            INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
        WHERE S.SubmissionId = @targetSubmissionId;

        --SELECT
        --    @OrganisationUUIDForSubmission as SubmittedOrgExternalId 
        --    ,@CSOReferenceNumber as CSOOrgRefNum
        --    ,@IsComplianceScheme
        --    ,@ComplianceSchemeId as CompSchemeId
        --    ,@SubmissionPeriod as SubmissionPeriod

        if (@targetFileId IS NOT NULL) 
        BEGIN
            if @IsComplianceScheme = 1
            BEGIN
                WITH ComplianceSchemeMembersCTE as (
                    select csm.*
                        ,@SubmittedOn as SubmittedOn
                        ,CASE WHEN @RegistrationDecisionDate IS NULL THEN 1
                                WHEN csm.EarliestSubmissionDate <= @RegistrationDecisionDate AND csm.joiner_date is null THEN 1
                                WHEN csm.joiner_date is null THEN 1
                                ELSE 0 END
                            AS IsOriginal
                        ,CASE WHEN @RegistrationDecisionDate IS NULL THEN 0
                                WHEN csm.EarliestSubmissionDate <= @RegistrationDecisionDate THEN 0
                                WHEN ( csm.EarliestSubmissionDate > @RegistrationDecisionDate and csm.joiner_date is not null) THEN 1
                                WHEN ( csm.EarliestSubmissionDate > @RegistrationDecisionDate and csm.joiner_date is null) THEN 0
                            END as IsNewJoiner
                    from dbo.v_ComplianceSchemeMembers_resub csm
                    where csm.FileId = @targetFileId
                )
                ,CompliancePaycalCTE
                AS
                (
                    SELECT
                        CSOReference
                        ,csm.CSOExternalId
                        ,csm.ComplianceSchemeId
                        ,@FirstSubmittedOn as FirstSubmittedOn
                        ,csm.ReferenceNumber
                        ,csm.ExternalId
                        ,csm.submissionperiod
                        ,csm.OrganisationName
                        ,csm.RelevantYear
                        ,csm.SubmittedDate
                        ,csm.EarliestSubmissionDate
                        ,csm.IsOriginal
                        ,csm.IsNewJoiner
                        ,ppp.ProducerSize
                        ,csm.leaver_code
                        ,csm.leaver_date
                        ,csm.joiner_date
                        ,csm.organisation_change_reason
                        ,csm.FileId
                        ,csm.FileName
                        ,ppp.IsOnlineMarketPlace
                        ,ppp.NumberOfSubsidiaries
                        ,ppp.OnlineMarketPlaceSubsidiaries as NumberOfSubsidiariesBeingOnlineMarketPlace
                    FROM
                        ComplianceSchemeMembersCTE csm
                        INNER JOIN dbo.t_ProducerPayCalParameters_resub ppp ON ppp.OrganisationId = csm.ReferenceNumber
                                    AND ppp.FileName = csm.FileName
                )
                INSERT INTO #PaycalParams (
                    SubmissionId,
                    IsCSO, CSOReference, CSOExternalId, ComplianceSchemeId, SubmissionPeriod, FirstSubmittedOn, 
                    ReferenceNumber, ExternalId,
                    OrganisationName, IsOriginal, IsNewJoiner, 
                    RelevantYear, SubmittedDate, EarliestSubmissionDate,
                    OrganisationSize, LeaverCode, LeaverDate, JoinerDate, OrganisationChangeReason,
                    IsOnlineMarketPlace, NumberOfSubsidiaries, NumberOfSubsidiariesBeingOnlineMarketPlace,
                    FileName, FileId )
                SELECT  CAST(@targetSubmissionId AS uniqueidentifier) as SubmissionId,
                        CAST(1 as BIT) as IsCSO
                        ,CSOReference
                        ,CAST(CSOExternalId AS uniqueidentifier) as CSOExternalId
                        ,CAST(ComplianceSchemeId as uniqueidentifier) as ComplianceSchemeId
                        ,submissionperiod
                        ,FirstSubmittedOn
                        ,ReferenceNumber
                        ,ExternalId
                        ,CAST(OrganisationName as nvarchar(250)) as OrganisationName
                        ,CAST(IsOriginal as Bit) as IsOriginal
                        ,CAST(IsNewJoiner as Bit) as IsNewJoiner
                        ,CAST(RelevantYear as INT) as RelevantYear
                        ,CAST(SubmittedDate as datetime2(7)) as SubmittedDate
                        ,CAST(EarliestSubmissionDate as datetime2(7)) as EarliestSubmissionDate
                        ,CAST(CASE WHEN ProducerSize = 'small' THEN 'S'
                            WHEN ProducerSize = 'large' THEN 'L'
                            ELSE NULL
                        END as CHAR) as ProducerSize
                        ,CAST(leaver_code as nvarchar(20)) as LeaverCode
                        ,CAST(leaver_date as nvarchar(20)) as LeaverDate
                        ,CAST(joiner_date as nvarchar(20)) as JoinerDate
                        ,CAST(organisation_change_reason as nvarchar(20)) as OrganisationChangeReason
                        ,CAST(IsOnlineMarketPlace as BIT) as IsOnlineMarketPlace
                        ,CAST(NumberOfSubsidiaries as INT) as NumberOfSubsidiaries
                        ,CAST(NumberOfSubsidiariesBeingOnlineMarketPlace as INT) as NumberOfSubsidiariesBeingOnlineMarketPlace
                        ,CAST(FileName as UNIQUEIDENTIFIER) as FileName
                        ,CAST(FileId as UNIQUEIDENTIFIER) as FileId
                FROM CompliancePaycalCTE
            END
            
            if @IsComplianceScheme = 0
            BEGIN
                WITH ProducerPaycalParametersCTE AS (
                    select o.Name as OrgName,
                        OrganisationExternalId,
                        OrganisationId as OrgRefNum,
                        FileName,
                        FileId,
                        RegistrationSetId,
                        IsOnlineMarketPlace,
                        NumberOfSubsidiaries,
                        OnlineMarketPlaceSubsidiaries,
                        OrganisationSize,
                        ProducerSize,
                        ppp.NationId
                    from dbo.t_ProducerPaycalParameters_resub ppp
                    inner join rpd.Organisations o on o.ExternalId = ppp.OrganisationExternalId
                    where ppp.FileId = @targetFileId
                )
                INSERT INTO #PaycalParams (
                    SubmissionId,
                    IsCSO, CSOReference, CSOExternalId, ComplianceSchemeId, SubmissionPeriod, FirstSubmittedOn,
                    ReferenceNumber, ExternalId,
                    OrganisationName, RelevantYear, SubmittedDate, EarliestSubmissionDate,
                    OrganisationSize, LeaverCode, LeaverDate, JoinerDate, OrganisationChangeReason,
                    IsOnlineMarketPlace, NumberOfSubsidiaries, NumberOfSubsidiariesBeingOnlineMarketPlace,
                    FileName, FileId )
                SELECT  CAST(@targetSubmissionId AS uniqueidentifier) as SubmissionId,
                        CAST(0 as BIT) as IsCSO, null as CSOReference, null as CSOExternalId, null as ComplianceSchemeId, @SubmissionPeriod as SubmissionPeriod, @FirstSubmittedOn as FirstSubmittedOn,
                        OrgRefNum as ReferenceNumber, OrganisationExternalId as ExternalId,
                        CAST(OrgName as NVARCHAR(250)) as OrganisationName, CONVERT(int, RIGHT(RTRIM(@SubmissionPeriod), 4)) as RelevantYear, CAST(@SubmittedOn as datetime2(7)) as SubmittedDate, CAST(@FirstSubmittedOn as datetime2(7)) as EarliestSubmissionDate,
                        CAsT(OrganisationSize as VARCHAR(1)) as OrganisationSize, null as LeaverCode, null as LeaverDate, null as JoinerDate, null as OrganisationChangeReason,
                        CAST(IsOnlineMarketplace as bit) as IsOnlineMarketplace, CAST(NumberOfSubsidiaries as INT) as NumberOfSubsidiaries, CAST(OnlineMarketPlaceSubsidiaries as INT) as NumberOfSubsidiariesBeingOnlineMarketPlace,
                        CAST(FileName as UNIQUEIDENTIFIER) as FileName, CAST(FileId as UNIQUEIDENTIFIER) as FileId
                FROM ProducerPaycalParametersCTE
            END
        END
        ELSE
        BEGIN
            print 'no file id';
        END
        select * from #PaycalParams;
    END
END
GO
