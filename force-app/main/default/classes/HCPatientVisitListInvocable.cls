/**
 * Lists ClinicalEncounter / ServiceAppointment visits for a Person Account (reschedule & cancel selection).
 * Shared by HC_SchedulingConsole LWC and GenAi HC_List_Patient_Visits.
 */
public without sharing class HCPatientVisitListInvocable {
    public class ListVisitsRequest {
        @InvocableVariable(
            required = true
            label = 'Patient Account Id'
            description = 'Person Account Id from HC_Resolve_Patient_By_Phone or HC_Create_Guest_Person_Account.'
        )
        public String patientAccountId;
        @InvocableVariable(
            label = 'Healthcare Facility Id'
            description = 'Optional: limit rows to this HealthcareFacility (ClinicalEncounter.FacilityId).'
        )
        public String healthcareFacilityId;
        @InvocableVariable(
            label = 'Healthcare Provider Id'
            description = 'Optional: limit to visits with this provider (via ClinicalEncounterProvider).'
        )
        public String healthcareProviderId;
    }

    public class ListVisitsResult {
        @InvocableVariable(
            label = 'Patient visit list'
            description = 'Parse payload for success, message, summaryText, and rows (serviceAppointmentId, facility, times).'
        )
        public HCPatientVisitListUiModel patientVisitListUi;
    }

    @InvocableMethod(
        label = 'HC List Patient Visits'
        description = 'Lists non-canceled visits for a patient (date, time, facility, provider). Use after identity resolution and before MODIFY or CANCEL so the user can pick which appointment.'
        category = 'Health Cloud'
    )
    public static List<ListVisitsResult> listVisits(List<ListVisitsRequest> requests) {
        List<ListVisitsResult> out = new List<ListVisitsResult>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        ListVisitsRequest req = requests[0];
        ListVisitsResult row = new ListVisitsResult();
        row.patientVisitListUi = buildUiModel(req);
        out.add(row);
        return out;
    }

    /**
     * Map shape used by hcSchedulingConsole (unchanged contract).
     */
    public static Map<String, Object> listVisitsMap(
        String patientAccountId,
        String healthcareFacilityId,
        String healthcareProviderId
    ) {
        ListVisitsRequest req = new ListVisitsRequest();
        req.patientAccountId = patientAccountId;
        req.healthcareFacilityId = healthcareFacilityId;
        req.healthcareProviderId = healthcareProviderId;
        HCPatientVisitListUiModel m = buildUiModel(req);
        if (m == null || String.isBlank(m.payload)) {
            return new Map<String, Object>{
                'success' => false,
                'message' => 'No result',
                'rows' => new List<Map<String, Object>>()
            };
        }
        Map<String, Object> pay = (Map<String, Object>) JSON.deserializeUntyped(m.payload);
        Boolean ok = pay.containsKey('success') ? (Boolean) pay.get('success') : true;
        String msg = pay.containsKey('message') ? (String) pay.get('message') : '';
        List<Object> rows = new List<Object>();
        if (pay.containsKey('rows')) {
            rows = (List<Object>) pay.get('rows');
        }
        return new Map<String, Object>{ 'success' => ok, 'message' => msg, 'rows' => rows };
    }

    private static HCPatientVisitListUiModel buildUiModel(ListVisitsRequest req) {
        HCPatientVisitListUiModel ui = new HCPatientVisitListUiModel();
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (req == null || String.isBlank(req.patientAccountId)) {
            ui.payload = wrapPayload(false, 'Patient Account Id is required.', '', rows);
            return ui;
        }
        try {
            Id pid = (Id) req.patientAccountId.trim();
            Id fid = String.isNotBlank(req.healthcareFacilityId) ? (Id) req.healthcareFacilityId.trim() : null;
            Id hpId = String.isNotBlank(req.healthcareProviderId) ? (Id) req.healthcareProviderId.trim() : null;
            Id practitionerId = null;
            if (hpId != null) {
                List<HealthcareProvider> hps = [
                    SELECT PractitionerId
                    FROM HealthcareProvider
                    WHERE Id = :hpId
                    LIMIT 1
                ];
                practitionerId = (!hps.isEmpty()) ? hps[0].PractitionerId : null;
            }

            List<String> cancelEncounter = new List<String>{ 'Canceled', 'Cancelled' };
            List<String> cancelSa = new List<String>{ 'Canceled', 'Cancelled' };

            List<ClinicalEncounter> encounters = [
                SELECT
                    Id,
                    ServiceAppointmentId,
                    FacilityId,
                    ServiceAppointment.Id,
                    ServiceAppointment.SchedStartTime,
                    ServiceAppointment.SchedEndTime,
                    ServiceAppointment.Status,
                    ServiceAppointment.Subject
                FROM ClinicalEncounter
                WHERE
                    PatientId = :pid
                    AND ServiceAppointmentId != NULL
                    AND (Status NOT IN :cancelEncounter
                    OR Status = NULL)
                LIMIT 500
            ];

            List<VisitSortWrapper> candidates = new List<VisitSortWrapper>();
            Set<Id> facilityIds = new Set<Id>();
            for (ClinicalEncounter ce : encounters) {
                if (ce.ServiceAppointment == null) {
                    continue;
                }
                ServiceAppointment sa = ce.ServiceAppointment;
                if (sa.Status != null && cancelSa.contains(sa.Status)) {
                    continue;
                }
                if (fid != null && ce.FacilityId != fid) {
                    continue;
                }
                if (ce.FacilityId != null) {
                    facilityIds.add(ce.FacilityId);
                }
                candidates.add(new VisitSortWrapper(ce, sa));
            }

            Set<Id> allowedCeIds = null;
            if (practitionerId != null && !candidates.isEmpty()) {
                Set<Id> candCeIds = new Set<Id>();
                for (VisitSortWrapper w : candidates) {
                    candCeIds.add(w.ce.Id);
                }
                allowedCeIds = new Set<Id>();
                for (ClinicalEncounterProvider cep : [
                    SELECT ClinicalEncounterId
                    FROM ClinicalEncounterProvider
                    WHERE ClinicalEncounterId IN :candCeIds AND PractitionerId = :practitionerId
                ]) {
                    allowedCeIds.add(cep.ClinicalEncounterId);
                }
            }

            List<VisitSortWrapper> filtered = new List<VisitSortWrapper>();
            for (VisitSortWrapper w : candidates) {
                if (practitionerId != null) {
                    if (allowedCeIds == null || !allowedCeIds.contains(w.ce.Id)) {
                        continue;
                    }
                }
                filtered.add(w);
            }
            filtered.sort();

            Map<Id, String> facilityNames = new Map<Id, String>();
            if (!facilityIds.isEmpty()) {
                for (HealthcareFacility hf : [SELECT Id, Name FROM HealthcareFacility WHERE Id IN :facilityIds]) {
                    facilityNames.put(hf.Id, hf.Name);
                }
            }

            Set<Id> ceIdsForLabels = new Set<Id>();
            for (VisitSortWrapper w : filtered) {
                ceIdsForLabels.add(w.ce.Id);
            }
            Map<Id, String> ceToClinicianLabel = new Map<Id, String>();
            if (!ceIdsForLabels.isEmpty()) {
                Map<Id, List<String>> nameBuckets = new Map<Id, List<String>>();
                for (ClinicalEncounterProvider cep : [
                    SELECT ClinicalEncounterId, Practitioner.Name
                    FROM ClinicalEncounterProvider
                    WHERE ClinicalEncounterId IN :ceIdsForLabels
                ]) {
                    if (cep.Practitioner == null || String.isBlank(cep.Practitioner.Name)) {
                        continue;
                    }
                    if (!nameBuckets.containsKey(cep.ClinicalEncounterId)) {
                        nameBuckets.put(cep.ClinicalEncounterId, new List<String>());
                    }
                    nameBuckets.get(cep.ClinicalEncounterId).add(cep.Practitioner.Name);
                }
                for (Id ceKey : nameBuckets.keySet()) {
                    ceToClinicianLabel.put(ceKey, String.join(nameBuckets.get(ceKey), ', '));
                }
            }

            List<String> lines = new List<String>();
            Integer n = 1;
            for (VisitSortWrapper w : filtered) {
                ServiceAppointment sa = w.sa;
                ClinicalEncounter ce = w.ce;
                Map<String, Object> row = new Map<String, Object>();
                row.put('serviceAppointmentId', sa.Id);
                row.put(
                    'schedStartIso',
                    sa.SchedStartTime != null ? sa.SchedStartTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : ''
                );
                row.put(
                    'schedEndIso',
                    sa.SchedEndTime != null ? sa.SchedEndTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : ''
                );
                row.put('status', sa.Status);
                row.put('subject', sa.Subject);
                row.put(
                    'facilityName',
                    ce.FacilityId != null && facilityNames.containsKey(ce.FacilityId)
                        ? facilityNames.get(ce.FacilityId)
                        : ''
                );
                row.put(
                    'clinicianName',
                    ceToClinicianLabel.containsKey(ce.Id) ? ceToClinicianLabel.get(ce.Id) : ''
                );
                rows.add(row);

                String line =
                    String.valueOf(n) +
                    ') ' +
                    (String) row.get('facilityName') +
                    ' — ' +
                    formatDt(sa.SchedStartTime) +
                    ' to ' +
                    formatDt(sa.SchedEndTime) +
                    (String.isNotBlank((String) row.get('clinicianName'))
                        ? ' — ' + (String) row.get('clinicianName')
                        : '') +
                    ' [ServiceAppointmentId ' +
                    sa.Id +
                    ']';
                lines.add(line);
                n++;
            }

            String summary;
            if (rows.isEmpty()) {
                summary = 'No active upcoming visits were found for this account.';
            } else {
                summary = 'Your visit(s):\n' + String.join(lines, '\n');
            }
            ui.payload = wrapPayload(true, '', summary, rows);
        } catch (Exception e) {
            ui.payload = wrapPayload(false, e.getMessage(), 'Unable to list visits: ' + e.getMessage(), rows);
        }
        return ui;
    }

    private static String formatDt(Datetime dt) {
        if (dt == null) {
            return '';
        }
        return dt.format();
    }

    private static String wrapPayload(
        Boolean success,
        String message,
        String summary,
        List<Map<String, Object>> visitRows
    ) {
        Map<String, Object> w = new Map<String, Object>();
        w.put('success', success);
        w.put('message', message == null ? '' : message);
        w.put('summaryText', summary == null ? '' : summary);
        w.put('rows', visitRows == null ? new List<Map<String, Object>>() : visitRows);
        return JSON.serialize(w);
    }

    private class VisitSortWrapper implements Comparable {
        ClinicalEncounter ce;
        ServiceAppointment sa;
        VisitSortWrapper(ClinicalEncounter c, ServiceAppointment s) {
            ce = c;
            sa = s;
        }
        public Integer compareTo(Object other) {
            VisitSortWrapper o = (VisitSortWrapper) other;
            Datetime a = sa.SchedStartTime;
            Datetime b = o.sa.SchedStartTime;
            if (a == null && b == null) {
                return 0;
            }
            if (a == null) {
                return 1;
            }
            if (b == null) {
                return -1;
            }
            if (a > b) {
                return -1;
            }
            if (a < b) {
                return 1;
            }
            return 0;
        }
    }
}
