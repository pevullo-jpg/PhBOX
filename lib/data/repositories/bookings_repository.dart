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

  Future<List<Booking>> getPatientBookings(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.bookings,
      orderBy: 'createdAt',
      descending: true,
    );
    return maps.map(Booking.fromMap).toList();
  }



  Future<List<Booking>> getAllBookings() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.bookings,
    );
    final bookings = maps.map(Booking.fromMap).where((item) => item.patientFiscalCode.trim().isNotEmpty).toList();
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
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
