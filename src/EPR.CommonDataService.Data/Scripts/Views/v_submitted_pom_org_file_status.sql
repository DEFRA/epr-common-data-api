CREATE VIEW [dbo].[v_submitted_pom_org_file_status] AS With
/****************************************************************************************************************************
	History:

	Updated: 2025-01-27:	SN001:	Ticket - 500601:	Additional SQL added to v_submitted_pom_org_file_status capture status of records.
	Updated: 2025-01-29:	SN002:	Ticket - 501408:	Additonal SQL required to get correct sumbission date for New Regulator process
														Additonal Type to identify path of data (Reg/Org) JourneyType
															1= Organisation/Existing, 2=New/Reglulator
														Change Status From 'Accpeted' to 'Granted' for New path.
														Rejected to Refused.. Commented out Implementation data TBC

														RegistrationType added to allow IF/CASE statement logic in POwerBI
														regulatorbrandwithpartner so new records show NULL not Pending.
	Updated: 2025-02-06:	YM001:	Ticket - 506054		Rejected to Refused Status change registration file for relevant_year 2025 onwards
	Updated: 2025-02-11:	YM002:	Ticket - 506055		Changing the decision as Pending from null for the 2nd submission under the ticket 506055
	Updated: 2025-02-18:	SN003:	Ticket - 510914		Remove values Comment, DecisionDate, User values for RegulatorRegistration 'Pending/Upload' rows
	Updated: 2025-03-19:	PM004:	Ticket - 512853		Bring the Registration file status as 'Uploaded' if not fully submitted in front end. This is the status before pending.
	Updated: 2025-03-24:	SN005:	Ticket - 520206		Add Application/App Reference Number to be passed to output for display on Power BI Report
	Updated: 2025-04-03:	RM006:	Ticket - 527578		Add registrationreferencenumber to be passed on to v_public_register_all_producers
	Updated: 2025-04-24:	PM006:	Ticket - 543160		Rewritten to handle status as per the ticekt 543160
	Updated: 2025-05-14:	PM008:	Ticket - 552117		Adding app submitted ts for the ticket 552117
	Updated: 2025-06-17:	PM009:	Ticket - 548534		POM resubmission fix - updated comments
	Updated: 2025-08-08:	PM010:	Ticket - 599145		Picking first submitted records by fileid to find if it is resubmitted or not
	Updated: 2026-07-01:	CL001:	Ticket - ECV-568		Propagate a Cancelled Registration decision (original or any resubmission) to every
															submission with the same SubmissionId, regardless of order. Cancellation is final and
															only applies to Registration submissions.
******************************************************************************************************************************/
--SQL to find resubmitted POM file ids
submitted_file_list as
(
	select distinct SubmissionId, FileId, CONVERT(DATETIME,substring(Created,1,23)) as file_submitted_ts from rpd.SubmissionEvents where Type in ('Submitted')
	and Fileid is not null
	and (IsResubmission is null or IsResubmission = 0)
),
first_PackagingResubmissionReferenceNumberCreated_entry as (
	select distinct SubmissionId, min(CONVERT(DATETIME,substring(Created,1,23))) as first_PackagingResubmissionReferenceNumberCreated_ts
	from rpd.SubmissionEvents where Type in ('PackagingResubmissionReferenceNumberCreated')
	group by SubmissionId
),
resubmitted_POM_list as
(
select distinct SubmissionId, FileId, IsResubmission as POM_resubmission_identifier, NULL as min_first_PackagingResubmissionReferenceNumberCreated_ts
from rpd.SubmissionEvents
where Type in ('Submitted')
and Fileid is not null
and IsResubmission = 1
 union
select sfl.SubmissionId, sfl.FileId, 1 as POM_resubmission_identifier, min(ent.first_PackagingResubmissionReferenceNumberCreated_ts) as min_first_PackagingResubmissionReferenceNumberCreated_ts
from submitted_file_list sfl
inner join first_PackagingResubmissionReferenceNumberCreated_entry ent
	on sfl.SubmissionId = ent.SubmissionId
	and sfl.file_submitted_ts >= ent.first_PackagingResubmissionReferenceNumberCreated_ts
group by sfl.SubmissionId, sfl.FileId
),

--Sub query to find the resubmission records
--with
resubmission_ids as
(
	select IsResubmission_identifier, Fileid
	from
	(
		select distinct ISNULL(IsResubmission,0) as IsResubmission_identifier, Fileid
			, row_number() over(partition by Fileid order by CONVERT(DATETIME,substring(Created,1,23))) resubmission_ids_submitted_rank
		from rpd.SubmissionEvents
		where Type = 'Submitted'
		and Fileid is not null --and IsResubmission is not null
	) A
	where resubmission_ids_submitted_rank = 1
)
--select * from resubmission_ids where Fileid = '665a9626-4f3b-4e5b-b966-423825d0848a'
,


