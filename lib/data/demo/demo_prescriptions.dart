import '../models/prescription.dart';
import '../models/prescription_item.dart';

final List<Prescription> demoPrescriptions = <Prescription>[
  Prescription(
    id: 'rx_001',
    patientFiscalCode: 'RSSMRA80A01F205X',
    patientName: 'Mario Rossi',
    prescriptionDate: DateTime(2026, 3, 10),
    expiryDate: DateTime(2026, 4, 10),
    doctorName: 'Dr. Bianchi',
    exemptionCode: 'E01',
    city: 'Agrigento',
    dpcFlag: true,
    sourceType: 'seed',
    extractedText: 'Mario Rossi DPC Cardioaspirina Metformina',
    items: <PrescriptionItem>[
      const PrescriptionItem(drugName: 'Cardioaspirina', dosage: '100 mg', quantity: 1),
      const PrescriptionItem(drugName: 'Metformina', dosage: '500 mg', quantity: 2),
    ],
    createdAt: DateTime(2026, 3, 10),
    updatedAt: DateTime(2026, 3, 10),
  ),
];
