/**
 * Invocable directory queries for Agentforce and Flow callers.
 * See docs/BOOKING_PATTERN.md and docs/Data-Model-Objects-And-Fields.md.
 */
public without sharing class HC_DirectoryInvocable {
    public class FindSpecialistRequest {
        @InvocableVariable(
            label='City keyword'
            description='Filters by HealthcareFacility.Name (contains match). Leave blank to search by specialty only or broaden results.'
        )
        public String cityKeyword;
        @InvocableVariable(
            label='Specialty name'
            description='Filters by Specialty.Name on active provider-specialty rows (e.g. medical oncology, gynecologic oncology). Leave blank for city-only listing.'
        )
        public String specialtyName;
        @InvocableVariable(
            label='Max rows'
            description='Maximum lines to return; capped at 25. Default 10 when null.'
        )
        public Integer topN;
    }

    public class FindSpecialistResult {
        @InvocableVariable(label='Summary text' description='Plain-text lines for the agent.')
        public String summaryText;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(
            label = 'Directory UI model'
            description = 'Custom Lightning Type payload for Enhanced Web Chat (hcDirectoryResultsRenderer).'
        )
        public HCDirectoryUiModel directoryUi;
    }

    @InvocableMethod(
        label='HC Find Specialist'
        description='Query the care network: list doctors and sites by city and/or specialty. Use for "find a medical oncologist in Hyderabad", "GYN oncology in Chennai", "surgical oncologists in Bengaluru", or "do you have X in [city]". Returns human-readable lines (provider, facility, specialty). Do not use for booking or canceling; use after the user names a city or specialty. If the user only needs a list of all hospital names, prefer HC_Get_Facilities_Chat (or the HC_Get_Facilities Flow for non-agent callers) instead.'
        category='Health Cloud'
    )
    public static List<FindSpecialistResult> findSpecialists(List<FindSpecialistRequest> requests) {
        System.debug('HC_DirectoryInvocable.findSpecialists: requests: ' + requests);
        List<FindSpecialistResult> results = new List<FindSpecialistResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        FindSpecialistRequest r = requests[0];
        Integer limitSize = (r.topN != null && r.topN > 0) ? Math.min(r.topN, 25) : 10;
        String city = String.isBlank(r.cityKeyword) ? null : r.cityKeyword.trim();
        String spec = String.isBlank(r.specialtyName) ? null : r.specialtyName.trim();

        FindSpecialistResult out = new FindSpecialistResult();
        out.success = true;
        try {
            List<HealthcarePractitionerFacility> rows = queryPractitionerFacilities(city, spec, limitSize);
            if (rows.isEmpty()) {
                out.summaryText = 'No matching providers found for your filters.';
                Map<String, Object> emptyWrap = new Map<String, Object>();
                emptyWrap.put('summaryText', out.summaryText);
                emptyWrap.put('rows', new List<Object>());
                out.directoryUi = new HCDirectoryUiModel();
                out.directoryUi.payload = JSON.serialize(emptyWrap);
            } else {
                List<String> lines = new List<String>();
                List<Map<String, Object>> uiRows = new List<Map<String, Object>>();
                for (HealthcarePractitionerFacility row : rows) {
                    String p = row.HealthcareProvider != null ? row.HealthcareProvider.Name : '(Provider)';
                    String f = row.HealthcareFacility != null ? row.HealthcareFacility.Name : '(Facility)';
                    lines.add('- ' + p + ' @ ' + f);
                    Map<String, Object> ur = new Map<String, Object>();
                    ur.put('providerId', row.HealthcareProviderId);
                    ur.put('facilityId', row.HealthcareFacilityId);
                    ur.put('providerName', p);
                    ur.put('facilityName', f);
                    ur.put('line', '- ' + p + ' @ ' + f);
                    uiRows.add(ur);
                }
                out.summaryText = String.join(lines, '\n');
                Map<String, Object> wrap = new Map<String, Object>();
                wrap.put('summaryText', out.summaryText);
                wrap.put('rows', uiRows);
                out.directoryUi = new HCDirectoryUiModel();
                out.directoryUi.payload = JSON.serialize(wrap);
            }
        } catch (Exception e) {
            out.success = false;
            out.summaryText = 'Query failed: ' + e.getMessage();
        }
        results.add(out);
        return results;
    }

    private static List<HealthcarePractitionerFacility> queryPractitionerFacilities(
        String city,
        String spec,
        Integer limitSize
    ) {
        String cityLike = city == null ? null : ('%' + city + '%');
        String specLike = spec == null ? null : ('%' + spec + '%');

        if (cityLike == null && specLike == null) {
            return [
                SELECT Id, HealthcareProviderId, HealthcareFacilityId, HealthcareProvider.Name, HealthcareFacility.Name
                FROM HealthcarePractitionerFacility
                WHERE IsActive = TRUE
                ORDER BY HealthcareFacility.Name, HealthcareProvider.Name
                LIMIT :limitSize
            ];
        }
        if (cityLike != null && specLike == null) {
            return [
                SELECT Id, HealthcareProviderId, HealthcareFacilityId, HealthcareProvider.Name, HealthcareFacility.Name
                FROM HealthcarePractitionerFacility
                WHERE IsActive = TRUE AND HealthcareFacility.Name LIKE :cityLike
                ORDER BY HealthcareFacility.Name, HealthcareProvider.Name
                LIMIT :limitSize
            ];
        }

        // No nested semi-joins: resolve practitioner ids, then provider ids, then HPF.
        Set<Id> practitionerIds = new Set<Id>();
        for (HealthcareProviderSpecialty row : [
            SELECT PractitionerId
            FROM HealthcareProviderSpecialty
            WHERE IsActive = TRUE AND Specialty.Name LIKE :specLike AND PractitionerId != NULL
        ]) {
            practitionerIds.add(row.PractitionerId);
        }
        if (practitionerIds.isEmpty()) {
            return new List<HealthcarePractitionerFacility>();
        }

        Set<Id> providerIds = new Set<Id>();
        for (HealthcareProvider hp : [
            SELECT Id FROM HealthcareProvider WHERE PractitionerId IN :practitionerIds AND IsActive = TRUE
        ]) {
            providerIds.add(hp.Id);
        }
        if (providerIds.isEmpty()) {
            return new List<HealthcarePractitionerFacility>();
        }

        if (cityLike == null) {
            return [
                SELECT Id, HealthcareProviderId, HealthcareFacilityId, HealthcareProvider.Name, HealthcareFacility.Name
                FROM HealthcarePractitionerFacility
                WHERE IsActive = TRUE AND HealthcareProviderId IN :providerIds
                ORDER BY HealthcareFacility.Name, HealthcareProvider.Name
                LIMIT :limitSize
            ];
        }
        return [
            SELECT Id, HealthcareProviderId, HealthcareFacilityId, HealthcareProvider.Name, HealthcareFacility.Name
            FROM HealthcarePractitionerFacility
            WHERE IsActive = TRUE
            AND HealthcareFacility.Name LIKE :cityLike
            AND HealthcareProviderId IN :providerIds
            ORDER BY HealthcareFacility.Name, HealthcareProvider.Name
            LIMIT :limitSize
        ];
    }
}
