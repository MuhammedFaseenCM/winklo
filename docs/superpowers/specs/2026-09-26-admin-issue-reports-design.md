# Admin issue reports — design (pointer)

Date: 2026-09-26  
Status: approved  

Canonical design lives in the admin repo:

https://github.com/MuhammedFaseenCM/winklo-admin/blob/main/docs/2026-09-26-admin-issue-reports-design.md

**Player repo changes for this feature:** none required for Flutter. Firestore rules stay create-only for `issue_reports` (no client admin reads). Worker uses Admin SDK.
