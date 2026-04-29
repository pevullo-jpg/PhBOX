Micro-PR 2 — Dead files & placeholder cleanup
Date: 2026-04-29

Removed files (all were 1-line placeholders: "// TODO: implement"):
- lib/features/auth/pages/login_page.dart
- lib/features/prescriptions/pages/import_prescription_page.dart
- lib/features/prescriptions/widgets/prescription_upload_zone.dart
- lib/features/patients/widgets/add_advance_dialog.dart
- lib/shared/widgets/app_text_field.dart
- lib/core/services/drive_service.dart
- lib/core/services/ocr_service.dart
- lib/core/services/pdf_service.dart
- lib/core/utils/date_utils.dart

Verification performed before removal:
1) pure placeholder/TODO content only
2) no imports/references in lib/
3) no references from app.dart/main runtime pages (dashboard/families/settings)

Runtime behavior: unchanged (no active code path touched).
Firestore reads/hour impact: delta 0.