--Find file id for the records that are missing fileid in decision records
/*
null_fileid_decision_records as
(
select CONVERT(DATETIME,substring(Created,1,23)) as Created_ts , SubmissionEventId, SubmissionId
 from rpd.SubmissionEvents where type = 'RegulatorRegistrationDecision'
 and fileid is null
 ),
 all_submitted_records as
 (
 select CONVERT(DATETIME,substring(Created,1,23)) as Created_ts, SubmissionEventId, SubmissionId, fileid
 from rpd.SubmissionEvents where type = 'Submitted'
 ),
rank_list as
(
 select D.SubmissionId, D.SubmissionEventId/*, D.Created_ts, S.Created_ts*/, S.fileid as fileid_new
	, row_number() over(partition by D.SubmissionId, D.SubmissionEventId order by S.Created_ts desc) as RN
 from null_fileid_decision_records D
 inner join all_submitted_records S
	on D.SubmissionId = S.SubmissionId
		and D.Created_ts >= S.Created_ts
),
final_result_set as
(
select distinct * from rank_list where RN = 1
),
SubmissionEvents_updated as
(
	select se.*, fs.fileid_new
	from rpd.SubmissionEvents se
	left join final_result_set fs on fs.SubmissionId = se.SubmissionId and fs.SubmissionEventId = se.SubmissionEventId
),
*/

--SET A (Decision records - related to submissions)
resubmission_list_A as
(
	select SE.SubmissionId, 1 as IsResubmitted, min(CONVERT(DATETIME,substring(SE.Created,1,23))) as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.IsResubmission = 1
	group by SE.SubmissionId
),
submission_list_A as
(
	select SE.SubmissionId, 0 as IsResubmitted, NULL as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.SubmissionId not in
		(
			select SubmissionId from resubmission_list_A
		)
),
combined_list_A as
(
	select * from resubmission_list_A
	union
	select * from submission_list_A
),
null_fileid_decision_records_A as
(
	select CONVERT(DATETIME,substring(se.Created,1,23)) as Created_ts , se.SubmissionEventId, se.SubmissionId
	 from rpd.SubmissionEvents se
	 inner join combined_list_A cl on cl.SubmissionId = se.SubmissionId
	 where se.type = 'RegulatorRegistrationDecision'
			and
			(
				cl.IsResubmitted = 0
				or
					(
						cl.IsResubmitted = 1
						and
						CONVERT(DATETIME,substring(se.Created,1,23)) < cl.first_resub_ts
					)
			)
			and se.fileid is null
			--and se.SubmissionId = 'b7efef91-2bda-488b-9ad7-32c310a3087f'
),
 all_submitted_records_A as
 (
 select CONVERT(DATETIME,substring(Created,1,23)) as Created_ts, SubmissionEventId, SubmissionId, fileid
 from rpd.SubmissionEvents where type = 'Submitted' and ISNULL(IsResubmission,0) = 0
 ),
rank_list_A as
(
 select D.SubmissionId, D.SubmissionEventId/*, D.Created_ts, S.Created_ts*/, S.fileid as fileid_new
	, row_number() over(partition by D.SubmissionId, D.SubmissionEventId order by S.Created_ts desc) as RN
 from null_fileid_decision_records_A D
 inner join all_submitted_records_A S
	on D.SubmissionId = S.SubmissionId
		and D.Created_ts >= S.Created_ts
),
final_result_set_A as
(
select distinct * from rank_list_A where RN = 1
),


--SET B (Canclled decision record after resubmission)
resubmission_list_B as
(
	select SE.SubmissionId, 1 as IsResubmitted, min(CONVERT(DATETIME,substring(SE.Created,1,23))) as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.IsResubmission = 1
	group by SE.SubmissionId
),
submission_list_B as
(
	select SE.SubmissionId, 0 as IsResubmitted, NULL as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.SubmissionId not in
		(
			select SubmissionId from resubmission_list_B
		)
),
combined_list_B as
(
	select * from resubmission_list_B
	union
	select * from submission_list_B
),
null_fileid_decision_records_B as
(
	select CONVERT(DATETIME,substring(se.Created,1,23)) as Created_ts , se.SubmissionEventId, se.SubmissionId
	 from rpd.SubmissionEvents se
	 inner join combined_list_B cl on cl.SubmissionId = se.SubmissionId
	 where se.type = 'RegulatorRegistrationDecision'
			and se.Decision = 'Cancelled'
			and
			(
				--cl.IsResubmitted = 0
				--or
					(
						cl.IsResubmitted = 1
						and
						CONVERT(DATETIME,substring(se.Created,1,23)) >= cl.first_resub_ts
					)
			)
			and se.fileid is null
			--and se.SubmissionId = 'b7efef91-2bda-488b-9ad7-32c310a3087f'
),
 all_submitted_records_B as
 (
 select CONVERT(DATETIME,substring(Created,1,23)) as Created_ts, SubmissionEventId, SubmissionId, fileid
 from rpd.SubmissionEvents where type = 'Submitted' and ISNULL(IsResubmission,0) = 0
 ),
