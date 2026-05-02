/**
 * Creates a Task reminder on the patient account for a ServiceAppointment (MVP when email is not configured).
 */
public without sharing class HC_ReminderInvocable {
    public class ReminderRequest {
        @InvocableVariable(
            required=true
            label='Service Appointment Id'
            description='Creates a Task on the patient Person Account linked via ServiceAppointment.ContactId. SA must have ContactId populated.'
        )
        public Id serviceAppointmentId;
        @InvocableVariable(
            label='Correlation Id'
            description='Optional id for Agent_Action_Log / tracing.'
        )
        public String correlationId;
    }

    public class ReminderResult {
        @InvocableVariable(description='Whether the Task was inserted.')
        public Boolean success;
        @InvocableVariable(description='User-facing or error detail.')
        public String message;
        @InvocableVariable(description='Inserted Task Id when success.')
        public Id taskId;
    }

    @InvocableMethod(
        label='HC Create Visit Reminder Task'
        description='Creates an internal Task reminder for an upcoming visit (MVP when email reminders are not configured). Use after a booking is confirmed if the workflow should record a staff/patient reminder. Not a patient SMS or email send by itself.'
        category='Health Cloud'
    )
    public static List<ReminderResult> createReminderTask(List<ReminderRequest> requests) {
        List<ReminderResult> out = new List<ReminderResult>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        ReminderRequest req = requests[0];
        ReminderResult r = new ReminderResult();
        r.success = false;
        try {
            List<ServiceAppointment> saRows = [
                SELECT Id, ContactId, SchedStartTime, Subject, Status
                FROM ServiceAppointment
                WHERE Id = :req.serviceAppointmentId
                LIMIT 1
            ];
            if (saRows.isEmpty()) {
                throw new IllegalArgumentException(
                    'No ServiceAppointment found for this Id (wrong object type, deleted row, or no access). Verify the Id is a ServiceAppointment.'
                );
            }
            ServiceAppointment sa = saRows[0];
            if (sa.ContactId == null) {
                throw new IllegalArgumentException('ServiceAppointment has no ContactId; cannot resolve patient.');
            }
            Account a = [
                SELECT Id, PersonContactId, IsPersonAccount
                FROM Account
                WHERE PersonContactId = :sa.ContactId
                LIMIT 1
            ];
            if (a.IsPersonAccount != true || a.PersonContactId == null) {
                throw new IllegalArgumentException('Reminder requires a Person Account with PersonContactId.');
            }
            Task t = new Task();
            t.Subject = 'Upcoming visit: ' + (String.isNotBlank(sa.Subject) ? sa.Subject.left(200) : 'Appointment');
            t.ActivityDate = sa.SchedStartTime != null ? sa.SchedStartTime.date() : Date.today();
            t.WhoId = a.PersonContactId;
            t.WhatId = a.Id;
            t.OwnerId = UserInfo.getUserId();
            t.Description = 'ServiceAppointment Id: ' + sa.Id + ' Status: ' + sa.Status;
            insert t;
            r.success = true;
            r.message = 'Task created';
            r.taskId = t.Id;
            HCAuditHelper.log(
                'HC_Reminder_Task',
                'Success',
                req.correlationId,
                null,
                'sa=' + sa.Id,
                sa.Id,
                null
            );
        } catch (Exception e) {
            r.message = e.getMessage();
            HCAuditHelper.log(
                'HC_Reminder_Task',
                'Failed',
                req.correlationId,
                e.getMessage(),
                'sa=' + req.serviceAppointmentId,
                req.serviceAppointmentId,
                null
            );
        }
        out.add(r);
        return out;
    }
}
