# Setup UI Checklist: HC_Create_Guest_Person_Account Flow Permissions

## Permission Set to Modify
**Name:** `Hackathon Agent Runtime Access`  
**Location:** Setup → Permission Sets → Hackathon Agent Runtime Access

---

## 1. Enable the Flow

### Navigation: Permission Sets → Hackathon Agent Runtime Access → Assigned Flows

**Action:** Click "Edit" and add:

- [x] **HC_Create_Guest_Person_Account** (set to Enabled)

---

## 2. Update Account Object Permissions

### Navigation: Permission Sets → Hackathon Agent Runtime Access → Object Settings → Account

**Current State:**
- Read: ✓
- Create: ✗
- Edit: ✗

**Required Changes:**

- [x] **Create** - Change from ✗ to **✓**

**Final State:**
- Read: ✓
- Create: ✓ ← **CHANGE THIS**
- Edit: ✗ (leave as-is, not needed)
- Delete: ✗ (leave as-is)
- View All Records: ✓ (already enabled)
- Modify All Records: ✗ (leave as-is)

---

## 3. Account Field-Level Security (FLS)

### Navigation: Permission Sets → Hackathon Agent Runtime Access → Object Settings → Account → Edit

Scroll to **Field Permissions** section and configure:

| Field API Name | Read Access | Edit Access | Notes |
|----------------|-------------|-------------|-------|
| `FirstName` | ✗ | **✓** | **ADD Edit** - Flow writes parsed first name |
| `LastName` | ✗ | **✓** | **ADD Edit** - Flow writes parsed last name |
| `PersonMobilePhone` | **✓** | **✓** | **ADD both** - Flow reads for duplicate check, writes on create |
| `PersonEmail` | ✗ | **✓** | **ADD Edit** - Flow writes email address |
| `IsPersonAccount` | **✓** | ✗ | **ADD Read** - Flow filters Person Accounts |
| `Id` | ✓ | ✗ | Already granted via Read object permission |

**Actions Required:**

- [x] **FirstName** - Enable "Edit Access"
- [x] **LastName** - Enable "Edit Access"
- [x] **PersonMobilePhone** - Enable "Read Access" AND "Edit Access"
- [x] **PersonEmail** - Enable "Edit Access"
- [x] **IsPersonAccount** - Enable "Read Access"

**Note:** Do NOT enable "View All Fields" - grant only the specific fields above.

---

## 4. Contact Object Permissions (Already Correct)

### Navigation: Permission Sets → Hackathon Agent Runtime Access → Object Settings → Contact

**Current State:** ✓ Read-only (correct for Person Account duplicate checks)

**No changes needed** - Contact is read-only, which is appropriate since Person Accounts automatically create related Contact records.

---

## 5. System Permissions (Already Correct)

### Navigation: Permission Sets → Hackathon Agent Runtime Access → System Permissions

**Current State:**
- "View All Users": ✗
- "Modify All Data": ✗
- "View Setup and Configuration": ✗

**No changes needed** - Flow does not require elevated system permissions.

---

## 6. Verify Person Account Record Type Access (If Applicable)

### Navigation: Permission Sets → Hackathon Agent Runtime Access → Object Settings → Account → Record Type Settings

**Action:** Check if your org uses a specific Person Account record type (e.g., "Patient")

**If YES:**

- [x] Locate the Person Account record type in the list
- [x] Set **Record Type** to "Visible" or "Default"
- [x] Set **Page Layout** to appropriate layout (e.g., "Person Account Layout")

**If NO:** Skip this step - the Flow will use the default Person Account configuration.

---

## Summary of Changes

### What We're Adding:
1. ✓ Flow: `HC_Create_Guest_Person_Account` (enabled)
2. ✓ Account Object: **Create** permission
3. ✓ Account FLS: Read access to `PersonMobilePhone`, `IsPersonAccount`
4. ✓ Account FLS: Edit access to `FirstName`, `LastName`, `PersonMobilePhone`, `PersonEmail`

### What We're NOT Adding (Least-Privilege):
- ✗ Account Edit permission (object-level)
- ✗ Account Delete permission
- ✗ Account Modify All Records
- ✗ View All Fields on Account
- ✗ Any elevated system permissions
- ✗ FLS on fields not used by the Flow

---

## Validation Steps

After making the changes above:

1. **Save** the permission set
2. **Assign** the permission set to your Einstein Agent runtime user (if not already assigned)
3. **Test** the Flow:
   ```
   Setup → Flows → HC_Create_Guest_Person_Account → Run
   
   Test Inputs:
   - patient_full_name: "Test Patient"
   - PersonMobilePhone: "5551234567"
   - PersonEmail: "test@example.com"
   
   Expected Output:
   - output_Status: "CREATED_NEW"
   - output_PatientAccountId: Valid 18-char Account Id
   ```

4. **Verify** in Setup → Debug Logs that no permission errors occur

---

## Troubleshooting

### Error: "Insufficient privileges to create Person Account"
**Solution:** Verify Account object has **Create** permission enabled (Step 2)

### Error: "Field FirstName/LastName/PersonEmail not writeable"
**Solution:** Verify Field-Level Security includes **Edit** access (Step 3)

### Error: "Unable to create Person Account - Record Type required"
**Solution:** Check Step 6 - assign Person Account record type visibility

### Error: "PersonMobilePhone field not readable"
**Solution:** Verify PersonMobilePhone has **Read Access** enabled (Step 3)

---

**Last Updated:** 2026-04-29  
**For:** Onco Global Hackathon - Patient Agent  
**Permission Set:** Hackathon_Agent_Runtime_Access