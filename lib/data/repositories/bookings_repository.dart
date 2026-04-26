import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/booking.dart';
import 'runtime_signal_repository.dart';

class BookingsRepository {
  final FirestoreDatasource datasource;

  const BookingsRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignalRepository => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveBooking(Booking booking) async {
    final String fiscalCode = booking.patientFiscalCode.trim().toUpperCase();
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: booking.id,
      data: booking.toMap(),
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'bookings',
      operation: 'sync',
      targetPath: '${AppCollections.patients}/$fiscalCode/${AppCollections.bookings}/${booking.id}',
      targetFiscalCode: fiscalCode,
      targetDocumentId: booking.id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }

  Future<List<Booking>> getAllBookings() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.bookings,
    );
    return maps.map(Booking.fromMap).toList();
  }

  Future<List<Booking>> getPatientBookings(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.bookings,
    );
    return maps.map(Booking.fromMap).toList();
  }

  Future<void> deleteBooking(String fiscalCode, String id) async {
    final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedFiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: id,
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'bookings',
      operation: 'delete',
      targetPath: '${AppCollections.patients}/$normalizedFiscalCode/${AppCollections.bookings}/$id',
      targetFiscalCode: normalizedFiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