rank_list_B as
(
 select D.SubmissionId, D.SubmissionEventId/*, D.Created_ts, S.Created_ts*/, S.fileid as fileid_new
	, row_number() over(partition by D.SubmissionId, D.SubmissionEventId order by S.Created_ts asc) as RN
 from null_fileid_decision_records_B D
 inner join all_submitted_records_B S
	on D.SubmissionId = S.SubmissionId
		--and D.Created_ts >= S.Created_ts
),
final_result_set_B as
(
select distinct * from rank_list_B where RN = 1
),


--SET C (Non Cancelled decision record after resubmission)
resubmission_list_C as
(
	select SE.SubmissionId, 1 as IsResubmitted, min(CONVERT(DATETIME,substring(SE.Created,1,23))) as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.IsResubmission = 1
	group by SE.SubmissionId
),
submission_list_C as
(
	select SE.SubmissionId, 0 as IsResubmitted, NULL as first_resub_ts
	from rpd.submissions S
	inner join rpd.SubmissionEvents SE on S.SubmissionId = SE.SubmissionId
	where S.SubmissionType = 'Registration'
	and SE.SubmissionId not in
		(
			select SubmissionId from resubmission_list_C
		)
),
combined_list_C as
(
	select * from resubmission_list_C
	union
	select * from submission_list_C
),
null_fileid_decision_records_C as
(
	select CONVERT(DATETIME,substring(se.Created,1,23)) as Created_ts , se.SubmissionEventId, se.SubmissionId
	 from rpd.SubmissionEvents se
	 inner join combined_list_C cl on cl.SubmissionId = se.SubmissionId
	 where se.type = 'RegulatorRegistrationDecision'
			and se.Decision <> 'Cancelled'
			and
			(
				--cl.IsResubmitted = 0
				--or
					(
						cl.IsResubmitted = 1
						and
						CONVERT(DATETIME,substring(se.Created,1,23)) >= cl.first_resub_ts
					)
			)
			and se.fileid is null
			--and se.SubmissionId = 'b7efef91-2bda-488b-9ad7-32c310a3087f'
),
 all_submitted_records_C as
 (
 select CONVERT(DATETIME,substring(Created,1,23)) as Created_ts, SubmissionEventId, SubmissionId, fileid
 from rpd.SubmissionEvents where type = 'Submitted'
 ),
rank_list_C as
(
 select D.SubmissionId, D.SubmissionEventId/*, D.Created_ts, S.Created_ts*/, S.fileid as fileid_new
	, row_number() over(partition by D.SubmissionId, D.SubmissionEventId order by S.Created_ts desc) as RN
 from null_fileid_decision_records_C D
 inner join all_submitted_records_C S
	on D.SubmissionId = S.SubmissionId
		and D.Created_ts >= S.Created_ts
),
final_result_set_C as
(
select distinct * from rank_list_C where RN = 1
),

--SET A + B
final_result_set as
(
select * from final_result_set_A
union
select * from final_result_set_B
union
select * from final_result_set_C
),
SubmissionEvents_updated as
(
	select se.*, fs.fileid_new
	from rpd.SubmissionEvents se
	left join final_result_set fs on fs.SubmissionId = se.SubmissionId and fs.SubmissionEventId = se.SubmissionEventId
),



--Find fileid that are submitted
submitted_Fileids as
(
	select distinct Fileid as submitted_Fileid, SubmissionEventId as SubmissionEventId_of_submitted_record, SubmissionId as SubmissionId_of_submitted_record, CONVERT(DATETIME,substring(Created,1,23)) as Submitted_ts
	From rpd.SubmissionEvents where Type = 'Submitted' and Fileid is not null
),

