import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../constants/app_constants.dart';
import '../../data/models/advance.dart';
import '../../data/models/booking.dart';
import '../../data/models/debt.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/advances_repository.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/repositories/debts_repository.dart';
import '../../data/repositories/patients_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../utils/file_download.dart';
import 'google_drive_service.dart';

enum BackupExportDestination {
  download,
  drive,
}

class BackupSnapshotBundle {
  final String jsonFilename;
  final String jsonContent;
  final String reportPdfFilename;
  final Uint8List reportPdfBytes;
  final Map<String, dynamic> payload;

  const BackupSnapshotBundle({
    required this.jsonFilename,
    required this.jsonContent,
    required this.reportPdfFilename,
    required this.reportPdfBytes,
    required this.payload,
  });
}

class BackupExportResult {
  final String jsonFilename;
  final String reportPdfFilename;
  final BackupExportDestination destination;

  const BackupExportResult({
    required this.jsonFilename,
    required this.reportPdfFilename,
    required this.destination,
  });
}

class BackupExportService {
  final FirebaseFirestore firestore;
  final SettingsRepository settingsRepository;
  final PatientsRepository patientsRepository;
  final DebtsRepository debtsRepository;
  final AdvancesRepository advancesRepository;
  final BookingsRepository bookingsRepository;

  const BackupExportService({
    required this.firestore,
    required this.settingsRepository,
    required this.patientsRepository,
    required this.debtsRepository,
    required this.advancesRepository,
    required this.bookingsRepository,
  });

  Future<BackupSnapshotBundle> buildSnapshotBundle() async {
    final List<dynamic> modelResults = await Future.wait<dynamic>(<Future<dynamic>>[
      patientsRepository.getAllPatients(),
      debtsRepository.getAllDebts(),
      advancesRepository.getAllAdvances(),
      bookingsRepository.getAllBookings(),
    ]);

    final List<dynamic> rawResults = await Future.wait<dynamic>(<Future<dynamic>>[
      _readRootDocument(
        collectionPath: AppCollections.appSettings,
        documentId: 'main',
      ),
      _readRootCollection(AppCollections.patients),
      _readRootCollection(AppCollections.families),
      _readRootCollection(AppCollections.doctorPatientLinks),
      _readCollectionGroup(AppCollections.prescriptions),
      _readRootCollection(AppCollections.drivePdfImports),
      _readCollectionGroup(AppCollections.debts),
      _readCollectionGroup(AppCollections.advances),
      _readCollectionGroup(AppCollections.bookings),
      _readRootCollection(AppCollections.patientTherapeuticAdvice),
      _readRootCollection(AppCollections.prescriptionIntakes),
      _readRootCollection(AppCollections.parserReferenceValues),
    ]);

    final List<Patient> patients = modelResults[0] as List<Patient>;
    final List<Debt> debts = modelResults[1] as List<Debt>;
    final List<Advance> advances = modelResults[2] as List<Advance>;
    final List<Booking> bookings = modelResults[3] as List<Booking>;

    final Map<String, dynamic> appSettingsRaw =
        rawResults[0] as Map<String, dynamic>;
    final List<Map<String, dynamic>> patientsRaw =
        rawResults[1] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> familiesRaw =
        rawResults[2] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> doctorLinksRaw =
        rawResults[3] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> prescriptionsRaw =
        rawResults[4] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> importsRaw =
        rawResults[5] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> debtsRaw =
        rawResults[6] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> advancesRaw =
        rawResults[7] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> bookingsRaw =
        rawResults[8] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> therapeuticAdviceRaw =
        rawResults[9] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> intakesRaw =
        rawResults[10] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> parserReferencesRaw =
        rawResults[11] as List<Map<String, dynamic>>;

    final DateTime now = DateTime.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'exportedAt': now.toIso8601String(),
      'source': 'PhBOX frontend backup',
      'schemaVersion': 2,
      'collections': <String, dynamic>{
        'app_settings': appSettingsRaw,
        'patients': patientsRaw,
        'families': familiesRaw,
        'doctor_patient_links': doctorLinksRaw,
        'prescriptions': prescriptionsRaw,
        'drive_pdf_imports': importsRaw,
        'debts': debtsRaw,
        'advances': advancesRaw,
        'bookings': bookingsRaw,
        'patient_therapeutic_advice': therapeuticAdviceRaw,
        'prescription_intakes': intakesRaw,
        'parser_reference_values': parserReferencesRaw,
      },
      'counts': <String, int>{
        'patients': patientsRaw.length,
        'families': familiesRaw.length,
        'doctor_patient_links': doctorLinksRaw.length,
        'prescriptions': prescriptionsRaw.length,
        'drive_pdf_imports': importsRaw.length,
        'debts': debtsRaw.length,
        'advances': advancesRaw.length,
        'bookings': bookingsRaw.length,
        'patient_therapeutic_advice': therapeuticAdviceRaw.length,
        'prescription_intakes': intakesRaw.length,
        'parser_reference_values': parserReferencesRaw.length,
      },
    };

