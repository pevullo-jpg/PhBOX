import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/booking.dart';

class BookingsRepository {
  final FirestoreDatasource datasource;

  const BookingsRepository({required this.datasource});

  Future<void> saveBooking(Booking booking) {
    return datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: booking.patientFiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: booking.id,
      data: booking.toMap(),
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


  Future<void> deleteBooking(String fiscalCode, String id) {
    return datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.bookings,
      subDocumentId: id,
    );
  }
}
