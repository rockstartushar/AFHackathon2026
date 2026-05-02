import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Account.Name';

import resolvePatientByPhone from '@salesforce/apex/HC_SchedulingConsoleController.resolvePatientByPhone';
import createGuestPersonAccount from '@salesforce/apex/HC_SchedulingConsoleController.createGuestPersonAccount';
import logAgentAction from '@salesforce/apex/HC_SchedulingConsoleController.logAgentAction';
import getFacilities from '@salesforce/apex/HC_SchedulingConsoleController.getFacilities';
import findSpecialists from '@salesforce/apex/HC_SchedulingConsoleController.findSpecialists';
import routeSymptomToSpecialty from '@salesforce/apex/HC_SchedulingConsoleController.routeSymptomToSpecialty';
import getSuggestedSlots from '@salesforce/apex/HC_SchedulingConsoleController.getSuggestedSlots';
import runBookingAction from '@salesforce/apex/HC_SchedulingConsoleController.runBookingAction';
import runPatientDataAction from '@salesforce/apex/HC_SchedulingConsoleController.runPatientDataAction';
import createVisitReminderTask from '@salesforce/apex/HC_SchedulingConsoleController.createVisitReminderTask';
import listPatientVisitsForConsole from '@salesforce/apex/HC_SchedulingConsoleController.listPatientVisitsForConsole';

function newCorrelationId() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
    }
    return 'hc-' + Date.now() + '-' + Math.random().toString(36).slice(2, 10);
}

export default class HcSchedulingConsole extends LightningElement {
    correlationId = newCorrelationId();

    /** When set, HC_* flows call HC_MessagingSessionContactLink to set MessagingSession.EndUserContactId. */
    messagingSessionIdForLink = '';

    resolvePhone = '';
    @track patientResolveSummary = '';

    guestName = '';
    guestMobile = '';
    guestEmail = '';
    @track guestCreateSummary = '';

    patientAccountId = '';
    _patientRecord;

    facilityKeyword = '';
    @track facilityRows = [];
    facilityColumns = [{ label: 'Site name', fieldName: 'facilityName', type: 'text', wrapText: true }];

    directoryCity = '';
    directorySpecialty = '';
    directoryTopN = 10;
    @track directoryRows = [];
    directoryColumns = [
        { label: 'Clinician', fieldName: 'providerName', type: 'text', wrapText: true },
        { label: 'Site', fieldName: 'facilityName', type: 'text', wrapText: true }
    ];

    symptomText = '';
    symptomCity = '';
    @track symptomSummary = '';

    healthcareFacilityId = '';
    healthcareProviderId = '';
    slotTargetDate = '';
    slotDurationMinutes = 30;
    slotMaxSlots = 10;
    @track slotsEmptyMessage = '';
    @track slotRows = [];
    activeSlotKey = '';
    @track selectedSlotStartDisplay = '';
    @track selectedSlotEndDisplay = '';

    bookingOperation = 'BOOK';
    bookingOperationOptions = [
        { label: 'Book new visit', value: 'BOOK' },
        { label: 'Reschedule visit', value: 'MODIFY' },
        { label: 'Cancel visit', value: 'CANCEL' }
    ];
    serviceAppointmentId = '';
    bookingStart = '';
    bookingEnd = '';
    bookingWorkTypeId = '';
    /** When false, work type is omitted from the form (optional in HC_BookingActionsInvocable for BOOK). */
    includeWorkTypeInBooking = false;
    bookingSubject = '';
    bookingCancelReason = '';
    @track bookingSummary = '';

    @track modifyCancelVisitRows = [];
    modifyCancelVisitLoading = false;
    modifyCancelVisitLoaded = false;

    modifyCancelVisitColumns = [
        { label: 'Start', fieldName: 'startDisplay', type: 'text', wrapText: true },
        { label: 'End', fieldName: 'endDisplay', type: 'text', wrapText: true },
        { label: 'Site', fieldName: 'facilityName', type: 'text', wrapText: true },
        { label: 'Clinician', fieldName: 'clinicianName', type: 'text', wrapText: true },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Subject', fieldName: 'subject', type: 'text', wrapText: true }
    ];

