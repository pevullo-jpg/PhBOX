GROUP 26 - BUILD FIX + IMPORT TRACEABILITY

Fix applied:
- added missing required Prescription.sourceType in intake_to_entities_service.dart
- added Prescription.extractedText from intake rawText
- added Prescription.city fallback from intake/patient
- normalized single now/prescriptionDate values during import to avoid inconsistent timestamps
- kept import pipeline compatible with current Firestore collections

Target:
- fix current web build error on missing sourceType
- preserve source provenance for prescriptions imported from drive scans
