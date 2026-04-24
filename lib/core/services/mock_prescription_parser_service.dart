import '../../data/models/prescription.dart';
import '../../data/models/prescription_item.dart';

class MockPrescriptionParserResult {
  final String patientName;
  final String fiscalCode;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final bool dpcFlag;
  final DateTime prescriptionDate;
  final DateTime expiryDate;
  final List<PrescriptionItem> items;
  final String extractedText;

  MockPrescriptionParserResult({
    required this.patientName,
    required this.fiscalCode,
    required this.doctorName,
    required this.exemptionCode,
    required this.city,
    required this.dpcFlag,
    required this.prescriptionDate,
    required this.expiryDate,
    required this.items,
    required this.extractedText,
  });

  Prescription toPrescription() {
    return Prescription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      patientFiscalCode: fiscalCode,
      patientName: patientName,
      prescriptionDate: prescriptionDate,
      expiryDate: expiryDate,
      doctorName: doctorName,
      exemptionCode: exemptionCode,
      city: city,
      dpcFlag: dpcFlag,
      sourceType: 'upload',
      extractedText: extractedText,
      items: items,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class MockPrescriptionParserService {
  MockPrescriptionParserResult parse({
    required String fileName,
    required String rawText,
  }) {
    final String lower = '$fileName $rawText'.toLowerCase();

    final bool mario = lower.contains('mario') || lower.contains('rossi');
    final bool luigi = lower.contains('luigi') || lower.contains('verdi');
    final bool giuseppe = lower.contains('giuseppe') || lower.contains('bianchi');

    if (mario) {
      return MockPrescriptionParserResult(
        patientName: 'Mario Rossi',
        fiscalCode: 'RSSMRA80A01F205X',
        doctorName: 'Dr. Bianchi',
        exemptionCode: 'E01',
        city: 'Agrigento',
        dpcFlag: true,
        prescriptionDate: DateTime(2026, 3, 12),
        expiryDate: DateTime(2026, 4, 12),
        items: <PrescriptionItem>[
          const PrescriptionItem(drugName: 'Cardioaspirina', dosage: '100 mg', quantity: 1),
          const PrescriptionItem(drugName: 'Metformina', dosage: '500 mg', quantity: 2),
        ],
        extractedText: 'Mario Rossi CF RSSMRA80A01F205X DPC Cardioaspirina Metformina',
      );
    }

    if (luigi) {
      return MockPrescriptionParserResult(
        patientName: 'Luigi Verdi',
        fiscalCode: 'VRDLGI75B22A089Y',
        doctorName: 'Dr.ssa Neri',
        exemptionCode: 'C02',
        city: 'Favara',
        dpcFlag: false,
        prescriptionDate: DateTime(2026, 3, 12),
        expiryDate: DateTime(2026, 4, 12),
        items: <PrescriptionItem>[
          const PrescriptionItem(drugName: 'Bisoprololo', dosage: '2.5 mg', quantity: 1),
        ],
        extractedText: 'Luigi Verdi CF VRDLGI75B22A089Y Bisoprololo',
      );
    }

    if (giuseppe) {
      return MockPrescriptionParserResult(
        patientName: 'Giuseppe Bianchi',
        fiscalCode: 'BNCGPP90C10G273K',
        doctorName: 'Dr. Greco',
        exemptionCode: 'E30',
        city: 'Canicatti',
        dpcFlag: true,
        prescriptionDate: DateTime(2026, 3, 12),
        expiryDate: DateTime(2026, 4, 12),
        items: <PrescriptionItem>[
          const PrescriptionItem(drugName: 'Pantoprazolo', dosage: '20 mg', quantity: 1),
          const PrescriptionItem(drugName: 'Amlodipina', dosage: '5 mg', quantity: 1),
        ],
        extractedText: 'Giuseppe Bianchi CF BNCGPP90C10G273K DPC Pantoprazolo Amlodipina',
      );
    }

    return MockPrescriptionParserResult(
      patientName: 'Maria Palla',
      fiscalCode: 'PLLMRA68D41A176T',
      doctorName: 'Dr. Romano',
      exemptionCode: 'E12',
      city: 'Licata',
      dpcFlag: false,
      prescriptionDate: DateTime(2026, 3, 12),
      expiryDate: DateTime(2026, 4, 12),
      items: <PrescriptionItem>[
        const PrescriptionItem(drugName: 'Eutirox', dosage: '50 mcg', quantity: 1),
        const PrescriptionItem(drugName: 'Lasix', dosage: '25 mg', quantity: 1),
      ],
      extractedText: 'Maria Palla CF PLLMRA68D41A176T Eutirox Lasix',
    );
  }
}