--File file id matching to the RegistrationApplicationSubmitted
get_all_RegistrationApplicationSubmitted as
(
	select distinct sub.submitted_Fileid as app_submitted_Fileid, sub.SubmissionEventId_of_submitted_record
		, app_sub.SubmissionEventId as SubmissionEventId_of_application_submitted_record
		--, CONVERT(DATETIME,substring(app_sub.Created,1,23)) as Submitted_ts
		, app_sub.Created as Submitted_ts
		, app_sub.ApplicationReferenceNumber
		, row_number() over(partition by app_sub.SubmissionId, app_sub.SubmissionEventId order by sub.Submitted_ts desc) as RN
	From rpd.SubmissionEvents app_sub
		 inner join submitted_Fileids sub
			on sub.SubmissionId_of_submitted_record = app_sub.SubmissionId
				and CONVERT(DATETIME,substring(app_sub.Created,1,23)) >= sub.Submitted_ts
	where app_sub.Type in ('RegistrationApplicationSubmitted','PackagingResubmissionApplicationSubmitted')
),
top_matching_og_get_all_RegistrationApplicationSubmitted as
(
	select * From get_all_RegistrationApplicationSubmitted where RN = 1
)

,res as (
		select distinct
				 cfm.[SubmissionId]
				,cfm.[RegistrationSetId]
				,cfm.[OrganisationId]
				,cfm.[FileName]
				,cfm.[FileType]
				,cfm.[OriginalFileName]
				,cfm.[TargetDirectoryName]
				, se.created as Decision_Date
				, case when cfm.[FileType] = 'CompanyDetails' and  Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) >= 2025 and ISNULL(rid.IsResubmission_identifier,0) = 0 and se.Decision = 'Accepted' Then 'Granted'
					   when cfm.[FileType] = 'CompanyDetails' and  Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) >= 2025 and ISNULL(rid.IsResubmission_identifier,0) = 0 and se.Decision = 'Rejected' Then 'Refused'
					   when cfm.[FileType] = 'Pom' and ISNULL(rpl.POM_resubmission_identifier,0) = 1 and app_submitted.SubmissionEventId_of_application_submitted_record is not null and se.Decision is null then 'Pending'
					   when cfm.[FileType] = 'Pom' and ISNULL(rpl.POM_resubmission_identifier,0) = 1 and app_submitted.SubmissionEventId_of_application_submitted_record is null and se.Decision is null then 'Uploaded'
					   when cfm.[FileType] = 'Pom' and ISNULL(rpl.POM_resubmission_identifier,0) = 0 and se.Decision is null then 'Pending'
					   when cfm.[FileType] = 'CompanyDetails' and app_submitted.SubmissionEventId_of_application_submitted_record is not null and se.Decision is null then 'Pending'
					   when cfm.[FileType] = 'CompanyDetails' and app_submitted.SubmissionEventId_of_application_submitted_record is null and se.Decision is null and Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) >= 2025 then 'Uploaded'
					   when cfm.[FileType] = 'CompanyDetails' and app_submitted.SubmissionEventId_of_application_submitted_record is null and se.Decision is null and Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) < 2025  then 'Pending'
					   else se.Decision
					   end
					as Regulator_Status
				,'' AS [RegulatorDecision] --not represented in Cosmos DB
				, ISNULL(p.[FirstName],'') +' '+ ISNULL(p.[LastName],'') as Regulator_User_Name
				, se.Comments as Regulator_Rejection_Comments
				, '' as RejectionComments

				, case when se.[Type] is null
							and SubmissionEventId_of_application_submitted_record is not null
							then 'RegistrationApplicationSubmitted'
						when se.[Type] is null
							and sfs.SubmissionEventId_of_submitted_record is not null
							then 'Submitted'
						else se.[Type]
						end as [Type]
				, se.UserId
				, cfm.Created
				, app_submitted.Submitted_ts as 'Application_submitted_ts'
				, case when Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) >= 2025 and s.SubmissionType = 'Registration' then 2
					   when Right(dbo.udf_DQ_SubmissionPeriod(s.SubmissionPeriod),4) < 2025 then 1
						else NULL
						end
					as RegistrationType
				,s.SubmissionPeriod
				, coalesce(app_submitted.ApplicationReferenceNumber,se.AppReferenceNumber) as ApplicationReferenceNo
				, se.registrationreferencenumber
				--Supporting columns
				, se.Decision as Original_Regulator_Status

				,s.SubmissionType
				, ISNULL(rid.IsResubmission_identifier,0) as IsResubmission_identifier
				, ISNULL(rpl.POM_resubmission_identifier,0) as Is_resubmitted_POM_identifier
				, cfm.FileId as cfm_FileId
				, se.FileId
				, se.fileid_new
				, sfs.submitted_Fileid
				, sfs.SubmissionEventId_of_submitted_record
				, app_submitted.app_submitted_Fileid
				, app_submitted.SubmissionEventId_of_application_submitted_record

		From rpd.cosmos_file_metadata cfm
		inner join rpd.Submissions s on s.SubmissionId = cfm.SubmissionId
		left Join
			SubmissionEvents_updated		se
				on cfm.FileId = ISNULL(se.FileId,se.fileid_new)
					and se.[type] in ('RegulatorPoMDecision', 'RegulatorRegistrationDecision')
		left join resubmission_ids rid on cfm.fileid = rid.fileid
		left join submitted_Fileids sfs on sfs.submitted_Fileid = cfm.fileid
		left join top_matching_og_get_all_RegistrationApplicationSubmitted app_submitted on app_submitted.app_submitted_Fileid = cfm.fileid
		Left Join [rpd].[Users] u on se.[Userid] = u.[userid] and u.[isdeleted] = 0
		Left Join rpd.[persons] p on u.[id] =p.[userid] and p.[isdeleted] = 0
		left join resubmitted_POM_list rpl on rpl.FileId = cfm.fileid
		where cfm.FileType in ('CompanyDetails','Pom')
),

