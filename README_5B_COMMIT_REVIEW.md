# PhBOX 0.2 — Micro-PR 5B — full-file replacement

## Branch target
`codex/create-final-pr-for-pdf-delete-mask`

## Replace these complete files
- `lib/core/utils/pending_pdf_delete_storage_web.dart`
- `lib/features/dashboard/pages/dashboard_page.dart`
- `lib/features/patients/pages/patient_detail_page.dart`

The ZIP also includes:
- `lib/core/utils/pending_pdf_delete_storage.dart`
- `lib/core/utils/pending_pdf_delete_storage_stub.dart`

Those two are included for completeness but should already exist in PR #22.

## Commit message
`fix: enforce pending pdf delete mask before backend convergence`

## Review prompt
```text
@codex review the latest PR HEAD only.

Before reviewing, confirm:
1. Current reviewed HEAD SHA.
2. Files changed.
3. No files outside scope were modified.

Focus:
- pending-delete mask hides imports independently from deletePdfRequested;
- Dashboard global flag search;
- PatientDetail load path;
- localStorage guarded;
- Firestore reads/writes delta = 0.
```

## Expected Firestore delta
- Reads/hour: 0
- Writes/hour: 0
- New queries: 0
- New listeners: 0
- Backend/GAS changes: 0