    patientDataOperation = 'INSURANCE';
    patientDataOptions = [
        { label: 'Insurance on file', value: 'INSURANCE' },
        { label: 'Visit checklist (prerequisites)', value: 'PREREQUISITES' },
        { label: 'Room rates at a site', value: 'ROOM_RATES' },
        { label: 'Specialty catalog', value: 'SPECIALTIES' },
        { label: 'Return visit context', value: 'BOOKING_SESSION' }
    ];
    roomTypeOptions = [
        { label: '—', value: '' },
        { label: 'General', value: 'General' },
        { label: 'ICU', value: 'ICU' },
        { label: 'Private', value: 'Private' },
        { label: 'Semi-private', value: 'Semi_Private' }
    ];
    pdRoomType = '';
    @track patientDataSummary = '';

    logActionName = 'Scheduling console';
    logStatus = 'OK';
    logError = '';
    logInputSummary = '';

    @track reminderSummary = '';

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasSlotChoices() {
        return Array.isArray(this.slotRows) && this.slotRows.length > 0;
    }

    get showEditableVisitTimes() {
        if (this.bookingOperation !== 'BOOK') {
            return true;
        }
        return !this.hasSlotChoices;
    }

    get showBookTimesFromSlotPicker() {
        return this.bookingOperation === 'BOOK' && this.hasSlotChoices;
    }

    get showWorkTypeOptionalSection() {
        return this.bookingOperation === 'BOOK';
    }

    get showModifyCancelVisitSection() {
        return this.bookingOperation === 'MODIFY' || this.bookingOperation === 'CANCEL';
    }

    get modifyCancelVisitEmptyHint() {
        if (this.modifyCancelVisitLoading || !this.showModifyCancelVisitSection) {
            return '';
        }
        if (!this.patientAccountId) {
            return 'Select a patient first (Patient tab), then refresh this list.';
        }
        if (this.modifyCancelVisitLoaded && (!this.modifyCancelVisitRows || this.modifyCancelVisitRows.length === 0)) {
            return 'No visits match this patient with the current site or clinician filters. Try clearing the clinician, choosing another site, or refreshing after changing Availability.';
        }
        return '';
    }

    get patientRecordIdForWire() {
        const id = this.patientAccountId;
        return id && String(id).length >= 15 ? id : undefined;
    }

    @wire(getRecord, { recordId: '$patientRecordIdForWire', fields: [NAME_FIELD] })
    wiredPatientRecord({ data, error }) {
        if (data) {
            this._patientRecord = data;
        } else {
            this._patientRecord = undefined;
        }
    }

    get schedulePatientSummary() {
        if (!this.patientAccountId) {
            return 'No patient selected yet. Use the Patient tab to find someone by phone, create a guest profile, or pick an account.';
        }
        if (this._patientRecord) {
            const name = getFieldValue(this._patientRecord, NAME_FIELD);
            if (name) {
                return name;
            }
        }
        return `Patient record: ${this.patientAccountId}`;
    }

    /** lightning-record-picker filters (GraphQL criteria). Narrow results to scheduling-relevant rows. */
    get patientAccountFilter() {
        return {
            criteria: [{ fieldPath: 'IsPersonAccount', operator: 'eq', value: true }]
        };
    }

    get healthcareProviderFilter() {
        return {
            criteria: [{ fieldPath: 'IsActive', operator: 'eq', value: true }]
        };
    }

    get workTypeFilter() {
        return {
            criteria: [{ fieldPath: 'IsActive', operator: 'eq', value: true }]
        };
    }

    get serviceAppointmentFilter() {
        const criteria = [
            {
                fieldPath: 'Status',
                operator: 'nin',
                value: ['Canceled', 'Cancelled']
            }
        ];
        const pid = this.patientAccountId;
        if (pid && String(pid).length >= 15) {
            criteria.push({
                fieldPath: 'ParentRecordId',
                operator: 'eq',
                value: pid
            });
        }
        return { criteria };
    }

    get slotTabsForUi() {
        const rows = this.slotRows || [];
        return rows.map((row, idx) => {
            const selected = row.slotKey === this.activeSlotKey;
            return {
                slotKey: row.slotKey,
                tabLabel: this.shortSlotTabLabel(row.label, idx),
                className: 'slot-tab' + (selected ? ' slot-tab_active' : ''),
                ariaSelected: selected ? 'true' : 'false'
            };
        });
    }