    final String jsonFilename = _buildJsonFileName(now);
    final String reportPdfFilename = _buildReportPdfFileName(now);
    final String jsonContent = const JsonEncoder.withIndent('  ').convert(payload);
    final Uint8List reportPdfBytes = _buildSummaryReportPdf(
      exportedAt: now,
      patients: patients,
      debts: debts,
      bookings: bookings,
      advances: advances,
    );

    return BackupSnapshotBundle(
      jsonFilename: jsonFilename,
      jsonContent: jsonContent,
      reportPdfFilename: reportPdfFilename,
      reportPdfBytes: reportPdfBytes,
      payload: payload,
    );
  }

  Future<BackupExportResult> exportCurrentSnapshot({
    BackupExportDestination destination = BackupExportDestination.download,
    GoogleDriveService? googleDriveService,
    String? driveFolderId,
    String trigger = 'manual',
  }) async {
    final BackupSnapshotBundle bundle = await buildSnapshotBundle();

    if (destination == BackupExportDestination.download) {
      await downloadTextFile(
        filename: bundle.jsonFilename,
        content: bundle.jsonContent,
      );
      await downloadBinaryFile(
        filename: bundle.reportPdfFilename,
        bytes: bundle.reportPdfBytes,
        mimeType: 'application/pdf',
      );
    } else {
      final GoogleDriveService driveService = googleDriveService ??
          (throw Exception('Servizio Google Drive assente.'));
      final String targetFolderId = (driveFolderId ?? '').trim();
      if (targetFolderId.isEmpty) {
        throw Exception('Inserisci l\'ID della cartella Drive di backup.');
      }
      await driveService.uploadFileBytes(
        fileName: bundle.jsonFilename,
        bytes: Uint8List.fromList(utf8.encode(bundle.jsonContent)),
        parentFolderId: targetFolderId,
        mimeType: 'application/json',
      );
      await driveService.uploadPdfBytes(
        fileName: bundle.reportPdfFilename,
        bytes: bundle.reportPdfBytes,
        parentFolderId: targetFolderId,
      );
    }

    final String status = destination == BackupExportDestination.download
        ? 'ok:$trigger:download'
        : 'ok:$trigger:drive';
    await settingsRepository.recordBackupRun(
      at: DateTime.now(),
      status: status,
    );

    return BackupExportResult(
      jsonFilename: bundle.jsonFilename,
      reportPdfFilename: bundle.reportPdfFilename,
      destination: destination,
    );
  }


  Future<Map<String, dynamic>> _readRootDocument({
    required String collectionPath,
    required String documentId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection(collectionPath).doc(documentId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return <String, dynamic>{};
    }
    return _sanitizeMap(data, documentId: snapshot.id);
  }

  Future<List<Map<String, dynamic>>> _readRootCollection(String collectionPath) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection(collectionPath).get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _sanitizeMap(doc.data(), documentId: doc.id),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _readCollectionGroup(String collectionPath) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore.collectionGroup(collectionPath).get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _sanitizeMap(doc.data(), documentId: doc.id),
        )
        .toList();
  }

  Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    final Map<String, dynamic> raw =
        _sanitizeForJson(Map<String, dynamic>.from(data)) as Map<String, dynamic>;
    if (!raw.containsKey('id')) {
      raw['id'] = documentId;
    }
    return raw;
  }

  dynamic _sanitizeForJson(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (MapEntry<dynamic, dynamic> entry) => MapEntry<String, dynamic>(
            entry.key.toString(),
            _sanitizeForJson(entry.value),
          ),
        ),
      );
    }
    if (value is List) {
      return value.map(_sanitizeForJson).toList();
    }
    return value;
  }

  Uint8List _buildSummaryReportPdf({
    required DateTime exportedAt,
    required List<Patient> patients,
    required List<Debt> debts,
    required List<Booking> bookings,
    required List<Advance> advances,
  }) {
    final PdfDocument document = PdfDocument();
    PdfPage page = document.pages.add();
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16,
        style: PdfFontStyle.bold);
    final PdfFont sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 13,
        style: PdfFontStyle.bold);
    final PdfFont lineFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont lineBoldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      10,
      style: PdfFontStyle.bold,
    );

    final double pageWidth = page.getClientSize().width - 40;
    final double pageHeight = page.getClientSize().height - 30;
    double y = 20;

    void ensureSpace(double neededHeight) {
      if (y + neededHeight <= pageHeight) {
        return;
      }
      page = document.pages.add();
      y = 20;
    }

    void drawLine(String text, PdfFont font, {double gapAfter = 4}) {
      final List<String> lines = _wrapText(text, 110);
      for (final String line in lines) {
        ensureSpace(16);
        page.graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(20, y, pageWidth, 16),
        );
        y += 14;
      }
      y += gapAfter;
    }

    final Map<String, Patient> patientsByCode = <String, Patient>{
      for (final Patient patient in patients) patient.fiscalCode.trim().toUpperCase(): patient,
    };

    drawLine('PhBOX - Riepilogo operativo backup', titleFont, gapAfter: 2);
    drawLine(
      'Esportato il ${_formatDateTime(exportedAt)}',
      lineFont,
      gapAfter: 10,
    );

    drawLine('1. Debiti per assistito', sectionFont, gapAfter: 6);
    final List<Debt> sortedDebts = <Debt>[...debts]
      ..sort((Debt a, Debt b) {
        final int byPatient = _patientLabelForCode(
          a.patientFiscalCode,
          a.patientName,
          patientsByCode,
        ).compareTo(
          _patientLabelForCode(
            b.patientFiscalCode,
            b.patientName,
            patientsByCode,
          ),
        );
        if (byPatient != 0) return byPatient;
        return a.createdAt.compareTo(b.createdAt);
      });
    if (sortedDebts.isEmpty) {
      drawLine('Nessun debito aperto o storico presente.', lineFont, gapAfter: 10);
    } else {
      String currentPatientKey = '';
      for (final Debt debt in sortedDebts) {
        final String patientKey = debt.patientFiscalCode.trim().toUpperCase();
        if (patientKey != currentPatientKey) {
          currentPatientKey = patientKey;
          drawLine(
            _patientHeading(
              fiscalCode: debt.patientFiscalCode,
              fallbackName: debt.patientName,
              patientsByCode: patientsByCode,
            ),
            lineBoldFont,
            gapAfter: 2,
          );
        }
        drawLine(
          '- ${debt.description} | totale ${_formatCurrency(debt.amount)} | residuo ${_formatCurrency(debt.residualAmount)}${debt.note == null || debt.note!.trim().isEmpty ? '' : ' | nota: ${debt.note!.trim()}'}',
          lineFont,
        );
      }
      y += 6;
    }

    drawLine('2. Prenotazioni per assistito', sectionFont, gapAfter: 6);
    final List<Booking> sortedBookings = <Booking>[...bookings]
      ..sort((Booking a, Booking b) {
        final int byPatient = _patientLabelForCode(
          a.patientFiscalCode,
          a.patientName,
          patientsByCode,
        ).compareTo(
          _patientLabelForCode(
            b.patientFiscalCode,
            b.patientName,
            patientsByCode,
          ),
        );
        if (byPatient != 0) return byPatient;
        return a.createdAt.compareTo(b.createdAt);
      });
    if (sortedBookings.isEmpty) {
      drawLine('Nessuna prenotazione presente.', lineFont, gapAfter: 10);
    } else {
      String currentPatientKey = '';
      for (final Booking booking in sortedBookings) {
        final String patientKey = booking.patientFiscalCode.trim().toUpperCase();
        if (patientKey != currentPatientKey) {
          currentPatientKey = patientKey;
          drawLine(
            _patientHeading(
              fiscalCode: booking.patientFiscalCode,
              fallbackName: booking.patientName,
              patientsByCode: patientsByCode,
            ),
            lineBoldFont,
            gapAfter: 2,
          );
        }
        final String expectedDate = booking.expectedDate == null
            ? '-'
            : _formatDate(booking.expectedDate!);
        drawLine(
          '- ${booking.drugName} | qta ${booking.quantity} | prevista $expectedDate${booking.note == null || booking.note!.trim().isEmpty ? '' : ' | nota: ${booking.note!.trim()}'}',
          lineFont,
        );
      }
      y += 6;
    }

    drawLine(
      '3. Anticipi per medico e assistito',
      sectionFont,
      gapAfter: 6,
    );
    final List<Advance> sortedAdvances = <Advance>[...advances]
      ..sort((Advance a, Advance b) {
        final String doctorA = a.doctorName.trim().toUpperCase();
        final String doctorB = b.doctorName.trim().toUpperCase();
        final int byDoctor = doctorA.compareTo(doctorB);
        if (byDoctor != 0) return byDoctor;
        final int byPatient = _patientLabelForCode(
          a.patientFiscalCode,
          a.patientName,
          patientsByCode,
        ).compareTo(
          _patientLabelForCode(
            b.patientFiscalCode,
            b.patientName,
            patientsByCode,
          ),
        );
        if (byPatient != 0) return byPatient;
        return a.createdAt.compareTo(b.createdAt);
      });
    if (sortedAdvances.isEmpty) {
      drawLine('Nessun anticipo presente.', lineFont, gapAfter: 10);
    } else {
      String currentDoctor = '';
      String currentPatientKey = '';
      for (final Advance advance in sortedAdvances) {
        final String doctor = advance.doctorName.trim().isEmpty
            ? 'MEDICO NON INDICATO'
            : advance.doctorName.trim().toUpperCase();
        final String patientKey = advance.patientFiscalCode.trim().toUpperCase();
        if (doctor != currentDoctor) {
          currentDoctor = doctor;
          currentPatientKey = '';
          drawLine(doctor, lineBoldFont, gapAfter: 2);
        }
        if (patientKey != currentPatientKey) {
          currentPatientKey = patientKey;
          drawLine(
            '  ${_patientHeading(
              fiscalCode: advance.patientFiscalCode,
              fallbackName: advance.patientName,
              patientsByCode: patientsByCode,
            )}',
            lineFont,
            gapAfter: 2,
          );
        }
        drawLine(
          '    - ${advance.drugName}${advance.note == null || advance.note!.trim().isEmpty ? '' : ' | nota: ${advance.note!.trim()}'}',
          lineFont,
        );
      }
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  String _patientHeading({
    required String fiscalCode,
    required String fallbackName,
    required Map<String, Patient> patientsByCode,
  }) {
    final String normalizedCode = fiscalCode.trim().toUpperCase();
    final Patient? patient = patientsByCode[normalizedCode];
    final String fullName = (patient?.fullName ?? fallbackName).trim();
    final String alias = (patient?.alias ?? '').trim();
    final String aliasChunk = alias.isEmpty ? '' : ' [$alias]';
    if (fullName.isEmpty && normalizedCode.isEmpty) {
      return 'Assistito non identificato';
    }
    return '${fullName.isEmpty ? 'Assistito non nominato' : fullName}$aliasChunk - ${normalizedCode.isEmpty ? '-' : normalizedCode}';
  }

  String _patientLabelForCode(
    String fiscalCode,
    String fallbackName,
    Map<String, Patient> patientsByCode,
  ) {
    return _patientHeading(
      fiscalCode: fiscalCode,
      fallbackName: fallbackName,
      patientsByCode: patientsByCode,
    ).toUpperCase();
  }

  List<String> _wrapText(String text, int maxChars) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return <String>[''];
    }
    final List<String> words = trimmed.split(RegExp(r'\s+'));
    final List<String> lines = <String>[];
    final StringBuffer buffer = StringBuffer();
    for (final String word in words) {
      final String current = buffer.toString();
      final String next = current.isEmpty ? word : '$current $word';
      if (next.length <= maxChars) {
        buffer
          ..clear()
          ..write(next);
        continue;
      }
      if (current.isNotEmpty) {
        lines.add(current);
        buffer
          ..clear()
          ..write(word);
      } else {
        lines.add(word);
      }
    }
    final String residual = buffer.toString();
    if (residual.isNotEmpty) {
      lines.add(residual);
    }
    return lines.isEmpty ? <String>[''] : lines;
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',') + ' €';
  }

  String _formatDate(DateTime value) {
    final String d = value.day.toString().padLeft(2, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String y = value.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  String _formatDateTime(DateTime value) {
    final String hh = value.hour.toString().padLeft(2, '0');
    final String mm = value.minute.toString().padLeft(2, '0');
    return '${_formatDate(value)} $hh:$mm';
  }

  String _buildJsonFileName(DateTime now) {
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    return 'phbox_backup_${y}${m}${d}_${hh}${mm}${ss}.json';
  }

  String _buildReportPdfFileName(DateTime now) {
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    return 'phbox_riepilogo_${y}${m}${d}_${hh}${mm}${ss}.pdf';
  }
}
