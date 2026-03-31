class AppCollections {
  static const String patients = 'patients';
  static const String advances = 'advances';
  static const String debts = 'debts';
  static const String bookings = 'bookings';
  static const String prescriptions = 'prescriptions';
  static const String appSettings = 'app_settings';
  static const String drivePdfImports = 'drive_pdf_imports';
  static const String doctorPatientLinks = 'doctor_patient_links';
  static const String families = 'families';
  static const String prescriptionIntakes = 'prescription_intakes';
  static const String parserReferenceValues = 'parser_reference_values';
}

class AppImportStatuses {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String parsed = 'parsed';
  static const String error = 'error';
  static const String deleted = 'deleted';
  static const String deletedPdf = 'deleted_pdf';
  static const String deleteRequested = 'delete_requested';
}

class AppPrescriptionStatuses {
  static const String active = 'active';
  static const String deleteRequested = 'delete_requested';
}