    shortSlotTabLabel(label, idx) {
        const base = (label && String(label).trim()) || `Time ${idx + 1}`;
        return base.length > 32 ? base.slice(0, 29) + '…' : base;
    }

    formatSlotDisplay(iso) {
        if (!iso) {
            return '';
        }
        try {
            const d = new Date(iso);
            if (Number.isNaN(d.getTime())) {
                return iso;
            }
            return d.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
        } catch (e) {
            return iso;
        }
    }

    applySlotSelection(row) {
        if (!row) {
            return;
        }
        this.bookingStart = row.start || '';
        this.bookingEnd = row.end || '';
        this.selectedSlotStartDisplay = this.formatSlotDisplay(row.start);
        this.selectedSlotEndDisplay = this.formatSlotDisplay(row.end);
    }

    async handlePatientPickerChange(event) {
        this.patientAccountId = event.detail.recordId || '';
        await this.refreshModifyCancelVisitsIfNeeded();
    }

    async handleFacilityPickerChange(event) {
        this.healthcareFacilityId = event.detail.recordId || '';
        await this.refreshModifyCancelVisitsIfNeeded();
    }

    async handleProviderPickerChange(event) {
        this.healthcareProviderId = event.detail.recordId || '';
        await this.refreshModifyCancelVisitsIfNeeded();
    }

    handleServiceAppointmentPickerChange(event) {
        this.serviceAppointmentId = event.detail.recordId || '';
    }

    handleWorkTypePickerChange(event) {
        this.bookingWorkTypeId = event.detail.recordId || '';
    }

    handleIncludeWorkTypeChange(event) {
        this.includeWorkTypeInBooking = event.target.checked;
        if (!this.includeWorkTypeInBooking) {
            this.bookingWorkTypeId = '';
        }
    }

    handleResolvePhone(e) {
        this.resolvePhone = e.target.value;
    }
    handleMessagingSessionIdForLink(e) {
        this.messagingSessionIdForLink = e.target.value || '';
    }

    async handleResolvePatient() {
        this.patientResolveSummary = '';
        try {
            const r = await resolvePatientByPhone({
                phone: this.resolvePhone,
                messagingSessionId: this.messagingSessionIdForLink || null
            });
            const status = r.output_Status || '';
            const pid = r.output_PatientAccountId || '';
            if (pid) {
                this.patientAccountId = pid;
                this.patientResolveSummary = `${status}: patient found and selected below.`;
                await this.refreshModifyCancelVisitsIfNeeded();
            } else {
                this.patientResolveSummary = `${status}: no patient matched this number.`;
            }
            this.toast('Find patient', status, pid ? 'success' : 'info');
        } catch (err) {
            this.toast('Find patient', this.reduceError(err), 'error');
        }
    }

    handleGuestName(e) {
        this.guestName = e.target.value;
    }
    handleGuestMobile(e) {
        this.guestMobile = e.target.value;
    }
    handleGuestEmail(e) {
        this.guestEmail = e.target.value;
    }

    async handleCreateGuest() {
        this.guestCreateSummary = '';
        try {
            const r = await createGuestPersonAccount({
                patientFullName: this.guestName,
                personMobilePhone: this.guestMobile,
                personEmail: this.guestEmail,
                messagingSessionId: this.messagingSessionIdForLink || null
            });
            const status = r.output_Status || '';
            const pid = r.output_PatientAccountId || '';
            const err = r.output_ErrorMessage || '';
            if (pid) {
                this.patientAccountId = pid;
                await this.refreshModifyCancelVisitsIfNeeded();
            }
            this.guestCreateSummary = err
                ? `${status}\n${err}`
                : pid
                  ? `${status}: guest profile created and selected below.`
                  : `${status}: could not create a profile.`;
            this.toast('Guest profile', status, status === 'Created' || status === 'Matched' ? 'success' : 'warning');
        } catch (err) {
            this.toast('Guest profile', this.reduceError(err), 'error');
        }
    }

