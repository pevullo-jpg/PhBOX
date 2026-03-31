import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/booking.dart';
import '../models/patient.dart';

class BookingsRepository {
  final FirestoreDatasource datasource;
  const BookingsRepository({required this.datasource});

  Future<void> saveBooking(Booking booking) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: booking.patientFiscalCode);
    final patient = raw == null ? Patient(fiscalCode: booking.patientFiscalCode, fullName: booking.patientName, createdAt: DateTime.now(), updatedAt: DateTime.now()) : Patient.fromMap(raw);
    final items = List<Booking>.from(patient.bookings);
    final index = items.indexWhere((item) => item.id == booking.id);
    if (index >= 0) { items[index] = booking; } else { items.insert(0, booking); }
    final updated = patient.copyWith(bookings: items, hasBooking: items.isNotEmpty, activeBookingsCount: items.length, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: booking.patientFiscalCode, data: updated.toMap());
  }

  Future<List<Booking>> getPatientBookings(String fiscalCode) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return const <Booking>[];
    return Patient.fromMap(raw).bookings;
  }

  Future<void> deleteBooking(String fiscalCode, String id) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return;
    final patient = Patient.fromMap(raw);
    final items = patient.bookings.where((item) => item.id != id).toList();
    final updated = patient.copyWith(bookings: items, hasBooking: items.isNotEmpty, activeBookingsCount: items.length, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: fiscalCode, data: updated.toMap());
  }
}
