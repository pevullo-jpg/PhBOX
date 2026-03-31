import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/prescription_item.dart';
import 'drive_pdf_imports_repository.dart';
import 'patients_repository.dart';

class PrescriptionsRepository {
  final FirestoreDatasource datasource;
  final PatientsRepository patientsRepository;

  const PrescriptionsRepository({
    required this.datasource,
    required this.patientsRepository,
  });

  Future<void> savePrescription(Prescription prescription) async {
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: prescription.patientFiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      subDocumentId: prescription.id,
      data: prescription.toMap(),
    );

    await refreshPatientAggregates(prescription.patientFiscalCode);
  }

  Future<List<Prescription>> getPatientPrescriptions(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      orderBy: 'prescriptionDate',
      descending: true,
    );

    final List<Prescription> fromSubcollection = maps.map(Prescription.fromMap).where((Prescription item) => !item.isDeleteRequested).toList();

    final DrivePdfImportsRepository importsRepository = DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> imports = await importsRepository.getImportsByPatient(fiscalCode);
    final List<Prescription> fromImports = imports.map(_importToPrescription).toList();

    final Map<String, Prescription> deduped = <String, Prescription>{};
    for (final Prescription item in [...fromSubcollection, ...fromImports]) {
      final String key = item.id.trim().isNotEmpty ? item.id.trim() : '${item.patientFiscalCode}_${item.prescriptionDate.toIso8601String()}';
      deduped[key] = item;
    }
    final List<Prescription> prescriptions = deduped.values.toList();
    prescriptions.sort((Prescription a, Prescription b) => b.prescriptionDate.compareTo(a.prescriptionDate));
    return prescriptions;
  }

  Future<void> refreshPatientAggregates(String fiscalCode) async {
    final Patient? patient = await patientsRepository.getPatientByFiscalCode(fiscalCode);
    if (patient == null) return;

    final List<Prescription> prescriptions = await getPatientPrescriptions(fiscalCode);
    final DrivePdfImportsRepository importsRepository = DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> imports = await importsRepository.getImportsByPatient(fiscalCode);

    final int prescriptionsRecipeCount = prescriptions.fold<int>(0, (int sum, Prescription prescription) => sum + (prescription.prescriptionCount > 0 ? prescription.prescriptionCount : 1));
    final int importsRecipeCount = imports.fold<int>(0, (int sum, DrivePdfImport item) => sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1));
    final int archivedRecipeCount = importsRecipeCount > 0 ? importsRecipeCount : prescriptionsRecipeCount;

    final List<DateTime> observedDates = <DateTime>[
      ...prescriptions.map((Prescription item) => item.prescriptionDate),
      ...imports.map((DrivePdfImport item) => item.prescriptionDate ?? item.createdAt),
    ];
    final DateTime? lastPrescriptionDate = observedDates.isEmpty
        ? null
        : observedDates.reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

    final bool hasDpc = prescriptions.any((Prescription item) => item.dpcFlag) || imports.any((DrivePdfImport item) => item.isDpc);

    final Set<String> therapies = <String>{
      ...patient.therapiesSummary.map((String item) => item.trim()).where((String item) => item.isNotEmpty),
      ...prescriptions.expand((Prescription prescription) => prescription.items).map((PrescriptionItem item) => item.drugName.trim()).where((String item) => item.isNotEmpty),
      ...imports.expand((DrivePdfImport item) => item.therapy).map((String item) => item.trim()).where((String item) => item.isNotEmpty),
    };

    final List<String> exemptions = Patient.normalizeExemptionValues(<dynamic>[
      ...patient.normalizedExemptions,
      ...prescriptions.map((Prescription item) => item.exemptionCode),
      ...imports.map((DrivePdfImport item) => item.exemptionCode),
    ]);

    final String? currentExemption = _resolveCurrentExemption(
      existingCurrent: patient.currentExemption,
      activePrescriptionCurrent: prescriptions.map((Prescription item) => item.exemptionCode?.trim() ?? '').firstWhere((String item) => item.isNotEmpty, orElse: () => ''),
      activeImportCurrent: imports.map((DrivePdfImport item) => item.exemptionCode.trim()).firstWhere((String item) => item.isNotEmpty, orElse: () => ''),
      normalizedExemptions: exemptions,
    );

    final Patient updated = patient.copyWith(
      exemption: currentExemption,
      exemptionCode: currentExemption,
      exemptions: exemptions,
      archivedRecipeCount: archivedRecipeCount,
      lastPrescriptionDate: lastPrescriptionDate,
      hasDpc: hasDpc,
      therapiesSummary: therapies.toList()..sort(),
      updatedAt: DateTime.now(),
    );

    await patientsRepository.savePatient(updated);
  }

  Future<void> requestDeletionForImport(String fiscalCode, String importId) async {
    final DrivePdfImportsRepository importsRepository = DrivePdfImportsRepository(datasource: datasource);
    final DrivePdfImport? importItem = await importsRepository.getImportById(importId);
    if (importItem == null) return;

    await importsRepository.queueImportDeletion(importId);

    final DateTime now = DateTime.now();
    final List<_SubPrescriptionRecord> records = await _getRawPatientPrescriptionRecords(fiscalCode);
    for (final _SubPrescriptionRecord record in records) {
      if (_recordMatchesImport(record, importItem)) {
        await _markPrescriptionDeletionRequested(fiscalCode: fiscalCode, record: record, now: now);
      }
    }

    await refreshPatientAggregates(fiscalCode);
  }

  Future<void> requestDeletionForPrescription(String fiscalCode, String prescriptionId) async {
    final DateTime now = DateTime.now();
    final List<_SubPrescriptionRecord> records = await _getRawPatientPrescriptionRecords(fiscalCode);
    _SubPrescriptionRecord? selectedRecord;
    for (final _SubPrescriptionRecord record in records) {
      if (record.documentId == prescriptionId || record.prescription.id == prescriptionId) {
        selectedRecord = record;
        break;
      }
    }
    if (selectedRecord == null) return;

    await _markPrescriptionDeletionRequested(fiscalCode: fiscalCode, record: selectedRecord, now: now);

    final DrivePdfImportsRepository importsRepository = DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> imports = await importsRepository.getImportsByPatient(fiscalCode, includeInactive: true);
    for (final DrivePdfImport item in imports) {
      if (_importMatchesPrescription(item, selectedRecord.prescription)) {
        await importsRepository.queueImportDeletion(item.id);
      }
    }

    await refreshPatientAggregates(fiscalCode);
  }

  Future<void> requestDeletionForAllPatientPrescriptions(String fiscalCode) async {
    final DrivePdfImportsRepository importsRepository = DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> imports = await importsRepository.getImportsByPatient(fiscalCode);
    for (final DrivePdfImport item in imports) {
      await importsRepository.queueImportDeletion(item.id);
    }

    final DateTime now = DateTime.now();
    final List<_SubPrescriptionRecord> records = await _getRawPatientPrescriptionRecords(fiscalCode);
    for (final _SubPrescriptionRecord record in records.where((item) => !item.prescription.isDeleteRequested)) {
      await _markPrescriptionDeletionRequested(fiscalCode: fiscalCode, record: record, now: now);
    }

    await refreshPatientAggregates(fiscalCode);
  }

  Prescription _importToPrescription(DrivePdfImport item) {
    final DateTime prescriptionDate = item.prescriptionDate ?? item.createdAt;
    return Prescription(
      id: item.id,
      patientFiscalCode: item.patientFiscalCode,
      patientName: item.patientFullName,
      prescriptionDate: prescriptionDate,
      expiryDate: prescriptionDate.add(const Duration(days: 30)),
      doctorName: item.doctorFullName.isEmpty ? null : item.doctorFullName,
      exemptionCode: item.exemptionCode.isEmpty ? null : item.exemptionCode,
      city: item.city.isEmpty ? null : item.city,
      dpcFlag: item.isDpc,
      prescriptionCount: item.prescriptionCount,
      sourceType: item.sourceType,
      status: item.isDeleteRequested ? AppPrescriptionStatuses.deleteRequested : AppPrescriptionStatuses.active,
      deleteRequested: item.isDeleteRequested,
      deletionRequestedAt: item.deletionRequestedAt,
      extractedText: null,
      items: item.therapy
          .where((String value) => value.trim().isNotEmpty)
          .map((String value) => PrescriptionItem(drugName: value.trim()))
          .toList(),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  Future<List<_SubPrescriptionRecord>> _getRawPatientPrescriptionRecords(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      orderBy: 'prescriptionDate',
      descending: true,
    );
    return maps.map((_map) {
      final Map<String, dynamic> recordMap = <String, dynamic>{..._map};
      final String documentId = _readString(recordMap['id']);
      return _SubPrescriptionRecord(
        documentId: documentId,
        raw: recordMap,
        prescription: Prescription.fromMap(recordMap),
      );
    }).where((record) => record.documentId.trim().isNotEmpty || record.prescription.id.trim().isNotEmpty).toList();
  }

  Future<void> _markPrescriptionDeletionRequested({
    required String fiscalCode,
    required _SubPrescriptionRecord record,
    required DateTime now,
  }) async {
    final String subDocumentId = record.documentId.trim().isNotEmpty ? record.documentId : record.prescription.id;
    final Map<String, dynamic> next = <String, dynamic>{...record.raw};
    next['id'] = subDocumentId;
    next['status'] = AppPrescriptionStatuses.deleteRequested;
    next['deleteRequested'] = true;
    next['deletionRequestedAt'] = now.toIso8601String();
    next['updatedAt'] = now.toIso8601String();
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      subDocumentId: subDocumentId,
      data: next,
    );
  }

  bool _recordMatchesImport(_SubPrescriptionRecord record, DrivePdfImport item) {
    final Set<String> candidateIds = <String>{
      record.documentId.trim(),
      record.prescription.id.trim(),
      _readString(record.raw['driveFileId']),
      _readString(record.raw['fileId']),
      _readString(record.raw['sourceImportId']),
    }..removeWhere((String value) => value.isEmpty);

    if (candidateIds.contains(item.id.trim())) return true;
    if (item.driveFileId.trim().isNotEmpty && candidateIds.any((String value) => value.contains(item.driveFileId.trim()))) {
      return true;
    }

    final DateTime? recordDate = record.prescription.prescriptionDate;
    final DateTime? importDate = item.prescriptionDate;
    final bool sameDay = recordDate != null && importDate != null &&
        recordDate.year == importDate.year &&
        recordDate.month == importDate.month &&
        recordDate.day == importDate.day;
    final bool sameDoctor = (record.prescription.doctorName ?? '').trim().toUpperCase() == item.doctorFullName.trim().toUpperCase();
    final bool sameExemption = (record.prescription.exemptionCode ?? '').trim().toUpperCase() == item.exemptionCode.trim().toUpperCase();
    return sameDay && (sameDoctor || sameExemption);
  }

  bool _importMatchesPrescription(DrivePdfImport item, Prescription prescription) {
    final String prescriptionId = prescription.id.trim();
    if (item.id.trim() == prescriptionId) return true;
    if (item.driveFileId.trim().isNotEmpty && prescriptionId.contains(item.driveFileId.trim())) return true;

    final DateTime? importDate = item.prescriptionDate;
    final bool sameDay = importDate != null &&
        importDate.year == prescription.prescriptionDate.year &&
        importDate.month == prescription.prescriptionDate.month &&
        importDate.day == prescription.prescriptionDate.day;
    final bool sameDoctor = item.doctorFullName.trim().toUpperCase() == (prescription.doctorName ?? '').trim().toUpperCase();
    final bool sameExemption = item.exemptionCode.trim().toUpperCase() == (prescription.exemptionCode ?? '').trim().toUpperCase();
    return sameDay && (sameDoctor || sameExemption);
  }

  String? _resolveCurrentExemption({
    required String? existingCurrent,
    required String activePrescriptionCurrent,
    required String activeImportCurrent,
    required List<String> normalizedExemptions,
  }) {
    final List<String> candidates = <String>[
      activePrescriptionCurrent.trim().toUpperCase(),
      activeImportCurrent.trim().toUpperCase(),
      (existingCurrent ?? '').trim().toUpperCase(),
      if (normalizedExemptions.isNotEmpty) normalizedExemptions.first,
    ].where((String item) => item.isNotEmpty).toList();
    return candidates.isEmpty ? null : candidates.first;
  }

  String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}

class _SubPrescriptionRecord {
  final String documentId;
  final Map<String, dynamic> raw;
  final Prescription prescription;

  const _SubPrescriptionRecord({
    required this.documentId,
    required this.raw,
    required this.prescription,
  });
}