    handleFacilityKeyword(e) {
        this.facilityKeyword = e.target.value;
    }

    async handleLoadFacilities() {
        try {
            const r = await getFacilities({ cityKeyword: this.facilityKeyword });
            const rows = (r.rows || []).map((row) => ({
                facilityId: row.facilityId,
                facilityName: row.facilityName,
                line: row.line
            }));
            this.facilityRows = rows;
            this.toast('Sites', `${rows.length} found`, r.success === false ? 'warning' : 'success');
        } catch (err) {
            this.toast('Sites', this.reduceError(err), 'error');
        }
    }

    handleFacilityRowSelect(e) {
        const [row] = e.detail.selectedRows;
        if (row && row.facilityId) {
            this.healthcareFacilityId = row.facilityId;
        }
    }

    handleDirectoryCity(e) {
        this.directoryCity = e.target.value;
    }
    handleDirectorySpecialty(e) {
        this.directorySpecialty = e.target.value;
    }
    handleDirectoryTopN(e) {
        this.directoryTopN = parseInt(e.target.value, 10) || 10;
    }

    async handleFindSpecialists() {
        try {
            const r = await findSpecialists({
                cityKeyword: this.directoryCity,
                specialtyName: this.directorySpecialty,
                topN: this.directoryTopN
            });
            const raw = r.rows || [];
            this.directoryRows = raw.map((row, i) => ({
                rowKey: (row.providerId || '') + '-' + (row.facilityId || '') + '-' + i,
                providerId: row.providerId,
                facilityId: row.facilityId,
                providerName: row.providerName,
                facilityName: row.facilityName,
                line: row.line
            }));
            this.toast('Directory', `${this.directoryRows.length} matches`, 'success');
        } catch (err) {
            this.toast('Directory', this.reduceError(err), 'error');
        }
    }

    handleDirectoryRowSelect(e) {
        const [row] = e.detail.selectedRows;
        if (row) {
            if (row.facilityId) {
                this.healthcareFacilityId = row.facilityId;
            }
            if (row.providerId) {
                this.healthcareProviderId = row.providerId;
            }
        }
    }

    handleSymptomText(e) {
        this.symptomText = e.target.value;
    }
    handleSymptomCity(e) {
        this.symptomCity = e.target.value;
    }

    async handleRouteSymptom() {
        this.symptomSummary = '';
        try {
            const o = await routeSymptomToSpecialty({
                symptomText: this.symptomText,
                cityKeyword: this.symptomCity
            });
            this.symptomSummary = [
                o.recommendedSpecialty ? `Suggested specialty: ${o.recommendedSpecialty}` : '',
                o.matchFound != null ? `Rule match: ${o.matchFound}` : '',
                o.cityKeyword ? `Region: ${o.cityKeyword}` : '',
                o.routingSummary || '',
                o.disclaimer || ''
            ]
                .filter(Boolean)
                .join('\n');
            this.toast('Symptom routing', 'Suggestion ready', 'success');
        } catch (err) {
            this.toast('Symptom routing', this.reduceError(err), 'error');
        }
    }

    handleSlotTargetDate(e) {
        this.slotTargetDate = e.target.value;
    }
    handleSlotDurationMinutes(e) {
        this.slotDurationMinutes = parseInt(e.target.value, 10) || 30;
    }
    handleSlotMaxSlots(e) {
        this.slotMaxSlots = parseInt(e.target.value, 10) || 10;
    }

    async handleGetSlots() {
        this.slotsEmptyMessage = '';
        this.slotRows = [];
        this.activeSlotKey = '';
        this.selectedSlotStartDisplay = '';
        this.selectedSlotEndDisplay = '';
        try {
            const r = await getSuggestedSlots({
                healthcareFacilityId: this.healthcareFacilityId,
                healthcareProviderId: this.healthcareProviderId,
                targetDateIso: this.slotTargetDate,
                slotDurationMinutes: this.slotDurationMinutes,
                maxSlots: this.slotMaxSlots,
                correlationId: this.correlationId
            });
            let slots = [];
            if (r.slotsJson) {
                try {
                    const parsed = JSON.parse(r.slotsJson);
                    slots = parsed.slots || [];
                } catch (ignore) {
                    /* leave empty */
                }
            }
            this.slotRows = slots.map((s, i) => ({
                slotKey: `slot-${i}-${s.start}`,
                label: s.label,
                start: s.start,
                end: s.end
            }));
            if (this.slotRows.length === 0) {
                this.slotsEmptyMessage = r.summaryText || r.message || 'No open times for this day.';
                this.bookingStart = '';
                this.bookingEnd = '';
            } else {
                this.activeSlotKey = this.slotRows[0].slotKey;
                this.applySlotSelection(this.slotRows[0]);
            }
            this.toast('Availability', `${this.slotRows.length} open time(s)`, 'success');
        } catch (err) {
            this.toast('Availability', this.reduceError(err), 'error');
        }
    }

