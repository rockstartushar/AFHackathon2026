/**
 * One-shot demo seed for docs/Data-Model-Objects-And-Fields.md happy path.
 * Run: sf apex run --file scripts/apex/HackathonSeedData.apex --target-org <alias>
 * Safe to re-run: each run uses a unique suffix on names (no deletes).
 */
String SUF = String.valueOf(Datetime.now().getTime());
String suf5 = SUF.length() > 5 ? SUF.substring(SUF.length() - 5) : SUF;

Id rtBusiness = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Business_Account' LIMIT 1].Id;
Id rtFacilityAcct = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Onco_Facility' LIMIT 1].Id;
Id rtPerson = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1].Id;

Account net = new Account(Name = 'Hackathon Network ' + SUF, RecordTypeId = rtBusiness);
insert net;

Account facOrg = new Account(Name = 'Hackathon Facility Org ' + SUF, RecordTypeId = rtFacilityAcct);
insert facOrg;

Account patient = new Account(
    RecordTypeId = rtPerson,
    LastName = 'Patil ' + SUF,
    PersonMobilePhone = '+9198000' + suf5,
    PersonEmail = 'patient.' + SUF + '@example.invalid'
);
insert patient;

// Standard object "Location" clashes with System.Location in Apex — use SObject factory.
SObject loc = Schema.getGlobalDescribe().get('Location').newSObject();
loc.put('Name', 'Hackathon Site ' + SUF);
loc.put('LocationType', 'Site');
loc.put('IsMobile', false);
loc.put('IsInventoryLocation', false);
loc.put('ShouldSyncWithOci', false);
loc.put('IsEligibleForPickup', false);
loc.put('Latitude', 19.076);
loc.put('Longitude', 72.8777);
insert loc;
Id locId = (Id) loc.get('Id');

HealthcareFacility hcf = new HealthcareFacility(
    Name = 'Hackathon Cancer Centre ' + SUF,
    AccountId = facOrg.Id,
    IsAlwaysOpen = false,
    LocationId = locId,
    LicensedBedCount = 120,
    Max_Daily_Appointments__c = 40
);
insert hcf;

Contact pract = new Contact(
    LastName = 'Kapoor ' + SUF,
    FirstName = 'Ananya',
    Email = 'dr.ananya.' + SUF + '@example.invalid',
    Phone = '+9198111' + suf5
);
insert pract;

HealthcareProvider hp = new HealthcareProvider(
    Name = 'Dr Ananya Kapoor ' + SUF,
    PractitionerId = pract.Id,
    IsActive = true,
    IsNotSearchable = false,
    HasCarrierContract = false,
    IsPrivacyLawEnabled = false
);
insert hp;

HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
    Name = 'Kapoor-HCF-' + SUF,
    HealthcareProviderId = hp.Id,
    HealthcareFacilityId = hcf.Id,
    IsPrimaryFacility = true,
    IsActive = true,
    IsDirectoryPrint = false,
    IsPrimaryCarePhysician = true,
    Has24x7Service = false
);
insert hpf;

CareSpecialty cs = new CareSpecialty(Name = 'Medical Oncology ' + SUF, IsActive = true);
insert cs;

HealthcareProviderSpecialty hps = new HealthcareProviderSpecialty(
    Name = 'MO ' + SUF,
    PractitionerId = pract.Id,
    SpecialtyId = cs.Id,
    IsPrimarySpecialty = true,
    IsActive = true
);
insert hps;

// One ServiceResource per RelatedRecordId (user) in this org — reuse if seed runs again.
ServiceResource sr;
List<ServiceResource> existingSr = [
    SELECT Id
    FROM ServiceResource
    WHERE RelatedRecordId = :UserInfo.getUserId() AND IsActive = TRUE
    LIMIT 1
];
if (!existingSr.isEmpty()) {
    sr = existingSr[0];
} else {
    sr = new ServiceResource(
        Name = 'Resource Kapoor ' + SUF,
        RelatedRecordId = UserInfo.getUserId(),
        IsActive = true,
        IsCapacityBased = false,
        IsOptimizationCapable = false,
        IsPrimary = false
    );
    insert sr;
}