rank_on_res as
(
select
	 *
	 ,row_number() over(partition by cfm_FileId order by Decision_Date desc, Created desc) as RowNumber
from res
),

cd_pom_result as
(
	select * From rank_on_res where RowNumber = 1
),

--A Cancelled Registration decision (against the original submission or any resubmission) is final, so it is
--propagated to every submission sharing that SubmissionId, regardless of submission order.
cancelled_registration_submissions as
(
	select distinct SubmissionId
	from cd_pom_result
	where SubmissionType = 'Registration'
		and Regulator_Status = 'Cancelled'
),
cd_pom_result_updated as
(
	select c.*
		, case
			when c.SubmissionType = 'Registration' and crs.SubmissionId is not null
				then 'Cancelled'
			else c.Regulator_Status
			end as Regulator_Status_recalculated
	from cd_pom_result c
	left join cancelled_registration_submissions crs on c.SubmissionId = crs.SubmissionId
)
select distinct pom_cd.SubmissionId, pom_cd.RegistrationSetId, pom_cd.OrganisationId, pom_cd.FileName, pom_cd.FileType, pom_cd.OriginalFileName, pom_cd.TargetDirectoryName, pom_cd.Decision_Date, pom_cd.Regulator_Status_recalculated as Regulator_Status, pom_cd.RegulatorDecision, pom_cd.Regulator_User_Name, pom_cd.Regulator_Rejection_Comments, pom_cd.RejectionComments, pom_cd.Type, pom_cd.UserId, pom_cd.RowNumber, pom_cd.Created, pom_cd.Application_submitted_ts, pom_cd.RegistrationType, pom_cd.SubmissionPeriod, pom_cd.ApplicationReferenceNo, pom_cd.registrationreferencenumber, pom_cd.Original_Regulator_Status, pom_cd.SubmissionType, pom_cd.IsResubmission_identifier, pom_cd.Is_resubmitted_POM_identifier, pom_cd.cfm_FileId, pom_cd.FileId, pom_cd.fileid_new, pom_cd.submitted_Fileid, pom_cd.SubmissionEventId_of_submitted_record, pom_cd.app_submitted_Fileid, pom_cd.SubmissionEventId_of_application_submitted_record
from cd_pom_result_updated pom_cd
union
select distinct cfm.SubmissionId, cfm.RegistrationSetId, cfm.OrganisationId, cfm.FileName, cfm.FileType, cfm.OriginalFileName, cfm.TargetDirectoryName, cp.Decision_Date, cp.Regulator_Status_recalculated as Regulator_Status, cp.RegulatorDecision, cp.Regulator_User_Name, cp.Regulator_Rejection_Comments, cp.RejectionComments, cp.Type, cp.UserId, cp.RowNumber, cp.Created, cp.Application_submitted_ts, cp.RegistrationType, cp.SubmissionPeriod, cp.ApplicationReferenceNo, cp.registrationreferencenumber, cp.Original_Regulator_Status, cp.SubmissionType, cp.IsResubmission_identifier, cp.Is_resubmitted_POM_identifier, cp.cfm_FileId, cp.FileId, cp.fileid_new, cp.submitted_Fileid, cp.SubmissionEventId_of_submitted_record, cp.app_submitted_Fileid, cp.SubmissionEventId_of_application_submitted_record
From rpd.cosmos_file_metadata cfm
inner join cd_pom_result_updated cp on cfm.RegistrationSetId = cp.RegistrationSetId
where cfm.FileType in ('Partnerships','Brands');
