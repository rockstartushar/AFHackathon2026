/**
 * Single invocable entry: set operation to BOOK, MODIFY, or CANCEL (org allows one @InvocableMethod per class).
 * See docs/BOOKING_PATTERN.md.
 */
public without sharing class HC_BookingActionsInvocable {
    private static final String DEF_SA_STATUS = 'Scheduled';
    private static final String DEF_CE_STATUS = 'Scheduled';
    private static final String DEF_SA_CANCEL_STATUS = 'Canceled';
    private static final String DEF_SA_CANCEL_CATEGORY = 'None';
    private static final String DEF_CE_CANCEL_STATUS = 'Canceled';
    private static final String DEF_CE_Category = 'Ambulatory';
    private static final List<String> CANCELLED_ENCOUNTER_STATUSES = new List<String>{ 'Canceled', 'Cancelled' };

    public class Request {
        @InvocableVariable(
            required=true
            label='Operation'
            description='BOOK = create ServiceAppointment + ClinicalEncounter (+ provider when set). MODIFY = reschedule existing SA (needs serviceAppointmentId). CANCEL = cancel SA/encounter (needs serviceAppointmentId). Uppercase.'
        )
        public String operation;
        @InvocableVariable(
            label='Patient Account Id'
            description='Person Account Id after verification. Required for BOOK, MODIFY, and CANCEL.'
        )
        public Id patientAccountId;
        @InvocableVariable(
            label='Healthcare Facility Id'
            description='HealthcareFacility Id for BOOK. MODIFY/CANCEL infer facility from existing SA.'
        )
        public Id healthcareFacilityId;
        @InvocableVariable(
            label='Sched Start / New Start'
            description='Appointment start (BOOK) or new start time (MODIFY). Use patient-local intent; stored as Datetime.'
        )
        public Datetime schedStartOrNewStart;
        @InvocableVariable(
            label='Sched End / New End'
            description='Appointment end (BOOK) or new end time (MODIFY).'
        )
        public Datetime schedEndOrNewEnd;
        @InvocableVariable(
            label='Healthcare Provider Id'
            description='Optional HealthcareProvider Id when patient names a doctor for BOOK.'
        )
        public Id healthcareProviderId;
        @InvocableVariable(
            label='Parent Record Id'
            description='Often required on ServiceAppointment for BOOK (org-specific parent work object).'
        )
        public Id parentRecordId;
        @InvocableVariable(
            label='Work Type Id'
            description='Optional WorkType Id for BOOK when the org ties visit length to work type.'
        )
        public Id workTypeId;
        @InvocableVariable(
            label='Correlation Id'
            description='Session or conversation id for Agent_Action_Log / tracing; optional but recommended.'
        )
        public String correlationId;
        @InvocableVariable(label='Subject' description='Optional short subject on the ServiceAppointment for BOOK.')
        public String subject;
        @InvocableVariable(
            label='SA Status API'
            description='Override ServiceAppointment Status API value for BOOK; default Scheduled.'
        )
        public String serviceAppointmentStatus;
        @InvocableVariable(
            label='SA StatusCategory API'
            description='Optional StatusCategory when your org requires it.'
        )
        public String serviceAppointmentStatusCategory;
        @InvocableVariable(
            label='CE Status API'
            description='Override ClinicalEncounter Status for BOOK; default Scheduled.'
        )
        public String clinicalEncounterStatus;
        @InvocableVariable(
            label='Service Appointment Id'
            description='Existing ServiceAppointment Id for MODIFY or CANCEL.'
        )
        public Id serviceAppointmentId;
        @InvocableVariable(
            label='Cancellation Reason'
            description='Picklist/API reason for CANCEL when your org captures it.'
        )
        public String cancellationReason;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id serviceAppointmentId;
        @InvocableVariable public Id clinicalEncounterId;
        @InvocableVariable public Id clinicalEncounterProviderId;
        @InvocableVariable(
            label = 'Booking confirmation UI model'
            description = 'Custom Lightning Type payload for Enhanced Web Chat (hcBookingConfirmationRenderer).'
        )
        public HCBookingConfirmationUiModel bookingUi;
    }

    @InvocableMethod(
        label='HC Booking Actions'
        description='Creates, reschedules, or cancels visits: BOOK / MODIFY / CANCEL on ServiceAppointment and ClinicalEncounter. Use only after the patient is verified (matched Person Account). Do not use for directory search (use HC Find Specialist) or insurance/prereq lists (use HC Patient Data Actions). Enforces facility daily cap when Max_Daily_Appointments__c is set.'
        category='Health Cloud'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        Request req = requests[0];
        String op = req.operation == null ? '' : req.operation.trim().toUpperCase();
        if (op == 'BOOK') {
            out.add(doBook(req));
        } else if (op == 'MODIFY') {
            out.add(doModify(req));
        } else if (op == 'CANCEL') {
            out.add(doCancel(req));
        } else {
            Result r = new Result();
            r.success = false;
            r.message = 'Unknown operation. Use BOOK, MODIFY, or CANCEL.';
            setBookingUiFromResult(r, 'Could not complete', null, null, null, null, 'UNKNOWN', r.message);
            out.add(r);
        }
        return out;
    }

    private static Result doBook(Request req) {
        Result res = new Result();
        res.success = false;
        Savepoint sp = Database.setSavepoint();
        try {
            if (req.patientAccountId == null || req.healthcareFacilityId == null) {
                throw new IllegalArgumentException('patientAccountId and healthcareFacilityId are required for BOOK.');
            }
            if (req.schedEndOrNewEnd == null || req.schedStartOrNewStart == null) {
                throw new IllegalArgumentException('schedStart and schedEnd are required for BOOK.');
            }
            if (req.schedEndOrNewEnd <= req.schedStartOrNewStart) {
                throw new IllegalArgumentException('End time must be after start time.');
            }
            if (req.schedStartOrNewStart < System.now()) {
                throw new IllegalArgumentException('Start time must be in the future.');
            }

            HealthcareFacility fac = [
                SELECT Id, Max_Daily_Appointments__c
                FROM HealthcareFacility
                WHERE Id = :req.healthcareFacilityId
                LIMIT 1
            ];
            if (fac.Max_Daily_Appointments__c != null) {
                Datetime sod = Datetime.newInstanceGmt(req.schedStartOrNewStart.dateGmt(), Time.newInstance(0, 0, 0, 0));
                Datetime eod = sod.addDays(1);
                Integer cnt = [
                    SELECT COUNT()
                    FROM ClinicalEncounter
                    WHERE
                        FacilityId = :req.healthcareFacilityId
                        AND StartDate >= :sod
                        AND StartDate < :eod
                        AND (Status NOT IN :CANCELLED_ENCOUNTER_STATUSES OR Status = NULL)
                ];
                if (cnt >= fac.Max_Daily_Appointments__c.intValue()) {
                    throw new IllegalArgumentException('Facility has reached its configured daily appointment limit.');
                }
            }

            Account pa = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :req.patientAccountId
                LIMIT 1
            ];
            ServiceAppointment sa = new ServiceAppointment();
            sa.SchedStartTime = req.schedStartOrNewStart;
            sa.SchedEndTime = req.schedEndOrNewEnd;
            sa.ParentRecordId = req.patientAccountId;
            sa.WorkTypeId = req.workTypeId;
            sa.Status = nz(req.serviceAppointmentStatus, DEF_SA_STATUS);
            sa.Subject = String.isNotBlank(req.subject) ? req.subject.left(255) : 'Outpatient visit';
            if (pa.PersonContactId != null) {
                sa.ContactId = pa.PersonContactId;
            }
            insert sa;

            ClinicalEncounter ce = new ClinicalEncounter();
            ce.PatientId = req.patientAccountId;
            ce.FacilityId = req.healthcareFacilityId;
            ce.StartDate = req.schedStartOrNewStart;
            ce.EndDate = req.schedEndOrNewEnd;
            ce.ServiceAppointmentId = sa.Id;
            ce.Category = DEF_CE_Category;
            ce.Status = nz(req.clinicalEncounterStatus, DEF_CE_STATUS);
            insert ce;

            Id cepId;
            if (req.healthcareProviderId != null) {
                HealthcareProvider hp = [
                    SELECT PractitionerId
                    FROM HealthcareProvider
                    WHERE Id = :req.healthcareProviderId
                    LIMIT 1
                ];
                if (hp.PractitionerId == null) {
                    throw new IllegalArgumentException('HealthcareProvider has no PractitionerId.');
                }
                Id practitionerForCep = hp.PractitionerId;
                if (!isAcceptablePractitionerLookup(practitionerForCep)) {
                    if (practitionerForCep.getSobjectType() == Contact.SObjectType) {
                        practitionerForCep = tryResolvePractitionerIdFromContact(practitionerForCep);
                    }
                }
                if (practitionerForCep != null && isAcceptablePractitionerLookup(practitionerForCep)) {
                    ClinicalEncounterProvider cep = new ClinicalEncounterProvider();
                    cep.ClinicalEncounterId = ce.Id;
                    cep.PractitionerId = practitionerForCep;
                    cep.StartDate = req.schedStartOrNewStart;
                    cep.EndDate = req.schedEndOrNewEnd;
                    insert cep;
                    cepId = cep.Id;
                }
                // When HP points at Contact but CEP only allows Practitioner and no Practitioner row exists, still book SA+CE (provider link skipped).
            }

            res.success = true;
            res.message = 'Booked';
            res.serviceAppointmentId = sa.Id;
            res.clinicalEncounterId = ce.Id;
            res.clinicalEncounterProviderId = cepId;
            String facName = [SELECT Name FROM HealthcareFacility WHERE Id = :req.healthcareFacilityId LIMIT 1].Name;
            setBookingUiFromResult(
                res,
                'Visit booked',
                sa.SchedStartTime,
                sa.SchedEndTime,
                facName,
                sa.Subject,
                'BOOK',
                res.message
            );
            HCAuditHelper.log('HC_Book_Appointment', 'Success', req.correlationId, null, summarize(req), sa.Id, ce.Id);
        } catch (Exception e) {
            Database.rollback(sp);
            res.message = e.getMessage();
            setBookingUiFromResult(
                res,
                'Could not book',
                null,
                null,
                null,
                null,
                'BOOK',
                res.message
            );
            HCAuditHelper.log('HC_Book_Appointment', 'Failed', req.correlationId, e.getMessage(), summarize(req), null, null);
        }
        return res;
    }

    private static Result doModify(Request req) {
        Result res = new Result();
        res.success = false;
        try {
            if (req.serviceAppointmentId == null || req.patientAccountId == null) {
                throw new IllegalArgumentException('serviceAppointmentId and patientAccountId are required for MODIFY.');
            }
            if (req.schedEndOrNewEnd == null || req.schedStartOrNewStart == null) {
                throw new IllegalArgumentException('New start and end are required for MODIFY.');
            }
            if (req.schedEndOrNewEnd <= req.schedStartOrNewStart) {
                throw new IllegalArgumentException('End time must be after start time.');
            }
            ServiceAppointment sa = [
                SELECT Id, ContactId, ParentRecordId
                FROM ServiceAppointment
                WHERE Id = :req.serviceAppointmentId
                LIMIT 1
            ];
            Id contactId = [
                    SELECT PersonContactId
                    FROM Account
                    WHERE Id = :req.patientAccountId
                    LIMIT 1
                ]
                .PersonContactId;
            assertPatientOwnsServiceAppointment(sa, req.patientAccountId, contactId);
            sa.SchedStartTime = req.schedStartOrNewStart;
            sa.SchedEndTime = req.schedEndOrNewEnd;
            update sa;

            List<ClinicalEncounter> ces = [
                SELECT Id
                FROM ClinicalEncounter
                WHERE ServiceAppointmentId = :sa.Id
                LIMIT 50
            ];
            Set<Id> ceIds = new Set<Id>();
            for (ClinicalEncounter ce : ces) {
                ce.StartDate = req.schedStartOrNewStart;
                ce.EndDate = req.schedEndOrNewEnd;
                ceIds.add(ce.Id);
            }
            if (!ces.isEmpty()) {
                update ces;
            }
            if (!ceIds.isEmpty()) {
                List<ClinicalEncounterProvider> ceps = [
                    SELECT Id
                    FROM ClinicalEncounterProvider
                    WHERE ClinicalEncounterId IN :ceIds
                ];
                for (ClinicalEncounterProvider cep : ceps) {
                    cep.StartDate = req.schedStartOrNewStart;
                    cep.EndDate = req.schedEndOrNewEnd;
                }
                if (!ceps.isEmpty()) {
                    update ceps;
                }
            }
            res.success = true;
            res.message = 'Updated';
            res.serviceAppointmentId = sa.Id;
            res.clinicalEncounterId = ces.isEmpty() ? null : ces[0].Id;
            String facNameMod;
            if (!ces.isEmpty()) {
                ClinicalEncounter ceOne = [
                    SELECT FacilityId
                    FROM ClinicalEncounter
                    WHERE Id = :ces[0].Id
                    LIMIT 1
                ];
                if (ceOne.FacilityId != null) {
                    facNameMod = [SELECT Name FROM HealthcareFacility WHERE Id = :ceOne.FacilityId LIMIT 1].Name;
                }
            }
            ServiceAppointment saOut = [
                SELECT SchedStartTime, SchedEndTime, Subject
                FROM ServiceAppointment
                WHERE Id = :sa.Id
                LIMIT 1
            ];
            setBookingUiFromResult(
                res,
                'Appointment updated',
                saOut.SchedStartTime,
                saOut.SchedEndTime,
                facNameMod,
                saOut.Subject,
                'MODIFY',
                res.message
            );
            HCAuditHelper.log(
                'HC_Modify_Appointment',
                'Success',
                req.correlationId,
                null,
                'sa=' + req.serviceAppointmentId,
                sa.Id,
                res.clinicalEncounterId
            );
        } catch (Exception e) {
            res.message = e.getMessage();
            setBookingUiFromResult(
                res,
                'Could not reschedule',
                null,
                null,
                null,
                null,
                'MODIFY',
                res.message
            );
            HCAuditHelper.log(
                'HC_Modify_Appointment',
                'Failed',
                req.correlationId,
                e.getMessage(),
                'sa=' + req.serviceAppointmentId,
                req.serviceAppointmentId,
                null
            );
        }
        return res;
    }

    private static Result doCancel(Request req) {
        Result res = new Result();
        res.success = false;
        try {
            if (req.serviceAppointmentId == null || req.patientAccountId == null) {
                throw new IllegalArgumentException('serviceAppointmentId and patientAccountId are required for CANCEL.');
            }
            ServiceAppointment sa = [
                SELECT Id, ContactId, ParentRecordId
                FROM ServiceAppointment
                WHERE Id = :req.serviceAppointmentId
                LIMIT 1
            ];
            Id contactId = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :req.patientAccountId
                LIMIT 1
            ]
            .PersonContactId;
            assertPatientOwnsServiceAppointment(sa, req.patientAccountId, contactId);
            sa.Status = DEF_SA_CANCEL_STATUS;
            if (String.isNotBlank(req.cancellationReason)) {
                sa.CancellationReason = req.cancellationReason.left(255);
            }
            update sa;

            List<ClinicalEncounter> ces = [SELECT Id FROM ClinicalEncounter WHERE ServiceAppointmentId = :sa.Id];
            for (ClinicalEncounter ce : ces) {
                ce.Status = DEF_CE_CANCEL_STATUS;
            }
            if (!ces.isEmpty()) {
                update ces;
            }
            res.success = true;
            res.message = 'Canceled';
            res.serviceAppointmentId = sa.Id;
            res.clinicalEncounterId = ces.isEmpty() ? null : ces[0].Id;
            setBookingUiFromResult(
                res,
                'Appointment canceled',
                null,
                null,
                null,
                null,
                'CANCEL',
                res.message
            );
            HCAuditHelper.log(
                'HC_Cancel_Appointment',
                'Success',
                req.correlationId,
                null,
                'sa=' + req.serviceAppointmentId,
                sa.Id,
                res.clinicalEncounterId
            );
        } catch (Exception e) {
            res.message = e.getMessage();
            setBookingUiFromResult(
                res,
                'Could not cancel',
                null,
                null,
                null,
                null,
                'CANCEL',
                res.message
            );
            HCAuditHelper.log(
                'HC_Cancel_Appointment',
                'Failed',
                req.correlationId,
                e.getMessage(),
                'sa=' + req.serviceAppointmentId,
                req.serviceAppointmentId,
                null
            );
        }
        return res;
    }

    /**
     * Populates bookingUi JSON for Enhanced Web Chat (phase 2 confirmation card).
     */
    /**
     * Accepts ownership when the SA is parented to the Person Account (BOOK path) or ContactId matches.
     * Handles visits where ContactId was never set but ParentRecordId is the patient account.
     */
    private static void assertPatientOwnsServiceAppointment(
        ServiceAppointment sa,
        Id patientAccountId,
        Id personContactId
    ) {
        if (sa == null || patientAccountId == null) {
            throw new IllegalArgumentException('Appointment does not belong to the given patient.');
        }
        if (sa.ParentRecordId == patientAccountId) {
            return;
        }
        if (personContactId != null && sa.ContactId == personContactId) {
            return;
        }
        throw new IllegalArgumentException('Appointment does not belong to the given patient.');
    }

    private static void setBookingUiFromResult(
        Result res,
        String headline,
        Datetime schedStart,
        Datetime schedEnd,
        String facilityName,
        String subject,
        String operation,
        String detailMessage
    ) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('operation', operation);
        m.put('success', res.success);
        m.put('headline', headline);
        m.put('message', detailMessage != null ? detailMessage : res.message);
        m.put('serviceAppointmentId', res.serviceAppointmentId);
        m.put('clinicalEncounterId', res.clinicalEncounterId);
        m.put('clinicalEncounterProviderId', res.clinicalEncounterProviderId);
        m.put('schedStart', schedStart);
        m.put('schedEnd', schedEnd);
        m.put('facilityName', facilityName);
        m.put('subject', subject);
        HCBookingConfirmationUiModel ui = new HCBookingConfirmationUiModel();
        ui.payload = JSON.serialize(m);
        res.bookingUi = ui;
    }

    private static String nz(String v, String d) {
        return String.isBlank(v) ? d : v;
    }

    private static String summarize(Request req) {
        return 'op=BOOK;patient=' + req.patientAccountId + ';facility=' + req.healthcareFacilityId;
    }

    /**
     * Ensures the Id is one of the types allowed on ClinicalEncounterProvider.PractitionerId
     * (avoids hard-coding the Practitioner type, which may not resolve in all compile contexts).
     */
    private static Boolean isAcceptablePractitionerLookup(Id practitionerId) {
        if (practitionerId == null) {
            return false;
        }
        Schema.SObjectType actual = practitionerId.getSobjectType();
        for (Schema.SObjectType allowed : ClinicalEncounterProvider.PractitionerId.getDescribe().getReferenceTo()) {
            if (actual == allowed) {
                return true;
            }
        }
        return false;
    }

    /**
     * Seed/demo HealthcareProvider rows often store Contact Id on PractitionerId. ClinicalEncounterProvider.PractitionerId
     * may only allow Practitioner in some orgs — resolve Practitioner.Id via a Contact lookup field when present.
     */
    private static Id tryResolvePractitionerIdFromContact(Id contactId) {
        if (contactId == null || contactId.getSobjectType() != Contact.SObjectType) {
            return null;
        }
        Schema.SObjectType pracType = null;
        for (String key : Schema.getGlobalDescribe().keySet()) {
            if (key.equalsIgnoreCase('Practitioner')) {
                pracType = Schema.getGlobalDescribe().get(key).getDescribe().getSObjectType();
                break;
            }
        }
        if (pracType == null) {
            return null;
        }
        String contactLookupField = pickPractitionerContactLookupField(pracType);
        if (String.isBlank(contactLookupField)) {
            return null;
        }
        String objName = pracType.getDescribe().getName();
        String q =
            'SELECT Id FROM ' +
            objName +
            ' WHERE ' +
            contactLookupField +
            ' = :contactId LIMIT 1';
        List<SObject> rows;
        try {
            rows = Database.query(q);
        } catch (Exception e) {
            return null;
        }
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static String pickPractitionerContactLookupField(Schema.SObjectType pracType) {
        Map<String, Schema.SObjectField> fm = pracType.getDescribe().fields.getMap();
        List<String> preference = new List<String>{
            'ContactId',
            'SourceContactId',
            'PersonContactId',
            'PrimaryContactId'
        };
        for (String pref : preference) {
            Schema.SObjectField sf = null;
            for (String k : fm.keySet()) {
                if (k != null && k.equalsIgnoreCase(pref)) {
                    sf = fm.get(k);
                    break;
                }
            }
            if (sf == null) {
                continue;
            }
            Schema.DescribeFieldResult d = sf.getDescribe();
            if (d.getType() != Schema.DisplayType.REFERENCE || !d.isAccessible()) {
                continue;
            }
            for (Schema.SObjectType ref : d.getReferenceTo()) {
                if (ref == Contact.SObjectType) {
                    return d.getName();
                }
            }
        }
        for (Schema.SObjectField sf : fm.values()) {
            Schema.DescribeFieldResult d = sf.getDescribe();
            if (d.getType() != Schema.DisplayType.REFERENCE || !d.isAccessible()) {
                continue;
            }
            for (Schema.SObjectType ref : d.getReferenceTo()) {
                if (ref == Contact.SObjectType) {
                    return d.getName();
                }
            }
        }
        return null;
    }
}
