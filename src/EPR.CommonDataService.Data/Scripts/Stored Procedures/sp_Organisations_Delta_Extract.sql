IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_Organisations_Delta_Extract]'))
DROP PROCEDURE [dbo].[sp_Organisations_Delta_Extract];
GO

CREATE  PROC [dbo].[sp_Organisations_Delta_Extract] @From_Date [Datetime],@To_Date [Datetime] AS
BEGIN
 -- Disable row count for performance
    SET NOCOUNT ON;
	
/****************************************************************************************************************************
	History:

	Updated: 2025-05-27:	ST001:  Ticket - 550045:Add in subsidiary is null check when finding the latest file/record to ensure only retrieving parent org details e.g. OrganisationName
													Add in coalesce on the CS buildingname to then use building number to improve Address Data Quality for Compliance Schemes
													Remove DR to CS Event Code from query
    Updated: 2025-12-02:    REEX-36:               :Used [dbo].[sp_PRN_Delta_Extract] as a template
                                                   :Removed submissionPeriodYear filter
                                                   :Removed reportingYear column from lastest_record
                                                   :Updated the SubmissionPeriodYear field to not use reverse functions
                                                   :Updated ActiveCompliaceScheme to include a SubmissionPeriodYear
                                                   :Added Distincts to DR Registered and DR Deleted
                                                   :Changed Unions to Union Alls
                                                   :Added SubmissionPeriodYear as registrationYear to all DR Registered, DR Deleted and CS Added
                                                   :Added registrationYear to use the year of lastupdatedon when SubmissionPeriodYear is NULL to CS Deleted
                                                   :Updated OrganisationType to either be S for compliance scheme or DP for large companies
                                                   :Updated status to be either Registered or Deleted

******************************************************************************************************************************/
WITH latest_record AS(
select
    OrganisationId
    ,ReferenceNumber
    ,SubmissionPeriodYear
    ,Submission_time
    ,ComplianceSchemeId
    ,[FileName]
    ,CS_Name
    ,SubmittedBy
    ,cd_filename
    ,organisation_size
    ,OrganisationName
    ,TradingName
    ,AddressLine1
    ,AddressLine2
    ,Town
    ,County
    ,Country
    ,Postcode
    ,subsidiary_id
	,row_number() over(partition by OrganisationId, ReferenceNumber order by Submission_time desc) as Last_submission
		from 
		(
				select distinct o.id as OrganisationId, cd.organisation_id as ReferenceNumber
					,'20'+RIGHT(rtrim(cfm.SubmissionPeriod),2) as SubmissionPeriodYear
					, CONVERT(DATETIME,substring(cfm.Created,1,23)) as Submission_time
					, cs.id as ComplianceSchemeId
					, cfm.FileName
					, cs.Name as 'CS_Name'
					, case when cs.id is NULL then 'DP' else 'CS' end as 'SubmittedBy'
					, cd.FileName as cd_filename
					, cd.organisation_size
					,cd.[organisation_name] as OrganisationName,
					cd.[trading_name] TradingName,
					cd.[registered_addr_line1] as AddressLine1, 
					cd.[registered_addr_line2] as AddressLine2,
					cd.[registered_city] as Town,
					cd.[registered_addr_county] as County,
					cd.[registered_addr_country] as Country,
					cd.[registered_addr_postcode] as Postcode,
					cd.subsidiary_id 
			from [rpd].[CompanyDetails] cd
			left join rpd.Organisations o on o.ReferenceNumber = cd.organisation_id
			left join [rpd].[cosmos_file_metadata] cfm on cfm.FileName = cd.FileName
			left join [rpd].[ComplianceSchemes] cs on cs.ExternalId = cfm.ComplianceSchemeId	
		) A
		WHERE subsidiary_id is null 
		--ORDER BY ReferenceNumber asc, Last_submission asc)
)

,Active_ComplianceScheme  
AS (
    select
        ComplianceSchemeId
        ,submission_time
        ,SubmissionPeriodYear
    FROM
        (
            SELECT
                cs.id as ComplianceSchemeId
                ,CONVERT(DATETIME,substring(cfm2.Created,1,23)) as submission_time
                ,'20'+RIGHT(rtrim(cfm2.SubmissionPeriod),2) AS SubmissionPeriodYear
                ,row_number() over(partition by cs.id order by CONVERT(DATETIME,substring(cfm2.Created,1,23)) desc) as Last_submission
            from
                rpd.cosmos_file_metadata cfm2
                left join [rpd].[ComplianceSchemes] cs on cs.ExternalId = cfm2.ComplianceSchemeId	
            where
                cs.id is not null
                and FileType = 'CompanyDetails'
        ) AS A
    WHERE
        Last_submission = 1
  )


