import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/doctor_patient_link.dart';

class DoctorPatientLinksRepository {
  final FirestoreDatasource datasource;

  const DoctorPatientLinksRepository({required this.datasource});

  Future<List<DoctorPatientLink>> getAllLinks() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.doctorPatientLinks,
    );
    final List<DoctorPatientLink> links = maps
        .map(DoctorPatientLink.fromMap)
        .where((DoctorPatientLink item) {
      return item.patientFiscalCode.isNotEmpty &&
          item.doctorFullName.trim().isNotEmpty;
    }).toList();
    links.sort((DoctorPatientLink a, DoctorPatientLink b) {
      final int typeOrder = _typeRank(a.linkType).compareTo(_typeRank(b.linkType));
      if (typeOrder != 0) {
        return typeOrder;
      }
      final DateTime aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return links;
  }

  Future<List<DoctorPatientLink>> getLinksForPatient(String fiscalCode) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const <DoctorPatientLink>[];
    }
    final List<Map<String, dynamic>> maps = await datasource.getCollectionWhereEqual(
      collectionPath: AppCollections.doctorPatientLinks,
      field: 'patientFiscalCode',
      value: normalized,
    );
    final List<DoctorPatientLink> links = maps
        .map(DoctorPatientLink.fromMap)
        .where((DoctorPatientLink item) {
      return item.patientFiscalCode == normalized &&
          item.doctorFullName.trim().isNotEmpty;
    }).toList();
    links.sort((DoctorPatientLink a, DoctorPatientLink b) {
      final int typeOrder = _typeRank(a.linkType).compareTo(_typeRank(b.linkType));
      if (typeOrder != 0) {
        return typeOrder;
      }
      final DateTime aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return links;
  }

  Future<void> saveManualOverride({
    required String patientFiscalCode,
    required String patientFullName,
    required String doctorFullName,
    String? city,
  }) {
    final String normalizedCf = patientFiscalCode.trim().toUpperCase();
    final String normalizedDoctor = doctorFullName.trim();
    final List<String> parts = normalizedDoctor
        .split(RegExp(r'\s+'))
        .where((String e) => e.isNotEmpty)
        .toList();
    final String doctorSurname = parts.isEmpty ? normalizedDoctor : parts.first;
    final String doctorGivenName =
        parts.length > 1 ? parts.sublist(1).join(' ') : doctorSurname;
    final DateTime now = DateTime.now();
    final String documentId = '${normalizedCf}__manual';
    return datasource.setDocument(
      collectionPath: AppCollections.doctorPatientLinks,
      documentId: documentId,
      data: <String, dynamic>{
        'id': documentId,
        'patientFiscalCode': normalizedCf,
        'patientFullName': patientFullName.trim(),
        'doctorFullName': normalizedDoctor,
        'doctorSurname': doctorSurname,
        'doctorName': doctorGivenName,
        'city': city?.trim(),
        'updatedAt': now.toIso8601String(),
      },
    );
  }

  Future<String?> resolveDoctorForPatient(String fiscalCode) async {
    final List<DoctorPatientLink> links = await getLinksForPatient(fiscalCode);
    for (final DoctorPatientLinkType type in const <DoctorPatientLinkType>[
      DoctorPatientLinkType.manual,
      DoctorPatientLinkType.primary,
    ]) {
      for (final DoctorPatientLink link in links) {
        if (link.linkType != type) {
          continue;
        }
        final String doctor = link.doctorFullName.trim();
        if (doctor.isNotEmpty) {
          return doctor;
        }
      }
    }
    return null;
  }

  int _typeRank(DoctorPatientLinkType type) {
    switch (type) {
      case DoctorPatientLinkType.manual:
        return 0;
      case DoctorPatientLinkType.primary:
        return 1;
      case DoctorPatientLinkType.other:
        return 2;
    }
  }
}
