GROUP 25 - BUILD FIX

Fix applied:
- removed unsupported Patient.activeTherapies
- removed unsupported PrescriptionItem.note
- removed unsupported Prescription.sourceFileId
- removed unsupported Prescription.sourceFileName
- removed unsupported Prescription.notes
- forced typed map<PrescriptionItem>() to avoid List<dynamic>

Target:
- fix current web build errors in intake_to_entities_service.dart
