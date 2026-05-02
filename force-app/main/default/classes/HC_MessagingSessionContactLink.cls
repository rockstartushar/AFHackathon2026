/**
 * Sets MessagingSession.EndUserContactId after a guest is verified or registered (Person Account).
 * Call from a Flow/GenAI action after HC_Resolve_Patient_By_Phone or HC_Create_Guest_Person_Account
 * with the current session Id and output_PatientAccountId.
 */
public without sharing class HC_MessagingSessionContactLink {
    public class LinkRequest {
        @InvocableVariable(
            required=true
            label='Messaging Session Id'
            description='The active MessagingSession to link (from conversation context).'
        )
        public Id messagingSessionId;
        @InvocableVariable(
            label='Patient Account Id'
            description='Person Account Id from patient resolution/registration (output_PatientAccountId).'
        )
        public Id patientAccountId;
        @InvocableVariable(
            label='Contact Id'
            description='Optional Person Contact Id. If both Account and Contact are set, they must match the same patient.'
        )
        public Id contactId;
    }

    public class LinkResult {
        @InvocableVariable(description='True when EndUserContactId was set.')
        public Boolean success;
        @InvocableVariable(description='Empty on success; details on failure.')
        public String message;
    }

    @InvocableMethod(
        label='HC Link Messaging Session to Patient'
        description='Populates EndUserContactId on MessagingSession from a verified Person Account or Contact. Use after unique patient match or new guest creation.'
        category='Health Cloud'
    )
    public static List<LinkResult> linkToVerifiedPatient(List<LinkRequest> requests) {
        List<LinkResult> results = new List<LinkResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> accountIds = new Set<Id>();
        for (LinkRequest req : requests) {
            if (req != null && req.patientAccountId != null) {
                accountIds.add(req.patientAccountId);
            }
        }
        Map<Id, Account> personById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            for (Account a : [
                SELECT Id, PersonContactId, IsPersonAccount
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                personById.put(a.Id, a);
            }
        }

        List<SObject> toUpdate = new List<SObject>();
        List<Integer> updateIndexByRow = new List<Integer>();

        Integer idx = 0;
        for (LinkRequest req : requests) {
            LinkResult lr = new LinkResult();
            lr.success = false;
            lr.message = '';
            results.add(lr);

            if (req == null) {
                lr.message = 'Request row is required.';
                idx++;
                continue;
            }
            if (req.messagingSessionId == null) {
                lr.message = 'messagingSessionId is required.';
                idx++;
                continue;
            }
            try {
                Id resolvedContact = resolvePersonContact(req, personById);
                if (resolvedContact == null) {
                    lr.message =
                        'Provide patientAccountId (Person Account) and/or contactId; could not resolve Person Contact.';
                    idx++;
                    continue;
                }
                SObject msRow = Schema.MessagingSession.SObjectType.newSObject(req.messagingSessionId);
                msRow.put('EndUserContactId', resolvedContact);
                toUpdate.add(msRow);
                updateIndexByRow.add(idx);
            } catch (Exception e) {
                lr.message = e.getMessage();
            }
            idx++;
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] srs = Database.update(toUpdate, false);
            for (Integer i = 0; i < srs.size(); i++) {
                Integer resultIdx = updateIndexByRow[i];
                LinkResult lr = results[resultIdx];
                if (srs[i].isSuccess()) {
                    lr.success = true;
                    lr.message = '';
                } else {
                    lr.success = false;
                    lr.message = srs[i].getErrors().isEmpty()
                        ? 'Update failed.'
                        : srs[i].getErrors()[0].getMessage();
                }
            }
        }

        return results;
    }

    private static Id resolvePersonContact(LinkRequest req, Map<Id, Account> personById) {
        Id fromAccount = null;
        if (req.patientAccountId != null) {
            Account a = personById.get(req.patientAccountId);
            if (a == null) {
                throw new IllegalArgumentException('Patient Account not found: ' + req.patientAccountId);
            }
            if (a.IsPersonAccount != true || a.PersonContactId == null) {
                throw new IllegalArgumentException(
                    'Patient Account must be a Person Account with PersonContactId.'
                );
            }
            fromAccount = a.PersonContactId;
        }

        if (req.contactId != null && fromAccount != null && req.contactId != fromAccount) {
            throw new IllegalArgumentException(
                'contactId does not match PersonContactId on the given Patient Account.'
            );
        }
        if (req.contactId != null) {
            return req.contactId;
        }
        return fromAccount;
    }

    /**
     * Optional: call from internal LWCs that have MessagingSession Id after resolve/create guest.
     */
    @AuraEnabled
    public static Map<String, Object> linkSessionToPatient(Id messagingSessionId, Id patientAccountId) {
        LinkRequest req = new LinkRequest();
        req.messagingSessionId = messagingSessionId;
        req.patientAccountId = patientAccountId;
        List<LinkResult> out = linkToVerifiedPatient(new List<LinkRequest>{ req });
        LinkResult r = out.isEmpty() ? null : out[0];
        return new Map<String, Object>{
            'success' => r != null && r.success == true,
            'message' => r != null ? r.message : 'No result.'
        };
    }
}