    handleSlotTabClick(evt) {
        const key = evt.currentTarget.dataset.slotKey;
        const row = (this.slotRows || []).find((r) => r.slotKey === key);
        if (row) {
            this.activeSlotKey = key;
            this.applySlotSelection(row);
        }
    }

    async refreshModifyCancelVisitsIfNeeded() {
        if (!this.showModifyCancelVisitSection) {
            return;
        }
        await this.loadModifyCancelVisits();
    }

    async loadModifyCancelVisits() {
        this.modifyCancelVisitLoading = true;
        try {
            const r = await listPatientVisitsForConsole({
                patientAccountId: this.patientAccountId,
                healthcareFacilityId: this.healthcareFacilityId,
                healthcareProviderId: this.healthcareProviderId
            });
            if (r.success === false && r.message) {
                this.modifyCancelVisitRows = [];
                this.toast('Visit list', r.message, 'warning');
            } else {
                this.modifyCancelVisitRows = this.mapVisitRowsForTable(r.rows);
            }
            this.modifyCancelVisitLoaded = true;
        } catch (err) {
            this.modifyCancelVisitRows = [];
            this.toast('Visit list', this.reduceError(err), 'error');
            this.modifyCancelVisitLoaded = true;
        } finally {
            this.modifyCancelVisitLoading = false;
        }
    }

    mapVisitRowsForTable(rows) {
        return (rows || []).map((row) => ({
            serviceAppointmentId: row.serviceAppointmentId,
            schedStartIso: row.schedStartIso,
            schedEndIso: row.schedEndIso,
            startDisplay: this.formatSlotDisplay(row.schedStartIso),
            endDisplay: this.formatSlotDisplay(row.schedEndIso),
            facilityName: row.facilityName || '—',
            clinicianName: row.clinicianName || '—',
            status: row.status || '',
            subject: row.subject || ''
        }));
    }

    handleModifyCancelVisitRowSelect(e) {
        const [row] = e.detail.selectedRows;
        if (!row) {
            return;
        }
        this.serviceAppointmentId = row.serviceAppointmentId;
        this.bookingStart = row.schedStartIso || '';
        this.bookingEnd = row.schedEndIso || '';
    }

    async handleRefreshModifyCancelVisits() {
        await this.loadModifyCancelVisits();
    }

    async handleBookingOperation(e) {
        this.bookingOperation = e.detail.value;
        this.includeWorkTypeInBooking = false;
        this.bookingWorkTypeId = '';
        if (this.bookingOperation === 'BOOK') {
            this.modifyCancelVisitRows = [];
            this.modifyCancelVisitLoaded = false;
        }
        if (this.bookingOperation === 'BOOK' && this.slotRows.length > 0) {
            const still = this.slotRows.find((r) => r.slotKey === this.activeSlotKey);
            if (still) {
                this.applySlotSelection(still);
            } else {
                this.activeSlotKey = this.slotRows[0].slotKey;
                this.applySlotSelection(this.slotRows[0]);
            }
        }
        if (this.showModifyCancelVisitSection) {
            await this.loadModifyCancelVisits();
        }
    }
    handleBookingStart(e) {
        this.bookingStart = e.target.value;
    }
    handleBookingEnd(e) {
        this.bookingEnd = e.target.value;
    }
    handleBookingSubject(e) {
        this.bookingSubject = e.target.value;
    }
    handleBookingCancelReason(e) {
        this.bookingCancelReason = e.target.value;
    }

