# HC_Create_Guest_Person_Account - Required CRUD Permissions

## Flow Overview
**API Name:** `HC_Create_Guest_Person_Account`  
**Type:** Autolaunched Flow  
**Purpose:** Creates or retrieves Person Account for guest patient scheduling with phone normalization and duplicate prevention.

## Flow Logic
1. **Normalize Phone Input** - Removes spaces, hyphens, parentheses from phone number
2. **Check for Existing Account** - Queries Person Account by normalized PersonMobilePhone
3. **Return Existing or Create New** - Returns found account or creates new Person Account
4. **Error Handling** - Captures creation failures with safe error messages (no PHI)

## Inputs
- `patient_full_name` (String) - Full name to parse into FirstName/LastName
- `PersonMobilePhone` (String) - Phone number to normalize and match
- `PersonEmail` (String) - Email address for the account

## Outputs
- `output_PatientAccountId` (String) - 18-character Account Id
- `output_Status` (String) - `CREATED_NEW`, `MATCHED_EXISTING`, or `FAILED`
- `output_ErrorMessage` (String) - Safe error message without PHI

---

## Required Object-Level Security (OLS)

### Account Object
**For Einstein Agent Runtime User:**
- **Read Access:** REQUIRED - To query existing Person Accounts by phone
- **Create Access:** REQUIRED - To insert new Person Accounts when no match found

---

## Required Field-Level Security (FLS)

### Account Fields (Person Account)

| Field API Name | Read | Create | Notes |
|----------------|------|--------|-------|
| `Id` | ✓ | — | Query existing accounts, return Account Id |
| `IsPersonAccount` | ✓ | — | Filter criteria (system-managed on create) |
| `FirstName` | — | ✓ | Parsed from patient_full_name input |
| `LastName` | — | ✓ | Parsed from patient_full_name input |
| `PersonMobilePhone` | ✓ | ✓ | Lookup key (normalized) + stored on new account |
| `PersonEmail` | — | ✓ | Email address for new account |

**Note:** `IsPersonAccount` is typically read-only and set by Salesforce automatically when creating Person Accounts via the appropriate record type or API settings.

---

## Permission Set Assignment

### Hackathon_Agent_Runtime_Access
Add this Flow to the existing Einstein Agent runtime permission set:

**Enabled Flows:**
- `HC_Create_Guest_Person_Account` ✓

**Object Permissions (Account):**
- Read: ✓
- Create: ✓
- Edit: ✓ (if modifying existing accounts in future)
- Delete: ✗ (not required)
- View All: ✗ (not required)
- Modify All: ✗ (not required)

**Field Permissions (Account - Person Account fields):**
- Read: `Id`, `IsPersonAccount`, `PersonMobilePhone`
- Edit: `FirstName`, `LastName`, `PersonMobilePhone`, `PersonEmail`

---

## Record Type Considerations

### Person Account Record Type
If your org uses a specific Person Account record type (e.g., "Patient"), you may need to:

1. **Add RecordTypeId to the Flow** - Update `Create_New_Person_Account` element to include:
   ```xml
   <inputAssignments>
       <field>RecordTypeId</field>
       <value>
           <stringValue>012XXXXXXXXXXXXXXX</stringValue>
       </value>
   </inputAssignments>
   ```
   
2. **Grant Record Type Assignment Permission** - In the permission set:
   - Navigate to Object Settings > Account
   - Under "Record Types", enable the Patient Person Account record type
   - Set as Default (optional)

3. **Query for RecordTypeId Dynamically** - Alternative approach using formula:
   ```
   $RecordType.Account.Patient.Id
   ```

**Current Implementation:** The Flow does not explicitly set a RecordTypeId. It relies on:
- Default Person Account record type assignment
- OR org-wide Person Account settings
- OR Account.IsPersonAccount flag handling by Salesforce

---

## Testing & Validation

### Test Scenarios

1. **New Patient (No Match)**
   - Input: New phone number not in system
   - Expected: `CREATED_NEW`, valid Account Id

2. **Existing Patient (Exact Match)**
   - Input: Phone matching existing Person Account
   - Expected: `MATCHED_EXISTING`, existing Account Id

3. **Phone Normalization**
   - Input: `(555) 123-4567` or `555-123-4567` or `555 123 4567`
   - Expected: All normalize to `5551234567` for matching

4. **Name Parsing**
   - Input: `John Doe` → FirstName: `John`, LastName: `Doe`
   - Input: `Maria Garcia Lopez` → FirstName: `Maria`, LastName: `Garcia Lopez` (last space)
   - Input: `Prince` → FirstName: `Prince`, LastName: `Prince` (no space)

5. **Error Handling**
   - Scenario: Required field validation fails
   - Expected: `FAILED` status with safe error message

---

## Integration with Agentforce

### Registering as Agentforce Action

1. **Deploy the Flow** to your org
2. **In Agent Builder**, add a new action:
   - Type: Flow
   - Flow: `HC Create Guest Person Account`
   - Label: "Create or Find Patient Account"
   
3. **Action Instructions** (paste in Agent Builder):
   ```
   Use this action to create a new guest patient account or find an existing one by phone number.
   
   When to call:
   - When a guest patient provides their name, phone, and email for the first time
   - Before booking an appointment for a patient not yet verified
   - When the patient says "I'm new" or "create my account"
   
   Input requirements:
   - patient_full_name: Full name as provided by patient (e.g., "John Doe")
   - PersonMobilePhone: Phone number in any format (will be normalized)
   - PersonEmail: Valid email address
   
   Response handling:
   - If output_Status = "MATCHED_EXISTING": Existing patient found, use output_PatientAccountId
   - If output_Status = "CREATED_NEW": New patient created, use output_PatientAccountId
   - If output_Status = "FAILED": Show error to patient, do not proceed with booking
   
   Always check output_Status before proceeding with appointment booking actions.
   ```

4. **Attach to Topics:**
   - Patient Verification
   - New Patient Registration
   - Guest Booking Flow

---

## Least-Privilege Principle

This Flow follows least-privilege by:
- ✓ Only reads fields necessary for duplicate checking
- ✓ Only writes fields explicitly provided by user
- ✓ Does not query/update unrelated objects
- ✓ Does not expose PHI in error messages
- ✓ No View All / Modify All permissions required
- ✓ No Delete permission required

---

## Related Documentation
- `docs/HC-Automations.md` - Overview of all HC automation components
- `docs/Patient-Agent-Conversation-Scripts.md` §4a - Patient verification flows
- `docs/BOOKING_PATTERN.md` - Data model for patient scheduling
- `docs/Org-Build-Checklist.md` - Deployment checklist

---

**Last Updated:** 2026-04-29  
**Author:** Onco Global Hackathon Team  
**Review Status:** ✓ Security reviewed for least-privilege + PHI safety