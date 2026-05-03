/**
 * Onco Global Health Cloud Hackathon - Data Seeding Script
 * 
 * Purpose: Seed demo data for Agentforce healthcare agent testing
 * Target: Onco Global (India-focused Health Cloud demo org)
 * 
 * IMPORTANT: Run this script ONCE in a fresh org with Health Cloud enabled
 * 
 * Prerequisites:
 * 1. Health Cloud license and permission sets assigned
 * 2. Person Account record type enabled
 * 3. CareSpecialty catalog populated (Medical Oncology, Radiation Oncology, Surgical Oncology, Hematology)
 * 
 * Usage:
 *   Execute in Anonymous Apex: 
 *   SeedHackathonData seed = new SeedHackathonData();
 *   seed.seedAll();
 */

 public class SeedHackathonData {
    
    // Track inserted records for cross-references
    private Map<String, Id> locationMap = new Map<String, Id>();
    private Map<String, Id> patientMap = new Map<String, Id>();
    private Map<String, Id> patientContactMap = new Map<String, Id>();
    private Map<String, Id> practitionerMap = new Map<String, Id>();
    private Map<String, Id> providerMap = new Map<String, Id>();
    private Map<String, Id> facilityMap = new Map<String, Id>();
    private Map<String, Id> hoursMap = new Map<String, Id>();
    private Map<String, Id> specialtyMap = new Map<String, Id>();
    private Map<String, Id> appointmentMap = new Map<String, Id>();
    private Map<String, Id> encounterMap = new Map<String, Id>();
    private Id hospitalAccountId;
    
    /**
     * Main entry point - seeds all data in dependency order
     */
    public void seedAll() {
        System.debug('=== Starting Onco Global Data Seeding ===');
        
        try {
            // Seed CareSpecialty catalog first if needed
            seedCareSpecialties();
            
            // Query existing CareSpecialty catalog
            queryCareSpecialties();
            
            // Seed in dependency order
            seedLocations();
            seedPatientAccounts();
            seedPractitionerContacts();
            seedHealthcareProviders();
            seedHealthcareFacilities();
            seedOperatingHours();
            seedTimeSlots();
            updateFacilityOperatingHours();
            seedHealthcarePractitionerFacilities();
            seedHealthcareProviderSpecialties();
            seedSymptomSpecialtyMap();
            seedPatientInsurance();
            seedFacilityRoomRates();
            seedServiceAppointments();
            seedClinicalEncounters();
            seedClinicalEncounterProviders();
            seedCounsellingPrerequisites();
            seedBookingSessions();
            
            System.debug('=== Data Seeding Complete! ===');
            System.debug('Locations: ' + locationMap.size());
            System.debug('Patients: ' + patientMap.size());
            System.debug('Practitioners: ' + practitionerMap.size());
            System.debug('Facilities: ' + facilityMap.size());
            System.debug('Appointments: ' + appointmentMap.size());
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * Seed CareSpecialty catalog records if they don't exist
     */
    private void seedCareSpecialties() {
        System.debug('Checking CareSpecialty catalog...');
        
        // Check for the specific specialties we need
        List<CareSpecialty> existingSpecialties = [
            SELECT Id, Name 
            FROM CareSpecialty 
            WHERE Name IN ('Medical Oncology', 'Radiation Oncology', 'Surgical Oncology', 'Hematology')
        ];
        
        // Build a set of names that already exist
        Set<String> existingNames = new Set<String>();
        for (CareSpecialty spec : existingSpecialties) {
            existingNames.add(spec.Name);
        }
        
        // Only create the ones that don't exist
        List<String> requiredSpecialties = new List<String>{
            'Medical Oncology', 'Radiation Oncology', 'Surgical Oncology', 'Hematology'
        };
        
        List<CareSpecialty> specialtiesToCreate = new List<CareSpecialty>();
        for (String specialtyName : requiredSpecialties) {
            if (!existingNames.contains(specialtyName)) {
                specialtiesToCreate.add(new CareSpecialty(Name = specialtyName));
            }
        }
        
        if (specialtiesToCreate.isEmpty()) {
            System.debug('All required CareSpecialty records already exist. Skipping seed.');
            return;
        }
        
        System.debug('Seeding ' + specialtiesToCreate.size() + ' CareSpecialty catalog records...');
        
        try {
            insert specialtiesToCreate;
            System.debug('Successfully seeded ' + specialtiesToCreate.size() + ' CareSpecialty records');
        } catch (DmlException e) {
            throw new DataSeedException('Failed to seed CareSpecialty records: ' + e.getMessage());
        }
    }
    
    /**
     * Query existing CareSpecialty catalog
     */
    private void queryCareSpecialties() {
        System.debug('Querying CareSpecialty catalog...');
        
        List<CareSpecialty> specialties = [
            SELECT Id, Name 
            FROM CareSpecialty 
            WHERE Name IN ('Medical Oncology', 'Radiation Oncology', 'Surgical Oncology', 'Hematology')
            LIMIT 10
        ];
        
        for (CareSpecialty specialty : specialties) {
            specialtyMap.put(specialty.Name, specialty.Id);
            System.debug('Found specialty: ' + specialty.Name + ' (' + specialty.Id + ')');
        }
        
        if (specialtyMap.isEmpty()) {
            throw new DataSeedException('CareSpecialty catalog is empty. Please populate with: Medical Oncology, Radiation Oncology, Surgical Oncology, Hematology');
        }
    }
    
    /**
     * 1. Seed Location records (5 Indian cities)
     */
    private void seedLocations() {
        System.debug('Seeding Locations...');
        
        // Create Location SObject records using SObjectType to avoid System.Location conflict
        SObject loc1 = Schema.getGlobalDescribe().get('Location').newSObject();
        loc1.put('Name', 'Onco Global Mumbai — Andheri West');
        loc1.put('Latitude', 19.1136);
        loc1.put('Longitude', 72.8697);
        
        SObject loc2 = Schema.getGlobalDescribe().get('Location').newSObject();
        loc2.put('Name', 'Onco Global Delhi NCR — Saket');
        loc2.put('Latitude', 28.5244);
        loc2.put('Longitude', 77.2066);
        
        SObject loc3 = Schema.getGlobalDescribe().get('Location').newSObject();
        loc3.put('Name', 'Onco Global Jaipur — Malviya Nagar');
        loc3.put('Latitude', 26.8500);
        loc3.put('Longitude', 75.8000);
        
        SObject loc4 = Schema.getGlobalDescribe().get('Location').newSObject();
        loc4.put('Name', 'Onco Global Bengaluru — Koramangala');
        loc4.put('Latitude', 12.9352);
        loc4.put('Longitude', 77.6245);
        
        SObject loc5 = Schema.getGlobalDescribe().get('Location').newSObject();
        loc5.put('Name', 'Onco Global Hyderabad — Jubilee Hills');
        loc5.put('Latitude', 17.4315);
        loc5.put('Longitude', 78.4108);
        
        List<SObject> locations = new List<SObject>{loc1, loc2, loc3, loc4, loc5};
        
        insert locations;
        
        // Re-query to get Ids and Names
        List<SObject> queriedLocations = Database.query('SELECT Id, Name FROM Location WHERE Id IN :locations');
        
        for (SObject loc : queriedLocations) {
            String locName = (String)loc.get('Name');
            String city = locName.contains('Mumbai') ? 'Mumbai' :
                         locName.contains('Delhi') ? 'Delhi' :
                         locName.contains('Jaipur') ? 'Jaipur' :
                         locName.contains('Bengaluru') ? 'Bengaluru' : 'Hyderabad';
            locationMap.put(city, loc.Id);
        }
        
        System.debug('Inserted ' + locations.size() + ' locations');
    }
    
    /**
     * 2. Seed Person Account records (15 patients)
     */
    private void seedPatientAccounts() {
        System.debug('Seeding Patient Accounts...');
        
        // Get Person Account Record Type
        Id personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        List<Account> patients = new List<Account>{
            new Account(FirstName='Priya', LastName='Sharma', PersonMobilePhone='9876543210', 
                       PersonEmail='priya.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Rajesh', LastName='Kumar', PersonMobilePhone='9876543211', 
                       PersonEmail='rajesh.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Anjali', LastName='Verma', PersonMobilePhone='9876543212', 
                       PersonEmail='anjali.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Vikram', LastName='Singh', PersonMobilePhone='9876543213', 
                       PersonEmail='vikram.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Meera', LastName='Patel', PersonMobilePhone='9876543214', 
                       PersonEmail='meera.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Arjun', LastName='Reddy', PersonMobilePhone='9876543215', 
                       PersonEmail='arjun.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Kavita', LastName='Iyer', PersonMobilePhone='9876543216', 
                       PersonEmail='kavita.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Suresh', LastName='Nair', PersonMobilePhone='9876543217', 
                       PersonEmail='suresh.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Lakshmi', LastName='Menon', PersonMobilePhone='9876543218', 
                       PersonEmail='lakshmi.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Rohit', LastName='Desai', PersonMobilePhone='9876543219', 
                       PersonEmail='rohit.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Shalini', LastName='Gupta', PersonMobilePhone='9876543220', 
                       PersonEmail='shalini.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Anil', LastName='Joshi', PersonMobilePhone='9876543221', 
                       PersonEmail='anil.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Deepa', LastName='Rao', PersonMobilePhone='9876543222', 
                       PersonEmail='deepa.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Karthik', LastName='Bhat', PersonMobilePhone='9876543223', 
                       PersonEmail='karthik.demo@example.com', RecordTypeId=personAccountRTId),
            new Account(FirstName='Sunita', LastName='Kapoor', PersonMobilePhone='9876543224', 
                       PersonEmail='sunita.demo@example.com', RecordTypeId=personAccountRTId)
        };
        
        insert patients;
        
        // Re-query to get PersonContactId
        patients = [SELECT Id, PersonContactId, FirstName, LastName FROM Account WHERE Id IN :patients];
        
        for (Account patient : patients) {
            String key = patient.FirstName + '_' + patient.LastName;
            patientMap.put(key, patient.Id);
            patientContactMap.put(key, patient.PersonContactId);
        }
        
        System.debug('Inserted ' + patients.size() + ' patient accounts');
    }
    
    /**
     * 3. Seed Contact records (practitioners)
     */
    private void seedPractitionerContacts() {
        System.debug('Seeding Practitioner Contacts...');
        
        // First create a Business Account for the hospital organization
        Account hospitalAccount = new Account(
            Name = 'Onco Global Healthcare Network',
            Type = 'Healthcare Provider'
        );
        insert hospitalAccount;
        
        hospitalAccountId = hospitalAccount.Id;
        System.debug('Created hospital account: ' + hospitalAccount.Id);
        
        // Now create practitioner contacts linked to the hospital account
        List<Contact> practitioners = new List<Contact>{
            new Contact(FirstName='Dr. Sneha', LastName='Nair', Phone='+91-22-55501234', 
                       Email='sneha.nair@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Amit', LastName='Deshmukh', Phone='+91-22-55501235', 
                       Email='amit.deshmukh@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Ravi', LastName='Chandra', Phone='+91-11-55501236', 
                       Email='ravi.chandra@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Priya', LastName='Kapoor', Phone='+91-11-55501237', 
                       Email='priya.kapoor@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Arun', LastName='Mehta', Phone='+91-141-55501238', 
                       Email='arun.mehta@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Sanjay', LastName='Verma', Phone='+91-141-55501239', 
                       Email='sanjay.verma@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Kavita', LastName='Reddy', Phone='+91-80-55501240', 
                       Email='kavita.reddy@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Suresh', LastName='Kumar', Phone='+91-80-55501241', 
                       Email='suresh.kumar@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Lakshmi', LastName='Iyer', Phone='+91-40-55501242', 
                       Email='lakshmi.iyer@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Rajesh', LastName='Pillai', Phone='+91-40-55501243', 
                       Email='rajesh.pillai@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Anita', LastName='Singh', Phone='+91-22-55501244', 
                       Email='anita.singh@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Vikram', LastName='Joshi', Phone='+91-11-55501245', 
                       Email='vikram.joshi@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Meera', LastName='Bhat', Phone='+91-141-55501246', 
                       Email='meera.bhat@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Deepak', LastName='Rao', Phone='+91-80-55501247', 
                       Email='deepak.rao@oncoglobal.demo', AccountId=hospitalAccount.Id),
            new Contact(FirstName='Dr. Sunita', LastName='Menon', Phone='+91-40-55501248', 
                       Email='sunita.menon@oncoglobal.demo', AccountId=hospitalAccount.Id)
        };
        
        insert practitioners;
        
        for (Contact pract : practitioners) {
            String key = pract.LastName; // Use last name as key
            practitionerMap.put(key, pract.Id);
        }
        
        System.debug('Inserted ' + practitioners.size() + ' practitioners');
    }
    
    /**
     * 4. Seed HealthcareProvider records
     */
    private void seedHealthcareProviders() {
        System.debug('Seeding Healthcare Providers...');
        
        List<HealthcareProvider> providers = new List<HealthcareProvider>();
        
        for (String lastName : practitionerMap.keySet()) {
            providers.add(new HealthcareProvider(
                Name = 'Dr. ' + lastName,
                PractitionerId = practitionerMap.get(lastName),
                IsActive = true
            ));
        }
        
        insert providers;
        
        for (HealthcareProvider provider : providers) {
            // Extract last name from "Dr. LastName"
            String lastName = provider.Name.replace('Dr. ', '');
            providerMap.put(lastName, provider.Id);
        }
        
        System.debug('Inserted ' + providers.size() + ' healthcare providers');
    }
    
    /**
     * 5. Seed HealthcareFacility records
     */
    private void seedHealthcareFacilities() {
        System.debug('Seeding Healthcare Facilities...');
        
        List<HealthcareFacility> facilities = new List<HealthcareFacility>{
            new HealthcareFacility(
                Name = 'Onco Global Mumbai',
                AccountId = hospitalAccountId,
                LocationId = locationMap.get('Mumbai'),
                Max_Daily_Appointments__c = 50,
                LicensedBedCount = 150
            ),
            new HealthcareFacility(
                Name = 'Onco Global Delhi NCR',
                AccountId = hospitalAccountId,
                LocationId = locationMap.get('Delhi'),
                Max_Daily_Appointments__c = 40,
                LicensedBedCount = 120
            ),
            new HealthcareFacility(
                Name = 'Onco Global Jaipur',
                AccountId = hospitalAccountId,
                LocationId = locationMap.get('Jaipur'),
                Max_Daily_Appointments__c = 30,
                LicensedBedCount = 80
            ),
            new HealthcareFacility(
                Name = 'Onco Global Bengaluru',
                AccountId = hospitalAccountId,
                LocationId = locationMap.get('Bengaluru'),
                Max_Daily_Appointments__c = 45,
                LicensedBedCount = 130
            ),
            new HealthcareFacility(
                Name = 'Onco Global Hyderabad',
                AccountId = hospitalAccountId,
                LocationId = locationMap.get('Hyderabad'),
                Max_Daily_Appointments__c = 35,
                LicensedBedCount = 100
            )
        };
        
        insert facilities;
        
        for (HealthcareFacility facility : facilities) {
            String city = facility.Name.contains('Mumbai') ? 'Mumbai' :
                         facility.Name.contains('Delhi') ? 'Delhi' :
                         facility.Name.contains('Jaipur') ? 'Jaipur' :
                         facility.Name.contains('Bengaluru') ? 'Bengaluru' : 'Hyderabad';
            facilityMap.put(city, facility.Id);
        }
        
        System.debug('Inserted ' + facilities.size() + ' healthcare facilities');
    }
    
    /**
     * 6. Seed OperatingHours records
     */
    private void seedOperatingHours() {
        System.debug('Seeding Operating Hours...');
        
        List<OperatingHours> hours = new List<OperatingHours>{
            new OperatingHours(Name = 'Mumbai OPD — Weekdays', TimeZone = 'Asia/Kolkata'),
            new OperatingHours(Name = 'Delhi OPD — Weekdays', TimeZone = 'Asia/Kolkata'),
            new OperatingHours(Name = 'Jaipur OPD — Weekdays', TimeZone = 'Asia/Kolkata'),
            new OperatingHours(Name = 'Bengaluru OPD — Weekdays', TimeZone = 'Asia/Kolkata'),
            new OperatingHours(Name = 'Hyderabad OPD — Weekdays', TimeZone = 'Asia/Kolkata')
        };
        
        insert hours;
        
        for (OperatingHours oh : hours) {
            String city = oh.Name.contains('Mumbai') ? 'Mumbai' :
                         oh.Name.contains('Delhi') ? 'Delhi' :
                         oh.Name.contains('Jaipur') ? 'Jaipur' :
                         oh.Name.contains('Bengaluru') ? 'Bengaluru' : 'Hyderabad';
            hoursMap.put(city, oh.Id);
        }
        
        System.debug('Inserted ' + hours.size() + ' operating hours');
    }
    
    /**
     * 7. Seed TimeSlot records
     */
    private void seedTimeSlots() {
        System.debug('Seeding Time Slots...');
        
        List<TimeSlot> slots = new List<TimeSlot>();
        
        // Mumbai: Split sessions (morning 09:00-13:00, afternoon 14:00-18:00)
        for (String day : new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'}) {
            slots.add(new TimeSlot(OperatingHoursId = hoursMap.get('Mumbai'), DayOfWeek = day, 
                                  StartTime = Time.newInstance(9, 0, 0, 0), EndTime = Time.newInstance(13, 0, 0, 0)));
            slots.add(new TimeSlot(OperatingHoursId = hoursMap.get('Mumbai'), DayOfWeek = day, 
                                  StartTime = Time.newInstance(14, 0, 0, 0), EndTime = Time.newInstance(18, 0, 0, 0)));
        }
        slots.add(new TimeSlot(OperatingHoursId = hoursMap.get('Mumbai'), DayOfWeek = 'Saturday', 
                              StartTime = Time.newInstance(9, 0, 0, 0), EndTime = Time.newInstance(13, 0, 0, 0)));
        
        // Delhi, Jaipur, Hyderabad: Continuous 09:00-17:00
        for (String city : new List<String>{'Delhi', 'Jaipur', 'Hyderabad'}) {
            for (String day : new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'}) {
                Time endTime = (day == 'Saturday') ? Time.newInstance(13, 0, 0, 0) : Time.newInstance(17, 0, 0, 0);
                slots.add(new TimeSlot(OperatingHoursId = hoursMap.get(city), DayOfWeek = day, 
                                      StartTime = Time.newInstance(9, 0, 0, 0), EndTime = endTime));
            }
        }
        
        // Bengaluru: Full day Mon-Fri 09:00-18:00, Sat 09:00-13:00
        for (String day : new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'}) {
            slots.add(new TimeSlot(OperatingHoursId = hoursMap.get('Bengaluru'), DayOfWeek = day, 
                                  StartTime = Time.newInstance(9, 0, 0, 0), EndTime = Time.newInstance(18, 0, 0, 0)));
        }
        slots.add(new TimeSlot(OperatingHoursId = hoursMap.get('Bengaluru'), DayOfWeek = 'Saturday', 
                              StartTime = Time.newInstance(9, 0, 0, 0), EndTime = Time.newInstance(13, 0, 0, 0)));
        
        insert slots;
        
        System.debug('Inserted ' + slots.size() + ' time slots');
    }
    
    /**
     * 8. Update HealthcareFacility with OperatingHours lookup
     */
    private void updateFacilityOperatingHours() {
        System.debug('Linking Facilities to Operating Hours...');
        
        List<HealthcareFacility> facilities = [SELECT Id, Name FROM HealthcareFacility WHERE Id IN :facilityMap.values()];
        
        for (HealthcareFacility facility : facilities) {
            String city = facility.Name.contains('Mumbai') ? 'Mumbai' :
                         facility.Name.contains('Delhi') ? 'Delhi' :
                         facility.Name.contains('Jaipur') ? 'Jaipur' :
                         facility.Name.contains('Bengaluru') ? 'Bengaluru' : 'Hyderabad';
            facility.OPD_Operating_Hours__c = hoursMap.get(city);
        }
        
        update facilities;
        
        System.debug('Updated ' + facilities.size() + ' facilities with operating hours');
    }
    
    /**
     * 9. Seed HealthcarePractitionerFacility records
     */
    private void seedHealthcarePractitionerFacilities() {
        System.debug('Seeding Healthcare Practitioner Facilities...');
        
        List<HealthcarePractitionerFacility> practFacilities = new List<HealthcarePractitionerFacility>{
            // Mumbai providers
            new HealthcarePractitionerFacility(Name='Sneha Nair @ Mumbai', HealthcareProviderId=providerMap.get('Nair'), 
                                              HealthcareFacilityId=facilityMap.get('Mumbai'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Sneha Nair @ Jaipur', HealthcareProviderId=providerMap.get('Nair'), 
                                              HealthcareFacilityId=facilityMap.get('Jaipur'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Amit Deshmukh @ Mumbai', HealthcareProviderId=providerMap.get('Deshmukh'), 
                                              HealthcareFacilityId=facilityMap.get('Mumbai'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Anita Singh @ Mumbai', HealthcareProviderId=providerMap.get('Singh'), 
                                              HealthcareFacilityId=facilityMap.get('Mumbai'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Rajesh Pillai @ Mumbai', HealthcareProviderId=providerMap.get('Pillai'), 
                                              HealthcareFacilityId=facilityMap.get('Mumbai'), IsActive=true),
            // Delhi providers
            new HealthcarePractitionerFacility(Name='Ravi Chandra @ Delhi', HealthcareProviderId=providerMap.get('Chandra'), 
                                              HealthcareFacilityId=facilityMap.get('Delhi'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Ravi Chandra @ Jaipur', HealthcareProviderId=providerMap.get('Chandra'), 
                                              HealthcareFacilityId=facilityMap.get('Jaipur'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Priya Kapoor @ Delhi', HealthcareProviderId=providerMap.get('Kapoor'), 
                                              HealthcareFacilityId=facilityMap.get('Delhi'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Vikram Joshi @ Delhi', HealthcareProviderId=providerMap.get('Joshi'), 
                                              HealthcareFacilityId=facilityMap.get('Delhi'), IsActive=true),
            // Jaipur providers
            new HealthcarePractitionerFacility(Name='Arun Mehta @ Jaipur', HealthcareProviderId=providerMap.get('Mehta'), 
                                              HealthcareFacilityId=facilityMap.get('Jaipur'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Arun Mehta @ Delhi', HealthcareProviderId=providerMap.get('Mehta'), 
                                              HealthcareFacilityId=facilityMap.get('Delhi'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Sanjay Verma @ Jaipur', HealthcareProviderId=providerMap.get('Verma'), 
                                              HealthcareFacilityId=facilityMap.get('Jaipur'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Meera Bhat @ Jaipur', HealthcareProviderId=providerMap.get('Bhat'), 
                                              HealthcareFacilityId=facilityMap.get('Jaipur'), IsActive=true),
            // Bengaluru providers
            new HealthcarePractitionerFacility(Name='Kavita Reddy @ Bengaluru', HealthcareProviderId=providerMap.get('Reddy'), 
                                              HealthcareFacilityId=facilityMap.get('Bengaluru'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Kavita Reddy @ Hyderabad', HealthcareProviderId=providerMap.get('Reddy'), 
                                              HealthcareFacilityId=facilityMap.get('Hyderabad'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Suresh Kumar @ Bengaluru', HealthcareProviderId=providerMap.get('Kumar'), 
                                              HealthcareFacilityId=facilityMap.get('Bengaluru'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Deepak Rao @ Bengaluru', HealthcareProviderId=providerMap.get('Rao'), 
                                              HealthcareFacilityId=facilityMap.get('Bengaluru'), IsActive=true),
            // Hyderabad providers
            new HealthcarePractitionerFacility(Name='Lakshmi Iyer @ Hyderabad', HealthcareProviderId=providerMap.get('Iyer'), 
                                              HealthcareFacilityId=facilityMap.get('Hyderabad'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Rajesh Pillai @ Hyderabad', HealthcareProviderId=providerMap.get('Pillai'), 
                                              HealthcareFacilityId=facilityMap.get('Hyderabad'), IsActive=true),
            new HealthcarePractitionerFacility(Name='Sunita Menon @ Hyderabad', HealthcareProviderId=providerMap.get('Menon'), 
                                              HealthcareFacilityId=facilityMap.get('Hyderabad'), IsActive=true)
        };
        
        insert practFacilities;
        System.debug('Inserted ' + practFacilities.size() + ' practitioner-facility links');
    }
    
    /**
     * 10. Seed HealthcareProviderSpecialty records
     */
    private void seedHealthcareProviderSpecialties() {
        System.debug('Seeding Healthcare Provider Specialties...');
        
        // Map providers to specialties
        Map<String, String> providerSpecialtyMap = new Map<String, String>{
            'Nair' => 'Medical Oncology',
            'Deshmukh' => 'Radiation Oncology',
            'Chandra' => 'Surgical Oncology',
            'Kapoor' => 'Hematology',
            'Mehta' => 'Medical Oncology',
            'Verma' => 'Surgical Oncology',
            'Reddy' => 'Medical Oncology',
            'Kumar' => 'Radiation Oncology',
            'Iyer' => 'Hematology',
            'Pillai' => 'Medical Oncology',
            'Singh' => 'Hematology',
            'Joshi' => 'Medical Oncology',
            'Bhat' => 'Radiation Oncology',
            'Rao' => 'Surgical Oncology',
            'Menon' => 'Surgical Oncology'
        };
        
        List<HealthcareProviderSpecialty> providerSpecialties = new List<HealthcareProviderSpecialty>();
        
        for (String lastName : providerSpecialtyMap.keySet()) {
            String specialtyName = providerSpecialtyMap.get(lastName);
            if (specialtyMap.containsKey(specialtyName) && practitionerMap.containsKey(lastName)) {
                providerSpecialties.add(new HealthcareProviderSpecialty(
                    Name = specialtyName.substring(0, 3) + ' — ' + lastName,
                    PractitionerId = practitionerMap.get(lastName),
                    SpecialtyId = specialtyMap.get(specialtyName),
                    IsPrimarySpecialty = true,
                    IsActive = true
                ));
            }
        }
        
        insert providerSpecialties;
        System.debug('Inserted ' + providerSpecialties.size() + ' provider specialties');
    }
    
    /**
     * 11. Seed Symptom_Specialty_Map__c records
     */
    private void seedSymptomSpecialtyMap() {
        System.debug('Seeding Symptom Specialty Map...');
        
        String disclaimer = 'This is not medical advice. For emergency symptoms, please call local emergency services immediately.';
        
        List<Symptom_Specialty_Map__c> maps = new List<Symptom_Specialty_Map__c>{
            new Symptom_Specialty_Map__c(
                Name = 'Lump neck → Med Onc',
                Keyword_Pattern__c = 'lump neck',
                Match_Priority__c = 10,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Many people discuss symptoms like persistent lumps or swelling in the neck area with our medical oncology team for evaluation. This is navigation guidance, not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Fatigue persistent → Med Onc',
                Keyword_Pattern__c = 'persistent fatigue',
                Match_Priority__c = 8,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Ongoing fatigue concerns are often reviewed by our medical oncology specialists. This helps you connect with the right team, but is not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Breast lump → Med Onc',
                Keyword_Pattern__c = 'breast lump',
                Match_Priority__c = 10,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Questions about breast lumps or changes are commonly discussed with our medical oncology specialists. This is informational guidance, not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Chest pain → Emergency first',
                Keyword_Pattern__c = 'chest pain',
                Match_Priority__c = 11,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Chest pain can be serious. If this is sudden, severe, or you also have shortness of breath, sweating, or pain spreading to the arm or jaw, call local emergency services immediately. If it is not an emergency, we can still help you find the right care team in our network—this message is navigation guidance only, not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Weight loss unexplained → Med Onc',
                Keyword_Pattern__c = 'unexplained weight loss',
                Match_Priority__c = 9,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Unexplained weight loss is often discussed with medical oncology for thorough evaluation. This is guidance only, not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Cough persistent → Rad Onc',
                Keyword_Pattern__c = 'persistent cough',
                Match_Priority__c = 7,
                Recommended_Specialty__c = 'Radiation Oncology',
                Routing_Summary__c = 'Long-lasting cough concerns may be reviewed by radiation oncology or other specialists. This helps guide you, but is not medical advice.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Bleeding abnormal → Surg Onc',
                Keyword_Pattern__c = 'abnormal bleeding',
                Match_Priority__c = 8,
                Recommended_Specialty__c = 'Surgical Oncology',
                Routing_Summary__c = 'Abnormal bleeding concerns may be reviewed by surgical oncology specialists. This helps you find the right team, not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Blood disorder → Hematology',
                Keyword_Pattern__c = 'blood disorder',
                Match_Priority__c = 10,
                Recommended_Specialty__c = 'Hematology',
                Routing_Summary__c = 'Blood-related concerns are typically reviewed by our hematology team. This helps connect you with appropriate specialists.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Anemia symptoms → Hematology',
                Keyword_Pattern__c = 'anemia',
                Match_Priority__c = 8,
                Recommended_Specialty__c = 'Hematology',
                Routing_Summary__c = 'Anemia and related symptoms are commonly discussed with hematology specialists for evaluation.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Lymph node swelling → Med Onc',
                Keyword_Pattern__c = 'lymph node swelling',
                Match_Priority__c = 9,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Swollen lymph nodes are often evaluated by medical oncology specialists. This navigation help is not a diagnosis.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Bone pain → Med Onc',
                Keyword_Pattern__c = 'bone pain',
                Match_Priority__c = 7,
                Recommended_Specialty__c = 'Medical Oncology',
                Routing_Summary__c = 'Persistent bone pain concerns may be discussed with medical oncology. This is informational guidance only.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Night sweats → Hematology',
                Keyword_Pattern__c = 'night sweats',
                Match_Priority__c = 6,
                Recommended_Specialty__c = 'Hematology',
                Routing_Summary__c = 'Persistent night sweats may be reviewed by hematology or other specialists. This helps guide your inquiry.',
                Disclaimer__c = disclaimer,
                Active__c = true
            ),
            new Symptom_Specialty_Map__c(
                Name = 'Difficulty swallowing → Rad Onc',
                Keyword_Pattern__c = 'difficulty swallowing',
                Match_Priority__c = 8,
                Recommended_Specialty__c = 'Radiation Oncology',
                Routing_Summary__c = 'Swallowing difficulties are often evaluated by radiation oncology or gastroenterology. This is guidance only.',
                Disclaimer__c = disclaimer,
                Active__c = true
            )
        };
        
        insert maps;
        System.debug('Inserted ' + maps.size() + ' symptom specialty maps');
    }
    
    /**
     * 12. Seed Patient_Insurance__c records
     */
    private void seedPatientInsurance() {
        System.debug('Seeding Patient Insurance...');
        
        List<Patient_Insurance__c> insurances = new List<Patient_Insurance__c>{
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Priya_Sharma'),
                Payer_Name__c = 'Star Health',
                Member_Id__c = 'SH-992810',
                Plan_Name__c = 'Gold Plus',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2025, 1, 1),
                Valid_To__c = Date.newInstance(2026, 12, 31),
                Last_Verified_Date__c = Date.newInstance(2026, 4, 1),
                Is_Primary__c = true,
                Notes__c = 'Room rent sub-limit: ₹5000/day'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Anjali_Verma'),
                Payer_Name__c = 'ICICI Lombard',
                Member_Id__c = 'ICICI-78452',
                Plan_Name__c = 'Comprehensive Health',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2024, 6, 1),
                Valid_To__c = Date.newInstance(2027, 5, 31),
                Last_Verified_Date__c = Date.newInstance(2026, 3, 15),
                Is_Primary__c = true,
                Notes__c = 'Full oncology coverage'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Vikram_Singh'),
                Payer_Name__c = 'Max Bupa',
                Member_Id__c = 'MB-556729',
                Plan_Name__c = 'Health Recharge',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2025, 3, 1),
                Valid_To__c = Date.newInstance(2026, 2, 28),
                Last_Verified_Date__c = Date.newInstance(2026, 4, 10),
                Is_Primary__c = true,
                Notes__c = 'Pre-existing covered after 2 years'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Vikram_Singh'),
                Payer_Name__c = 'Niva Bupa',
                Member_Id__c = 'NB-334211',
                Plan_Name__c = 'Senior First',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2024, 1, 1),
                Valid_To__c = Date.newInstance(2026, 12, 31),
                Last_Verified_Date__c = Date.newInstance(2026, 2, 28),
                Is_Primary__c = false,
                Notes__c = 'Secondary coverage'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Meera_Patel'),
                Payer_Name__c = 'HDFC ERGO',
                Member_Id__c = 'HDFC-889342',
                Plan_Name__c = 'Optima Secure',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2023, 7, 1),
                Valid_To__c = Date.newInstance(2026, 6, 30),
                Last_Verified_Date__c = Date.newInstance(2026, 3, 20),
                Is_Primary__c = true,
                Notes__c = 'Cancer care included'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Kavita_Iyer'),
                Payer_Name__c = 'Care Health',
                Member_Id__c = 'CH-445678',
                Plan_Name__c = 'Care Advantage',
                Eligibility_Status__c = 'Pending',
                Valid_From__c = Date.newInstance(2026, 5, 1),
                Valid_To__c = Date.newInstance(2027, 4, 30),
                Last_Verified_Date__c = Date.newInstance(2026, 4, 25),
                Is_Primary__c = true,
                Notes__c = 'Verification in progress'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Shalini_Gupta'),
                Payer_Name__c = 'Religare Health',
                Member_Id__c = 'RH-223456',
                Plan_Name__c = 'Care',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2024, 10, 1),
                Valid_To__c = Date.newInstance(2026, 9, 30),
                Last_Verified_Date__c = Date.newInstance(2026, 3, 5),
                Is_Primary__c = true,
                Notes__c = 'Room: Private ward eligible'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Anil_Joshi'),
                Payer_Name__c = 'New India Assurance',
                Member_Id__c = 'NIA-667788',
                Plan_Name__c = 'Mediclaim',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2023, 4, 1),
                Valid_To__c = Date.newInstance(2026, 3, 31),
                Last_Verified_Date__c = Date.newInstance(2025, 12, 15),
                Is_Primary__c = true,
                Notes__c = 'Government scheme'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Karthik_Bhat'),
                Payer_Name__c = 'Bajaj Allianz',
                Member_Id__c = 'BA-991234',
                Plan_Name__c = 'Health Guard',
                Eligibility_Status__c = 'Active',
                Valid_From__c = Date.newInstance(2025, 2, 1),
                Valid_To__c = Date.newInstance(2027, 1, 31),
                Last_Verified_Date__c = Date.newInstance(2026, 4, 5),
                Is_Primary__c = true,
                Notes__c = 'Day care procedures covered'
            ),
            new Patient_Insurance__c(
                Patient__c = patientMap.get('Sunita_Kapoor'),
                Payer_Name__c = 'United India',
                Member_Id__c = 'UI-554332',
                Plan_Name__c = 'Comprehensive',
                Eligibility_Status__c = 'Pending',
                Valid_From__c = Date.newInstance(2026, 4, 15),
                Valid_To__c = Date.newInstance(2027, 4, 14),
                Last_Verified_Date__c = Date.newInstance(2026, 4, 20),
                Is_Primary__c = true,
                Notes__c = 'New policy under review'
            )
        };
        
        insert insurances;
        System.debug('Inserted ' + insurances.size() + ' patient insurance records');
    }
    
    /**
     * 13. Seed Facility_Room_Rate__c records
     */
    private void seedFacilityRoomRates() {
        System.debug('Seeding Facility Room Rates...');
        
        List<Facility_Room_Rate__c> rates = new List<Facility_Room_Rate__c>();
        
        // Mumbai rates
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Mumbai'),
            Room_Type__c = 'General',
            Daily_Rate__c = 8000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Mumbai'),
            Room_Type__c = 'Private',
            Daily_Rate__c = 15000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Mumbai'),
            Room_Type__c = 'ICU',
            Daily_Rate__c = 25000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        
        // Delhi rates
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Delhi'),
            Room_Type__c = 'General',
            Daily_Rate__c = 7000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Delhi'),
            Room_Type__c = 'Private',
            Daily_Rate__c = 12000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Delhi'),
            Room_Type__c = 'ICU',
            Daily_Rate__c = 22000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        
        // Jaipur rates
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Jaipur'),
            Room_Type__c = 'General',
            Daily_Rate__c = 5000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Jaipur'),
            Room_Type__c = 'Private',
            Daily_Rate__c = 10000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Jaipur'),
            Room_Type__c = 'ICU',
            Daily_Rate__c = 18000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        
        // Bengaluru rates
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Bengaluru'),
            Room_Type__c = 'General',
            Daily_Rate__c = 7500,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Bengaluru'),
            Room_Type__c = 'Private',
            Daily_Rate__c = 14000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Bengaluru'),
            Room_Type__c = 'ICU',
            Daily_Rate__c = 24000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        
        // Hyderabad rates
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Hyderabad'),
            Room_Type__c = 'General',
            Daily_Rate__c = 6500,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Hyderabad'),
            Room_Type__c = 'Private',
            Daily_Rate__c = 11000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        rates.add(new Facility_Room_Rate__c(
            Healthcare_Facility__c = facilityMap.get('Hyderabad'),
            Room_Type__c = 'ICU',
            Daily_Rate__c = 20000,
            Effective_From__c = Date.newInstance(2026, 1, 1)
        ));
        
        insert rates;
        System.debug('Inserted ' + rates.size() + ' facility room rates');
    }
    
    /**
     * 14. Seed ServiceAppointment records
     */
    private void seedServiceAppointments() {
        System.debug('Seeding Service Appointments...');
        
        List<ServiceAppointment> appointments = new List<ServiceAppointment>{
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Arjun_Reddy'),
                ContactId = patientContactMap.get('Arjun_Reddy'),
                SchedStartTime = Datetime.newInstance(2026, 5, 5, 10, 0, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 5, 10, 30, 0),
                Status = 'Scheduled',
                Subject = 'Consultation — Medical Oncology'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Karthik_Bhat'),
                ContactId = patientContactMap.get('Karthik_Bhat'),
                SchedStartTime = Datetime.newInstance(2026, 5, 5, 14, 0, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 5, 14, 30, 0),
                Status = 'Scheduled',
                Subject = 'Follow-up — Radiation Oncology'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Meera_Patel'),
                ContactId = patientContactMap.get('Meera_Patel'),
                SchedStartTime = Datetime.newInstance(2026, 5, 5, 15, 0, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 5, 15, 30, 0),
                Status = 'Scheduled',
                Subject = 'Review — Hematology'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Anil_Joshi'),
                ContactId = patientContactMap.get('Anil_Joshi'),
                SchedStartTime = Datetime.newInstance(2026, 5, 8, 11, 0, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 8, 11, 30, 0),
                Status = 'Scheduled',
                Subject = 'Consultation — Medical Oncology'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Lakshmi_Menon'),
                ContactId = patientContactMap.get('Lakshmi_Menon'),
                SchedStartTime = Datetime.newInstance(2026, 5, 12, 9, 30, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 12, 10, 0, 0),
                Status = 'Scheduled',
                Subject = 'Pre-op consultation'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Deepa_Rao'),
                ContactId = patientContactMap.get('Deepa_Rao'),
                SchedStartTime = Datetime.newInstance(2026, 5, 15, 16, 0, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 15, 16, 30, 0),
                Status = 'Scheduled',
                Subject = 'Chemotherapy session'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Priya_Sharma'),
                ContactId = patientContactMap.get('Priya_Sharma'),
                SchedStartTime = Datetime.newInstance(2026, 5, 20, 10, 30, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 20, 11, 0, 0),
                Status = 'Scheduled',
                Subject = 'Follow-up — Medical Oncology'
            ),
            new ServiceAppointment(
                ParentRecordId = patientMap.get('Rajesh_Kumar'),
                ContactId = patientContactMap.get('Rajesh_Kumar'),
                SchedStartTime = Datetime.newInstance(2026, 5, 22, 14, 30, 0),
                SchedEndTime = Datetime.newInstance(2026, 5, 22, 15, 0, 0),
                Status = 'Scheduled',
                Subject = 'Initial consultation'
            )
        };
        
        insert appointments;
        
        // Track appointment Ids for subsequent objects
        Integer index = 1;
        for (ServiceAppointment appt : appointments) {
            appointmentMap.put('SA_' + index, appt.Id);
            index++;
        }
        
        System.debug('Inserted ' + appointments.size() + ' service appointments');
    }
    
    /**
     * 15. Seed ClinicalEncounter records
     */
    private void seedClinicalEncounters() {
        System.debug('Seeding Clinical Encounters...');
        
        List<ClinicalEncounter> encounters = new List<ClinicalEncounter>{
            new ClinicalEncounter(
                PatientId = patientMap.get('Arjun_Reddy'),
                FacilityId = facilityMap.get('Hyderabad'),
                StartDate = Datetime.newInstance(2026, 5, 5, 10, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 10, 30, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_1')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Karthik_Bhat'),
                FacilityId = facilityMap.get('Bengaluru'),
                StartDate = Datetime.newInstance(2026, 5, 5, 14, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 14, 30, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_2')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Meera_Patel'),
                FacilityId = facilityMap.get('Hyderabad'),
                StartDate = Datetime.newInstance(2026, 5, 5, 15, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 15, 30, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_3')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Anil_Joshi'),
                FacilityId = facilityMap.get('Mumbai'),
                StartDate = Datetime.newInstance(2026, 5, 8, 11, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 8, 11, 30, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_4')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Lakshmi_Menon'),
                FacilityId = facilityMap.get('Bengaluru'),
                StartDate = Datetime.newInstance(2026, 5, 12, 9, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 12, 10, 0, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_5')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Deepa_Rao'),
                FacilityId = facilityMap.get('Jaipur'),
                StartDate = Datetime.newInstance(2026, 5, 15, 16, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 15, 16, 30, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_6')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Priya_Sharma'),
                FacilityId = facilityMap.get('Jaipur'),
                StartDate = Datetime.newInstance(2026, 5, 20, 10, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 20, 11, 0, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_7')
            ),
            new ClinicalEncounter(
                PatientId = patientMap.get('Rajesh_Kumar'),
                FacilityId = facilityMap.get('Mumbai'),
                StartDate = Datetime.newInstance(2026, 5, 22, 14, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 22, 15, 0, 0),
                Status = 'Scheduled',
                Category = 'Outpatient',
                ServiceAppointmentId = appointmentMap.get('SA_8')
            )
        };
        
        insert encounters;
        
        // Track encounter Ids for subsequent objects
        Integer index = 1;
        for (ClinicalEncounter enc : encounters) {
            encounterMap.put('CE_' + index, enc.Id);
            index++;
        }
        
        System.debug('Inserted ' + encounters.size() + ' clinical encounters');
    }
    
    /**
     * 16. Seed ClinicalEncounterProvider records
     */
    private void seedClinicalEncounterProviders() {
        System.debug('Seeding Clinical Encounter Providers...');
        
        List<ClinicalEncounterProvider> encProviders = new List<ClinicalEncounterProvider>{
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_1'),
                PractitionerId = practitionerMap.get('Pillai'),
                StartDate = Datetime.newInstance(2026, 5, 5, 10, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 10, 30, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_2'),
                PractitionerId = practitionerMap.get('Kumar'),
                StartDate = Datetime.newInstance(2026, 5, 5, 14, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 14, 30, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_3'),
                PractitionerId = practitionerMap.get('Iyer'),
                StartDate = Datetime.newInstance(2026, 5, 5, 15, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 5, 15, 30, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_4'),
                PractitionerId = practitionerMap.get('Nair'),
                StartDate = Datetime.newInstance(2026, 5, 8, 11, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 8, 11, 30, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_5'),
                PractitionerId = practitionerMap.get('Rao'),
                StartDate = Datetime.newInstance(2026, 5, 12, 9, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 12, 10, 0, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_6'),
                PractitionerId = practitionerMap.get('Mehta'),
                StartDate = Datetime.newInstance(2026, 5, 15, 16, 0, 0),
                EndDate = Datetime.newInstance(2026, 5, 15, 16, 30, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_7'),
                PractitionerId = practitionerMap.get('Mehta'),
                StartDate = Datetime.newInstance(2026, 5, 20, 10, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 20, 11, 0, 0)
            ),
            new ClinicalEncounterProvider(
                ClinicalEncounterId = encounterMap.get('CE_8'),
                PractitionerId = practitionerMap.get('Nair'),
                StartDate = Datetime.newInstance(2026, 5, 22, 14, 30, 0),
                EndDate = Datetime.newInstance(2026, 5, 22, 15, 0, 0)
            )
        };
        
        insert encProviders;
        System.debug('Inserted ' + encProviders.size() + ' clinical encounter providers');
    }
    
    /**
     * 17. Seed Counselling_Prerequisite__c records
     */
    private void seedCounsellingPrerequisites() {
        System.debug('Seeding Counselling Prerequisites...');
        
        List<Counselling_Prerequisite__c> prereqs = new List<Counselling_Prerequisite__c>{
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_1'),
                Document_Type__c = 'Lab report',
                Is_Required__c = true,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 4, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_1'),
                Document_Type__c = 'Insurance card',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 4, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_3'),
                Document_Type__c = 'ID',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 4, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_3'),
                Document_Type__c = 'Consent',
                Is_Required__c = true,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 5, 9, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_4'),
                Document_Type__c = 'Lab report',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 7, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_5'),
                Document_Type__c = 'Insurance card',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 11, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_5'),
                Document_Type__c = 'Consent',
                Is_Required__c = true,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 11, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_6'),
                Document_Type__c = 'Lab report',
                Is_Required__c = false,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 14, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_7'),
                Document_Type__c = 'Lab report',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 19, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_7'),
                Document_Type__c = 'Insurance card',
                Is_Required__c = true,
                Is_Satisfied__c = true,
                Due_Before__c = Datetime.newInstance(2026, 5, 19, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_8'),
                Document_Type__c = 'ID',
                Is_Required__c = true,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 21, 17, 0, 0)
            ),
            new Counselling_Prerequisite__c(
                Related_Appointment__c = appointmentMap.get('SA_8'),
                Document_Type__c = 'Insurance card',
                Is_Required__c = true,
                Is_Satisfied__c = false,
                Due_Before__c = Datetime.newInstance(2026, 5, 21, 17, 0, 0)
            )
        };
        
        insert prereqs;
        System.debug('Inserted ' + prereqs.size() + ' counselling prerequisites');
    }
    
    /**
     * 18. Seed Booking_Session__c records
     */
    private void seedBookingSessions() {
        System.debug('Seeding Booking Sessions...');
        
        List<Booking_Session__c> sessions = new List<Booking_Session__c>{
            new Booking_Session__c(
                Patient__c = patientMap.get('Priya_Sharma'),
                Last_Service_Appointment__c = appointmentMap.get('SA_7'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_7'),
                Preferred_Facility__c = facilityMap.get('Jaipur'),
                Context_Token__c = 'sess_a1b2c3d4e5'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Meera_Patel'),
                Last_Service_Appointment__c = appointmentMap.get('SA_3'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_3'),
                Preferred_Facility__c = facilityMap.get('Hyderabad'),
                Context_Token__c = 'sess_f6g7h8i9j0'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Lakshmi_Menon'),
                Last_Service_Appointment__c = appointmentMap.get('SA_5'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_5'),
                Preferred_Facility__c = facilityMap.get('Bengaluru'),
                Context_Token__c = 'sess_k1l2m3n4o5'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Arjun_Reddy'),
                Last_Service_Appointment__c = appointmentMap.get('SA_1'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_1'),
                Preferred_Facility__c = facilityMap.get('Hyderabad'),
                Context_Token__c = 'sess_p6q7r8s9t0'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Karthik_Bhat'),
                Last_Service_Appointment__c = appointmentMap.get('SA_2'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_2'),
                Preferred_Facility__c = facilityMap.get('Bengaluru'),
                Context_Token__c = 'sess_u1v2w3x4y5'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Anil_Joshi'),
                Last_Service_Appointment__c = appointmentMap.get('SA_4'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_4'),
                Preferred_Facility__c = facilityMap.get('Mumbai'),
                Context_Token__c = 'sess_z6a7b8c9d0'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Deepa_Rao'),
                Last_Service_Appointment__c = appointmentMap.get('SA_6'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_6'),
                Preferred_Facility__c = facilityMap.get('Jaipur'),
                Context_Token__c = 'sess_e1f2g3h4i5'
            ),
            new Booking_Session__c(
                Patient__c = patientMap.get('Rajesh_Kumar'),
                Last_Service_Appointment__c = appointmentMap.get('SA_8'),
                Last_Clinical_Encounter__c = encounterMap.get('CE_8'),
                Preferred_Facility__c = facilityMap.get('Mumbai'),
                Context_Token__c = 'sess_j6k7l8m9n0'
            )
        };
        
        insert sessions;
        System.debug('Inserted ' + sessions.size() + ' booking sessions');
    }
}