    async handleRunBooking() {
        this.bookingSummary = '';
        try {
            const r = await runBookingAction({
                operation: this.bookingOperation,
                patientAccountId: this.patientAccountId,
                healthcareFacilityId: this.healthcareFacilityId,
                schedStartIso: this.bookingStart,
                schedEndIso: this.bookingEnd,
                healthcareProviderId: this.healthcareProviderId,
                parentRecordId: '',
                workTypeId: this.includeWorkTypeInBooking ? this.bookingWorkTypeId : '',
                correlationId: this.correlationId,
                subject: this.bookingSubject,
                serviceAppointmentId: this.serviceAppointmentId,
                cancellationReason: this.bookingCancelReason
            });
            this.bookingSummary = [
                r.success ? 'Completed successfully.' : 'Something went wrong.',
                r.message || '',
                r.serviceAppointmentId ? `Visit ID: ${r.serviceAppointmentId}` : '',
                r.clinicalEncounterId ? `Encounter ID: ${r.clinicalEncounterId}` : ''
            ]
                .filter(Boolean)
                .join('\n');
            if (r.serviceAppointmentId) {
                this.serviceAppointmentId = r.serviceAppointmentId;
            }
            this.toast('Visit', r.message || 'Done', r.success ? 'success' : 'error');
            if (r.success && this.bookingOperation === 'BOOK' && this.healthcareFacilityId && this.slotTargetDate) {
                await this.handleGetSlots();
            }
            if (r.success && this.showModifyCancelVisitSection) {
                await this.loadModifyCancelVisits();
            }
        } catch (err) {
            this.toast('Visit', this.reduceError(err), 'error');
        }
    }

    handlePatientDataOperation(e) {
        this.patientDataOperation = e.detail.value;
    }
    handlePdRoomType(e) {
        this.pdRoomType = e.detail.value;
    }

    async handlePatientData() {
        this.patientDataSummary = '';
        try {
            const r = await runPatientDataAction({
                operation: this.patientDataOperation,
                patientAccountId: this.patientAccountId,
                serviceAppointmentId: this.serviceAppointmentId,
                healthcareFacilityId: this.healthcareFacilityId,
                roomTypeApi: this.pdRoomType,
                correlationId: this.correlationId
            });
            this.patientDataSummary = [r.summaryText, r.message].filter(Boolean).join('\n');
            this.toast('Patient context', r.message || 'Done', r.success ? 'success' : 'warning');
        } catch (err) {
            this.toast('Patient context', this.reduceError(err), 'error');
        }
    }

    handleLogActionName(e) {
        this.logActionName = e.target.value;
    }
    handleLogStatus(e) {
        this.logStatus = e.target.value;
    }
    handleLogError(e) {
        this.logError = e.target.value;
    }
    handleLogInputSummary(e) {
        this.logInputSummary = e.target.value;
    }

    async handleLogAgentAction() {
        try {
            await logAgentAction({
                inputActionName: this.logActionName,
                inputStatus: this.logStatus,
                inputCorrelationId: this.correlationId,
                inputErrorMessage: this.logError,
                inputInputSummary: this.logInputSummary
            });
            this.toast('Activity log', 'Entry saved', 'success');
        } catch (err) {
            this.toast('Activity log', this.reduceError(err), 'error');
        }
    }

    async handleCreateReminder() {
        this.reminderSummary = '';
        try {
            const r = await createVisitReminderTask({
                serviceAppointmentId: this.serviceAppointmentId,
                correlationId: this.correlationId
            });
            this.reminderSummary = [r.success ? 'Reminder created.' : 'Could not create reminder.', r.message, r.taskId ? `Task ID: ${r.taskId}` : '']
                .filter(Boolean)
                .join('\n');
            this.toast('Reminder', r.message || 'Done', r.success ? 'success' : 'error');
        } catch (err) {
            this.toast('Reminder', this.reduceError(err), 'error');
        }
    }

    reduceError(err) {
        if (!err) {
            return 'Unknown error';
        }
        if (Array.isArray(err.body)) {
            return err.body.map((e) => e.message).join('; ');
        }
        if (err.body && err.body.message) {
            return err.body.message;
        }
        return err.message || String(err);
    }
}
