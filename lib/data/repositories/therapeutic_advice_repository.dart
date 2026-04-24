import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/therapeutic_advice_note.dart';

class TherapeuticAdviceRepository {
  final FirestoreDatasource datasource;

  const TherapeuticAdviceRepository({required this.datasource});

  Future<TherapeuticAdviceNote?> getByFiscalCode(String fiscalCode) async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      documentId: fiscalCode.trim().toUpperCase(),
    );
    if (map == null) return null;
    return TherapeuticAdviceNote.fromMap(map);
  }



  Future<List<TherapeuticAdviceNote>> getAllNotes() async {
    final List<Map<String, dynamic>> rows = await datasource.getCollection(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      orderBy: 'updatedAt',
      descending: true,
    );
    return rows
        .map((Map<String, dynamic> row) => TherapeuticAdviceNote.fromMap(row))
        .toList();
  }

  Future<void> save({
    required String fiscalCode,
    required String text,
  }) async {
    final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
    final TherapeuticAdviceNote? current = await getByFiscalCode(normalizedFiscalCode);
    final DateTime now = DateTime.now();
    final TherapeuticAdviceNote next = TherapeuticAdviceNote(
      patientFiscalCode: normalizedFiscalCode,
      text: text,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    await datasource.setDocument(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      documentId: normalizedFiscalCode,
      data: next.toMap(),
    );
  }

  Future<void> clear(String fiscalCode) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      documentId: fiscalCode.trim().toUpperCase(),
    );
  }
}