Datetime schedStart = Datetime.now().addDays(1).addHours(3);
Datetime schedEnd = schedStart.addHours(1);

// AccountId is not writable on SA here; parent Account satisfies ParentRecordId (FSL).
ServiceAppointment sa = new ServiceAppointment(
    ParentRecordId = patient.Id,
    Subject = 'Hackathon counselling ' + SUF,
    SchedStartTime = schedStart,
    SchedEndTime = schedEnd,
    EarliestStartTime = schedStart.addMinutes(-30),
    DueDate = schedEnd.addHours(2),
    IsAnonymousBooking = false,
    IsManuallyBundled = false,
    IsBundleMember = false,
    IsBundle = false,
    IsOffsiteAppointment = false,
    Status = 'Scheduled'
);
insert sa;

ClinicalEncounter enc = new ClinicalEncounter(
    PatientId = patient.Id,
    FacilityId = hcf.Id,
    ServiceAppointmentId = sa.Id,
    Status = 'Planned',
    Category = 'Ambulatory',
    StartDate = schedStart,
    EndDate = schedEnd
);
insert enc;

ClinicalEncounterProvider cep = new ClinicalEncounterProvider(
    ClinicalEncounterId = enc.Id,
    PractitionerId = hp.Id,
    StartDate = schedStart,
    EndDate = schedEnd
);
insert cep;

ClinicalEncounterFacility cef = new ClinicalEncounterFacility(ClinicalEncounterId = enc.Id, FacilityId = hcf.Id);
insert cef;

Patient_Insurance__c pi = new Patient_Insurance__c(
    Patient__c = patient.Id,
    Payer_Name__c = 'Demo National Health',
    Member_Id__c = 'MEM-' + SUF,
    Plan_Name__c = 'Gold Coverage',
    Eligibility_Status__c = 'Active',
    Valid_From__c = Date.today().addMonths(-6),
    Valid_To__c = Date.today().addMonths(6),
    Last_Verified_Date__c = Date.today(),
    Is_Primary__c = true,
    Notes__c = 'Demo seed row — not real PHI.'
);
insert pi;

Counselling_Prerequisite__c cpr = new Counselling_Prerequisite__c(
    Related_Appointment__c = sa.Id,
    Document_Type__c = 'Insurance_Card',
    Is_Required__c = true,
    Is_Satisfied__c = false,
    Due_Before__c = schedStart.addHours(-1)
);
insert cpr;

Facility_Room_Rate__c frr = new Facility_Room_Rate__c(
    Healthcare_Facility__c = hcf.Id,
    Room_Type__c = 'Private',
    Daily_Rate__c = 5500,
    Effective_From__c = Date.today(),
    Effective_To__c = null
);
insert frr;

Booking_Session__c bs = new Booking_Session__c(
    Patient__c = patient.Id,
    Last_Service_Appointment__c = sa.Id,
    Last_Clinical_Encounter__c = enc.Id,
    Preferred_Facility__c = hcf.Id,
    Context_Token__c = 'ctx_' + SUF
);
insert bs;

Agent_Action_Log__c log = new Agent_Action_Log__c(
    Action_Name__c = 'HC_Seed_Run',
    Status__c = 'Success',
    Correlation_Id__c = 'seed-' + SUF,
    Related_Service_Appointment__c = sa.Id,
    Related_Clinical_Encounter__c = enc.Id,
    Input_Summary__c = 'Seeded demo network, facility, patient, appt, encounter.'
);
insert log;

System.debug(
    LoggingLevel.INFO,
    'HACKATHON_SEED_OK suffix=' +
        SUF +
        ' patient=' +
        patient.Id +
        ' facility=' +
        hcf.Id +
        ' appt=' +
        sa.Id +
        ' encounter=' +
        enc.Id
);