--DR Registered--
select
distinct
l.OrganisationName
,l.TradingName
,'DP' as OrganisationType
,e.CompaniesHouseNumber as CompaniesHouseNumber
-- e.referencenumber as organisationId,
,l.AddressLine1
,l.AddressLine2
,l.Town
,l.County
,l.Country
,l.Postcode
,e.externalid as pEPRID
,'Registered' as status
,N.Name as 'BusinessCountry'
,l.Submission_time as UpdatedDateTime
,l.SubmissionPeriodYear as registrationYear
from [rpd].[Organisations] e  
INNER JOIN latest_record l on e.referencenumber =l.referencenumber and e.isdeleted=0 and e.iscompliancescheme=0 
and l.SubmittedBy = 'DP' AND l.Last_submission = 1 AND ISNULL(l.organisation_size, 'L') ='L'
--ADDED IN DUE TO FRONT END NOT VALIDATING SUBMISSIONS
and l.referencenumber IS NOT NULL
LEFT JOIN rpd.Nations N on N.Id = e.NationId
where l.Submission_time between @From_Date and @To_Date


UNION ALL


-- DR DELETED--
select
distinct
l.OrganisationName
,l.TradingName
,'DP' as OrganisationType
,e.CompaniesHouseNumber as CompaniesHouseNumber
-- e.referencenumber as organisationId,
,l.AddressLine1 
,l.AddressLine2
,l.Town
,l.County
,l.Country
,l.Postcode
,e.externalid as pEPRID
--'DR Deleted' as status,
,'Deleted' as status
,N.Name as 'BusinessCountry'
,CAST(CONVERT(datetimeoffset, e.lastupdatedon) as datetime) as UpdatedDateTime
,l.SubmissionPeriodYear as registrationYear
from [rpd].[Organisations] e 
INNER JOIN latest_record l on e.referencenumber =l.referencenumber and e.isdeleted=1 and e.iscompliancescheme=0 
and l.SubmittedBy = 'DP' AND l.Last_submission = 1 AND ISNULL(l.organisation_size, 'L') ='L'
LEFT JOIN rpd.Nations N on N.Id = e.NationId
where e.isdeleted=1 AND e.iscompliancescheme=0
and  CAST(CONVERT(datetimeoffset, e.lastupdatedon) as datetime) between @From_Date and @To_Date




union all
-- Compliance Scheme Added
select 
distinct
o.name as OrganisationName
,cs.name as TradingName
,'CS' as OrganisationType
,o.CompaniesHouseNumber
-- o.referencenumber as organisationId ,
,COALESCE(o.BuildingName, o.BuildingNumber) as AddressLine1
,o.Street as AddressLine2
,o.Town
,o.County
,o.Country
,o.Postcode
,cs.externalid as pEPRID
,'Registered' as status
,N.Name as 'BusinessCountry'
,acs.Submission_time as UpdatedDateTime
,acs.SubmissionPeriodYear as registrationYear
from [rpd].[Organisations] o  
join [rpd].[OrganisationsConnections] oc on o.id=oc.toorganisationid   and o.iscompliancescheme=1 and o.isdeleted=0 and oc.isdeleted=0
left join [rpd].[SelectedSchemes] ss on ss.OrganisationConnectionid=oc.ID and ss.isdeleted=0
left join [rpd].[ComplianceSchemes] cs on ss.ComplianceSchemeid = cs.id and cs.isdeleted=0
left join [rpd].[ComplianceSchemes] cs_not_sub on cs_not_sub.CompaniesHouseNumber = o.CompaniesHouseNumber and cs_not_sub.isdeleted=0
INNER JOIN Active_ComplianceScheme acs ON cs.id = acs.ComplianceSchemeId
LEFT JOIN rpd.Nations N on N.Id = cs.NationId
where 
--The following load criteria means each time a CS makes a file submission it would come through
--But the upsert would handle this and simply update NPWD with existing information, or updated information if say address details have been changed/improved--
CAST(CONVERT(datetimeoffset, acs.Submission_time) as datetime) between @From_Date and @To_Date



union all
-- Compliance Scheme Deleted
select 
distinct
o.name as OrganisationName
,cs.name as TradingName
,'CS' as OrganisationType
,o.CompaniesHouseNumber
-- o.referencenumber as organisationId ,
,o.BuildingName as AddressLine1
,o.Street as AddressLine2
,o.Town
,o.County
,o.Country
,o.Postcode
,cs.externalid as pEPRID
,'Deleted' as status
,N.Name as 'BusinessCountry'
,CAST(CONVERT(datetimeoffset, cs.lastupdatedon) as datetime) as UpdatedDateTime
,acs.SubmissionPeriodYear as registrationYear
from [rpd].[Organisations] o  
join [rpd].[OrganisationsConnections] oc on o.id=oc.toorganisationid   and o.iscompliancescheme=1
left join [rpd].[SelectedSchemes] ss on ss.OrganisationConnectionid=oc.ID
left join [rpd].[ComplianceSchemes] cs on ss.ComplianceSchemeid = cs.id and cs.isdeleted=1
LEFT JOIN rpd.Nations N on N.Id = cs.NationId
INNER JOIN Active_ComplianceScheme acs ON cs.id = acs.ComplianceSchemeId
where CAST(CONVERT(datetimeoffset, cs.lastupdatedon) as datetime)  between @From_Date and @To_Date

END;
GO
