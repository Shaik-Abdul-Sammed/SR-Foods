# Google Play Data Safety Form Responses

**App Name:** SR Foods  
**Package:** `com.srfoods.sr_foods`  
**Target:** Google Play Console Data Safety Questionnaire  

---

### 1. Data Collection and Security
- **Does your app collect or share any of the required user data types?**  
  **No.** All user and business data entered into SR Foods is stored **exclusively in a local SQLite database** on the user's device. No user data is transferred to external servers or third-party networks.
- **Is all of the user data collected by your app encrypted in transit?**  
  **Not applicable** (no user data is collected or transmitted to remote servers).
- **Do you provide a way for users to request that their data be deleted?**  
  **Yes.** Users have total control to wipe their data at any time by clearing application storage in Android system settings or utilizing the in-app database reset option.

---

### 2. Specific Data Types Evaluation

| Category | Data Type | Collected? | Shared? | Purpose | Processing |
|---|---|---|---|---|---|
| **Location** | Approximate / Precise | No | No | N/A | None |
| **Personal Info** | Name, Phone, Address | No (Local only) | No | Business Ledger | Stored on-device in `sr_foods.db` |
| **Financial Info** | Payment receipts, dues | No (Local only) | No | Account balance tracking | Stored on-device in `sr_foods.db` |
| **Contacts** | Address book entries | No (Local only) | No | Optional import of shop phone numbers | Processed ephemeral on-device via native picker; not uploaded |
| **Photos & Videos** | Photos | No (Local only) | No | Product photo & invoice receipt capture | Stored locally |
| **App Activity** | Page views, interactions | No | No | N/A | None |
| **Device or other IDs** | Device ID, Advertising ID | No | No | N/A | None |

---

### 3. Declarations for Play Console
- **Data Collection Summary**: Select **"No"** to data collection since all processing occurs locally without remote transmission (as per Google Play policy definitions for on-device processing).
- **Target Audience**: 18 and older (B2B Commercial Food ERP).
