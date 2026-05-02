/**
 * Lists HealthcareFacility records for the agent and Enhanced Web Chat.
 * Single invocable output: facilityListUi (HCFacilityListUiModel). Parse payload JSON for
 * success, message, summaryText, rows — agent + Enhanced Web Chat (same filters as HC_Get_Facilities flow).
 */
public without sharing class HCFacilityListInvocable {
    private static final Integer MAX_ROWS = 25;

    public class GetFacilitiesRequest {
        @InvocableVariable(
            label = 'City keyword'
            description = 'Filters HealthcareFacility.Name CONTAINS keyword; leave blank for first 25 facilities alphabetically by name.'
        )
        public String input_CityKeyword;
    }

    public class GetFacilitiesResult {
        @InvocableVariable(
            label = 'Facility list result'
            description = 'Only output: read payload for success, message, summaryText, and rows (hcFacilityCardList / planner).'
        )
        public HCFacilityListUiModel facilityListUi;
    }

    /** One row in facilityListUi.payload JSON (matches hcFacilityCardList). */
    public class FacilityUiRow {
        public String facilityId;
        public String facilityName;
        public String line;
    }

    /** Top-level JSON object stored in HCFacilityListUiModel.payload. */
    public class FacilityListPayload {
        public Boolean success;
        public String message;
        public String summaryText;
        public List<FacilityUiRow> rows;
    }

    @InvocableMethod(
        label = 'HC Get Facilities'
        description = 'Lists HealthcareFacility sites (max 25): optional Name contains keyword, else all alpha by name. Returns one facilityListUi with full JSON payload for agent and UI.'
        category = 'Health Cloud'
    )
    public static List<GetFacilitiesResult> getFacilities(List<GetFacilitiesRequest> requests) {
        List<GetFacilitiesResult> results = new List<GetFacilitiesResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        GetFacilitiesRequest req = requests[0];
        GetFacilitiesResult out = new GetFacilitiesResult();
        try {
            String kw = req.input_CityKeyword == null ? '' : req.input_CityKeyword.trim();
            List<HealthcareFacility> rows;
            if (String.isBlank(kw)) {
                rows = [
                    SELECT Id, Name
                    FROM HealthcareFacility
                    ORDER BY Name ASC
                    LIMIT :MAX_ROWS
                ];
            } else {
                String likeKw = '%' + kw + '%';
                rows = [
                    SELECT Id, Name
                    FROM HealthcareFacility
                    WHERE Name LIKE :likeKw
                    ORDER BY Name ASC
                    LIMIT :MAX_ROWS
                ];
            }

            if (rows.isEmpty()) {
                String summary = 'No facilities matched your search.';
                out.facilityListUi = wrapUi(true, '', summary, new List<FacilityUiRow>());
            } else {
                List<String> lines = new List<String>();
                List<FacilityUiRow> uiRows = new List<FacilityUiRow>();
                for (HealthcareFacility f : rows) {
                    String line = '- ' + f.Name;
                    lines.add(line);
                    FacilityUiRow ur = new FacilityUiRow();
                    ur.facilityId = f.Id;
                    ur.facilityName = f.Name;
                    ur.line = line;
                    uiRows.add(ur);
                }
                out.facilityListUi = wrapUi(true, '', String.join(lines, '\n'), uiRows);
            }
        } catch (Exception e) {
            String summary = 'Unable to list facilities: ' + e.getMessage();
            out.facilityListUi = wrapUi(false, e.getMessage(), summary, new List<FacilityUiRow>());
        }
        results.add(out);
        return results;
    }

    private static HCFacilityListUiModel wrapUi(
        Boolean success,
        String message,
        String summary,
        List<FacilityUiRow> rows
    ) {
        FacilityListPayload wrap = new FacilityListPayload();
        wrap.success = success;
        wrap.message = message == null ? '' : message;
        wrap.summaryText = summary == null ? '' : summary;
        wrap.rows = rows == null ? new List<FacilityUiRow>() : rows;
        HCFacilityListUiModel m = new HCFacilityListUiModel();
        m.payload = JSON.serialize(wrap);
        return m;
    }
}
