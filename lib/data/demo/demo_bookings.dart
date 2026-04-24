import '../models/booking.dart';

final List<Booking> demoBookings = <Booking>[
  Booking(
    id: 'book_001',
    patientFiscalCode: 'RSSMRA80A01F205X',
    patientName: 'Mario Rossi',
    drugName: 'Metformina',
    quantity: 2,
    note: 'Ordine in arrivo',
    createdAt: DateTime(2026, 3, 11),
    expectedDate: DateTime(2026, 3, 13),
    status: 'pending',
  ),
];
