import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/booking.dart';
import 'runtime_signal_repository.dart';

class BookingsRepository {
  final FirestoreDatasource datasource;

  const BookingsRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignals => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveBooking(Booking booking) async {
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: booking.patientFiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: booking.id,
      data: booking.toMap(),
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'bookings',
      operation: 'sync',
      targetPath: 'patients/${booking.patientFiscalCode}/bookings/${booking.id}',
      targetFiscalCode: booking.patientFiscalCode,
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
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: id,
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'bookings',
      operation: 'delete',
      targetPath: 'patients/$fiscalCode/bookings/$id',
      targetFiscalCode: fiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
