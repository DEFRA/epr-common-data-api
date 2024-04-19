SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP VIEW IF EXISTS [apps].[v_Large_Producers]
GO

CREATE VIEW [apps].[v_Large_Producers]
AS 
	select 
		RPD_Organisation_ID,		submission_period,		Compliance_scheme,		Companies_House_number,		Subsidiary_ID,		Organisation_name,
		Trading_name,		Address_line_1,		Address_line_2,		Address_line_3,		Address_line_4,		Town,		County,		Country,
		Postcode,		ProducerNation,		ProducerNationId,		ComplianceSchemeNation,		ComplianceSchemeNationId,		ProducerId,
		Environmental_regulator,		Compliance_scheme_regulator,		Reporting_year
	from
	(
		select *, Row_number() over(Partition by RPD_Organisation_ID, Subsidiary_ID order by SubmittedDateTime desc) as rn
		from
		(	
	
					SELECT DISTINCT *
					FROM (
								SELECT DISTINCT
									p.organisation_id AS 'RPD_Organisation_ID'
									, '' AS 'submission_period'
									, cs.Name AS 'Compliance_scheme'
									, COALESCE( v.companies_house_number, prr.CompaniesHouseNumber) AS 'Companies_House_number'
									, COALESCE(v.subsidiary_id, p.subsidiary_id, '') AS 'Subsidiary_ID'
									, COALESCE( v.organisation_name, prr.Name  ) AS 'Organisation_name'
									, COALESCE( v.Trading_Name, prr.TradingName  ) AS 'Trading_name'

									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_addr_line1,'') 
										else TRIM( ISNULL(prr.BuildingName,'') + ' ' +ISNULL(prr.BuildingNumber,'') ) 
											end as 'Address_line_1'
									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_addr_line2,'') 
										else ISNULL(prr.Street,'') 
											end as 'Address_line_2'
									, '' as 'Address_line_3'
									, '' as 'Address_line_4'
									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_city,'') 
										else ISNULL(prr.Town,'') 
											end as 'Town'
									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_addr_county,'') 
										else ISNULL(prr.County,'') 
											end as 'County'
									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_addr_country,'') 
										else ISNULL(prr.Country,'') 
											end as 'Country'									
									, case 
										when v.organisation_id is not null 
											then ISNULL(v.registered_addr_postcode,'') 
										else ISNULL(prr.Postcode,'') 
											end as 'Postcode'
									, producernation.Name AS ProducerNation
									, producernation.Id AS ProducerNationId
									, csnation.Name AS ComplianceSchemeNation
									, csnation.Id AS ComplianceSchemeNationId
									, prr.ReferenceNumber AS ProducerId
									, (CASE producernation.Id
										WHEN 1 THEN 'Environment Agency (England)'
										WHEN 2 THEN 'Northern Ireland Environment Agency'
										WHEN 3 THEN 'Scottish Environment Protection Agency'
										WHEN 4 THEN 'Natural Resources Wales'
									  END) As 'Environmental_regulator'
									, (CASE csnation.Id
										WHEN 1 THEN 'Environment Agency (England)'
										WHEN 2 THEN 'Northern Ireland Environment Agency'
										WHEN 3 THEN 'Scottish Environment Protection Agency'
										WHEN 4 THEN 'Natural Resources Wales'
									  END) As 'Compliance_scheme_regulator'
									, 2023 as Reporting_year
									,m.created SubmittedDateTime
								FROM [rpd].[Pom] p
								left join [dbo].[v_registration_latest] v
									ON p.Organisation_id = v.organisation_id
										and isnull(p.subsidiary_id,'') = isnull(v.subsidiary_id,'')
								left JOIN apps.get_latest_pom_file_submitted meta
									ON p.FileName = meta.FileName
								LEFT JOIN rpd.ComplianceSchemes cs
									ON meta.ComplianceSchemeId = cs.ExternalId
								left JOIN rpd.Organisations prr
									ON p.organisation_id = prr.ReferenceNumber
								LEFT JOIN rpd.Nations producernation   
									ON prr.NationId = producernation.Id
								LEFT JOIN rpd.Nations csnation
									ON cs.NationId = csnation.Id
								left join [dbo].[v_cosmos_file_metadata] m
									on m.FileName = p.FileName
								left JOIN (SELECT FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus
												FROM t_rpd_data_SECURITY_FIX
												GROUP BY FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus) e_status
									ON e_status.FromOrganisation_ReferenceNumber = p.organisation_id
							where  p.organisation_size = 'L'
								   AND (cs.IsDeleted = 0 OR cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
								   AND (prr.isdeleted = 0 OR prr.isdeleted IS NULL)
								   AND e_status.EnrolmentStatuses_EnrolmentStatus <> 'Rejected'
								   AND (prr.IsComplianceScheme = 0 OR prr.IsComplianceScheme IS NULL)
						) pom_start
					UNION
 					SELECT DISTINCT * 
					FROM (
							SELECT DISTINCT
								cd.organisation_id AS 'RPD_Organisation_ID'
								, '' AS 'submission_period'
								, cs.Name AS 'Compliance_scheme'
								, COALESCE( cd.companies_house_number, pr.CompaniesHouseNumber) AS 'Companies_House_number'
								, COALESCE( cd.subsidiary_id, '') AS 'Subsidiary_ID'
								, COALESCE( cd.organisation_name , pr.Name ) AS 'Organisation_name'
								, COALESCE( cd.Trading_Name , pr.TradingName ) AS 'Trading_name'
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_addr_line1,'') 
									else TRIM( ISNULL(pr.BuildingName,'') + ' ' +ISNULL(pr.BuildingNumber,'') )
										end as 'Address_line_1'									
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_addr_line2,'') 
									else ISNULL(pr.Street,'') 
										end as 'Address_line_2'								
								, '' as 'Address_line_3'
								, '' as 'Address_line_4'
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_city,'') 
									else ISNULL(pr.Town,'') 
										end as 'Town'
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_addr_county,'') 
									else ISNULL(pr.County,'') 
										end as 'County'
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_addr_country,'') 
									else ISNULL(pr.Country,'') 
										end as 'Country'
								, case 
									when cd.organisation_id is not null 
										then ISNULL(cd.registered_addr_postcode,'') 
									else ISNULL(pr.Postcode,'') 
										end as 'Postcode'
								, producernation.Name AS ProducerNation
								, producernation.Id AS ProducerNationId
								, csnation.Name AS ComplianceSchemeNation
								, csnation.Id AS ComplianceSchemeNationId
								, pr.ReferenceNumber AS ProducerId
								, (CASE producernation.Id
									WHEN 1 THEN 'Environment Agency (England)'
									WHEN 2 THEN 'Northern Ireland Environment Agency'
									WHEN 3 THEN 'Scottish Environment Protection Agency'
									WHEN 4 THEN 'Natural Resources Wales'
									END) As 'Environmental_regulator'
								, (CASE csnation.Id
									WHEN 1 THEN 'Environment Agency (England)'
									WHEN 2 THEN 'Northern Ireland Environment Agency'
									WHEN 3 THEN 'Scottish Environment Protection Agency'
									WHEN 4 THEN 'Natural Resources Wales'
									END) As 'Compliance_scheme_regulator'
								, 2023 as Reporting_year
								,m.created SubmittedDateTime
							FROM [rpd].[CompanyDetails] cd
 							left JOIN apps.get_latest_org_file_submitted meta
								ON cd.FileName = meta.FileName
							LEFT JOIN rpd.ComplianceSchemes cs
								ON meta.ComplianceSchemeId = cs.ExternalId
							left JOIN rpd.Organisations pr
								ON cd.organisation_id = pr.ReferenceNumber
							LEFT JOIN rpd.Nations producernation  ---> 'LEFT JOIN instead of JOIN to take data even if enrolment data doesn't exist' (should use it)
								ON pr.NationId = producernation.Id
							LEFT JOIN rpd.Nations csnation
								ON cs.NationId = csnation.Id
							left JOIN [dbo].[v_registration_latest] rl
								ON cd.organisation_id = rl.organisation_id-- AND rl.created = meta.created
								and isnull(cd.subsidiary_id,'') = isnull(rl.subsidiary_id,'')
							left JOIN (SELECT FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus
									FROM t_rpd_data_SECURITY_FIX
									GROUP BY FromOrganisation_ReferenceNumber, EnrolmentStatuses_EnrolmentStatus) e_status
								ON e_status.FromOrganisation_ReferenceNumber = cd.organisation_id
 							left join [dbo].[v_cosmos_file_metadata] m
								on m.FileName = cd.FileName
								WHERE (cs.IsDeleted = 0 OR cs.IsDeleted IS NULL)  ---> If only company-details file is submitted cs.IsDeleted would be NULL
									AND (pr.isdeleted = 0 OR pr.isdeleted IS NULL)
									AND e_status.EnrolmentStatuses_EnrolmentStatus <> 'Rejected'
									AND (pr.IsComplianceScheme = 0 OR pr.IsComplianceScheme IS NULL)
						) reg_start
		) A
	) B
	where B.rn = 1;
GO
