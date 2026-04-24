import '../models/debt.dart';

final List<Debt> demoDebts = <Debt>[
  Debt(
    id: 'debt_001',
    patientFiscalCode: 'RSSMRA80A01F205X',
    patientName: 'Mario Rossi',
    description: 'Ticket + integratore',
    amount: 18.50,
    paidAmount: 0,
    residualAmount: 18.50,
    createdAt: DateTime(2026, 3, 10),
    dueDate: DateTime(2026, 3, 20),
    status: 'open',
    note: 'Pagamento alla consegna',
  ),
];
