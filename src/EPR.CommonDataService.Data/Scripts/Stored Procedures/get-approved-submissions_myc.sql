-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetApprovedSubmissionsMyc]'))
DROP PROCEDURE [dbo].[sp_GetApprovedSubmissionsMyc];
GO


CREATE PROC [dbo].[sp_GetApprovedSubmissionsMyc]
  @PeriodYear VARCHAR(4)
, @IncludePackagingTypes [VARCHAR](MAX)
, @IncludePackagingMaterials [VARCHAR](MAX)
AS
BEGIN

	DECLARE @start_dt datetime;
	DECLARE @batch_id INT;
	DECLARE @cnt int;

	select @batch_id  = ISNULL(max(batch_id),0)+1 from [dbo].[batch_log]
	set @start_dt = getdate();

    BEGIN
        SET NOCOUNT ON;

        declare @DirectRegistrantType nvarchar(50) = 'DirectRegistrant';
        declare @ComplianceSchemeType nvarchar(50) = 'ComplianceScheme';

        declare @Delimiter char(1) = ',';

        declare @RelevantYear varchar(4) = cast(cast(@PeriodYear as int) + 1 as varchar);
        DECLARE @DaysInYear int = datediff(day, datefromparts(convert(int, @RelevantYear), 1, 1), datefromparts(convert(int, @RelevantYear) + 1, 1, 1));

        with
        IncludeOrganisationSizeTable as (
          select value as OrganisationSize from string_split('L', @Delimiter)
        ),

        IncludePackagingMaterialsTable as (
          select value as PackagingMaterials from string_split(@IncludePackagingMaterials, @Delimiter)
        ),

        IncludePackagingTypesTable as (
          select value as PackagingType from string_split(@IncludePackagingTypes, @Delimiter)
        ),

        P1P4Table as (
          select concat(@PeriodYear, '-P1') as period
          union
          select concat(@PeriodYear, '-P4') as period
        ),

        P2P4Table as (
          select concat(@PeriodYear, '-P2') as period
          union
          select concat(@PeriodYear, '-P4') as period
        ),
        P3P4Table as (
          select concat(@PeriodYear, '-P3') as period
          union
          select concat(@PeriodYear, '-P4') as period
        ),

        -- For 2025+
        H1H2Table as (
          select concat(@PeriodYear, '-H1') as period
          union
          select concat(@PeriodYear, '-H2') as period
        ),

        AllPeriodsTable as (
          select * from P1P4Table where @PeriodYear = '2024'
          union
          select * from P2P4Table where @PeriodYear = '2024'
          union
          select * from P3P4Table where @PeriodYear = '2024'
          union
          select * from H1H2Table where @PeriodYear > '2024'
        ),

        -- First get the org obligation:
        RegistrationsWithObligations as (
          select
            organisation_id
          , subsidiary_id
          , organisation_name
          , trading_name
          , status_code  as leaver_code
          , leaver_date
          , joiner_date
          , submitter_id
          , submission_period_year
          , obligation_status
          , num_days_obligated
          , error_code
          , coalesce(subsidiary_id, cast(organisation_id as nvarchar(50))) as producer_id
          from dbo.t_producer_obligation_determination
          where submission_period_year = @RelevantYear
        ),

        LatestAcceptedPomFiles as (
          select
            FileId
          , SubmissionId
          , Created
          from (
            select
              FileId
            , SubmissionId
            , Created
            , row_number() over (partition by SubmissionId order by Created desc) as rn
            from rpd.SubmissionEvents
            where Type     = 'RegulatorPoMDecision'
              and Decision = 'Accepted'
              and FileId   is not null
          ) a
          where a.rn = 1
        ),

        LatestAcceptedPoms as (
          select * from (
            select distinct
              latest.SubmissionId
            , latest.FileId
            , cfm.FileName
            , cfm.submissionperiod as submission_period_desc
            , latest.created
            --ST005 Updated logic to determine the latest accepted file submission with data for a given organisation
            , row_number() over(
                partition by
                  p.organisation_id,
                  nullif(trim(p.subsidiary_id), ''), -- important - sometimes is blank, sometimes is null
                  p.submission_period,
                  coalesce(cfm.ComplianceSchemeId, o.ExternalId)  -- keep alternative submissions... (especially submitter_type)
                order by latest.created desc
              ) as rn
            , p.organisation_id
            , nullif(trim(p.subsidiary_id), '') as subsidiary_id
            , p.submission_period
            , right(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod), 4)        as submission_period_year
            , coalesce(cfm.ComplianceSchemeId, o.ExternalId)                     as submitter_id
            , coalesce(nullif(trim(p.subsidiary_id), ''), cast(p.organisation_id as nvarchar(50))) as producer_id
            , case
                when nullif(trim(cfm.ComplianceSchemeId), '') is null
                then @DirectRegistrantType
                else @ComplianceSchemeType
              end as submitter_type
            from rpd.Pom as p
            inner join rpd.Organisations o
              on  o.ReferenceNumber     = p.organisation_id
              --Excluding soft deleted organisations
              and o.IsDeleted           = 0
              --Restricting to just accepted pom files
            inner join rpd.cosmos_file_metadata as cfm
              on  cfm.FileName          = p.FileName
            inner join LatestAcceptedPomFiles as latest
              on  latest.FileId         = cfm.FileId
            where p.submission_period in (select period from AllPeriodsTable)
              and p.organisation_size in (select OrganisationSize from IncludeOrganisationSizeTable)
          ) a
          where a.rn = 1
        ),

        -- The following is to enure we only consider orgs
        -- which have submitted two periods
        -- Note, P2 and P3 only apply to 2024
        -- TODO it doesn't prevent anyone submitting P1, P2 and P3 (or P0 - seen in test data)
        -- It also doesn't ensure that the two periods were submitted with the same org structure
        OrgsWithBothP1P4 as (
          select producer_id, submitter_id
          from LatestAcceptedPoms
          where submission_period in (select period from P1P4Table)
          group by producer_id, submitter_id
          having count(distinct submission_period) = (select count(*) from P1P4Table)
        ),
        OrgsWithBothP2P4 as (
          select producer_id, submitter_id
          from LatestAcceptedPoms
          where submission_period in (select period from P2P4Table)
          group by producer_id, submitter_id
          having count(distinct submission_period) = (select count(*) from P2P4Table)
        ),
        OrgsWithBothP3P4 as (
          select producer_id, submitter_id
          from LatestAcceptedPoms
          where submission_period in (select period from P3P4Table)
          group by producer_id, submitter_id
          having count(distinct submission_period) = (select count(*) from P3P4Table)
        ),
        OrgsWithBothH1H2 as (
          select producer_id, submitter_id
          from LatestAcceptedPoms
          where submission_period in (select period from H1H2Table)
          group by producer_id, submitter_id
          having count(distinct submission_period) = (select count(*) from H1H2Table)
        ),
        OrgsWith2Periods as (
          select producer_id, submitter_id from OrgsWithBothP1P4 where @PeriodYear = '2024'
          union
          select producer_id, submitter_id from OrgsWithBothP2P4 where @PeriodYear = '2024'
          union
          select producer_id, submitter_id from OrgsWithBothP3P4 where @PeriodYear = '2024'
          union
          select producer_id, submitter_id from OrgsWithBothH1H2 where @PeriodYear > '2024'
        ),

        LatestAcceptedPomsWith2Period as (
          select pom.*
          from LatestAcceptedPoms pom
          inner join OrgsWith2Periods as periods
            on  pom.producer_id  = periods.producer_id
            and pom.submitter_id = periods.submitter_id
        ),

        -- If a producer has moved (e.g. from/to a holding company) we only use the latest one.
        -- we return org,sub rather than producer for acurate lookup of the pom data later
        LatestForProducer as (
          select
            submission_period
          , organisation_id
          , subsidiary_id
          , submitter_id
          from (
            select
              pom.submission_period
            , pom.organisation_id
            , pom.subsidiary_id
            , pom.submitter_id
            , row_number() over(partition by
                  pom.submission_period
                , pom.producer_id
                order by pom.created desc
              ) as rn
            from LatestAcceptedPomsWith2Period as pom
          ) a
          where a.rn = 1
        ),

        LatestAcceptedPomEntries as (
          select
            lap.organisation_id
          , lap.subsidiary_id
          , lap.submitter_id
          , lap.producer_id
          , prodOrg.ExternalId as external_producer_id
          , lap.submitter_type
          , lap.submission_period
          , lap.submission_period_year
          , pom.packaging_type
          , pom.packaging_material
          , -- TODO could use v_POM which already does this
            case
              when pom.submission_period = '2023-P2' then cast(pom.packaging_material_weight * 1.50     as decimal(16,2))
              when pom.submission_period = '2024-P2' then cast(pom.packaging_material_weight * 2        as decimal(16,2))
              when pom.submission_period = '2024-P3' then cast(pom.packaging_material_weight * 182.0/61 as decimal(16,2)) -- v_POM uses 3 - but 182/61 preserves value previously used (for 182 days in P1, 61 in P3)
              else pom.packaging_material_weight
            end as packaging_material_weight
          , pom.transitional_packaging_units
          from LatestAcceptedPomsWith2Period as lap
          inner join rpd.Organisations prodOrg
            on prodOrg.ReferenceNumber = lap.producer_id
          inner join rpd.Pom as pom
            on  pom.FileName           = lap.FileName
            and coalesce(nullif(trim(pom.subsidiary_id), ''), '') = coalesce(lap.subsidiary_id, '')
            and pom.organisation_id    = lap.organisation_id
        ),

        WithMYC as (
          select
            lap.organisation_id
          , lap.subsidiary_id
          , lap.submitter_id
          , lap.producer_id
          , lap.external_producer_id
          , lap.submitter_type
          , lap.submission_period
          , lap.submission_period_year
          , lap.packaging_type
          , lap.packaging_material
          , case
              when obl.num_days_obligated is not null then
                cast(lap.packaging_material_weight as decimal(16,2)) * cast(obl.num_days_obligated as decimal(16,2)) / cast(@DaysInYear as decimal(16,2))
              else
                cast(lap.packaging_material_weight AS DECIMAL(16,2))
            end as packaging_material_weight
          , lap.transitional_packaging_units
          , obl.num_days_obligated
          from LatestAcceptedPomEntries as lap
          left join RegistrationsWithObligations as obl
            on  lap.organisation_id             = obl.organisation_id
            and coalesce(lap.subsidiary_id, '') = coalesce(obl.subsidiary_id, '')
            and lap.submitter_id                = obl.submitter_id
            and obl.obligation_status           = 'O'
        )

        select
          submission_period_year                 as SubmissionPeriod
        , submitter_type                         as SubmitterType
        , cast(pom.submitter_id as uniqueidentifier) as SubmitterId -- cast added for uppercasing (to match the other query)
        , external_producer_id                   as OrganisationId
        , packaging_material                     as PackagingMaterial
        , cast(
            round(
              (sum(packaging_material_weight) - coalesce(sum(transitional_packaging_units), 0)) / 1000.0,
              0
            ) as int
          )                                      as PackagingMaterialWeight
        from WithMYC as pom
        inner join LatestForProducer as lfp
          on  lfp.submission_period           =  pom.submission_period
          and lfp.organisation_id             =  pom.organisation_id
          and coalesce(lfp.subsidiary_id, '') =  coalesce(pom.subsidiary_id, '')
          and lfp.submitter_id                =  pom.submitter_id
        where packaging_material              in (select * from IncludePackagingMaterialsTable)
          and packaging_type                  in (select * from IncludePackagingTypesTable)
        group by
          submission_period_year
        , pom.submitter_id
        , submitter_type
        , external_producer_id
        , packaging_material

    END

	INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
	select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'dbo.sp_GetApprovedSubmissionsMyc','', NULL, @start_dt, getdate(), '',@batch_id
END
