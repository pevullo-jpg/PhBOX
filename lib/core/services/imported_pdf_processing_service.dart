import '../../data/models/drive_pdf_import.dart';
import '../../data/models/prescription_intake.dart';
import '../../data/repositories/drive_pdf_imports_repository.dart';
import '../../data/repositories/prescription_intakes_repository.dart';
import 'google_drive_service.dart';
import 'pdf_text_extraction_service.dart';
import 'prescription_pdf_parser_service.dart';

class ImportedPdfProcessingResult {
  final int processedCount;
  final int failedCount;

  const ImportedPdfProcessingResult({
    required this.processedCount,
    required this.failedCount,
  });
}

class ImportedPdfProcessingService {
  final GoogleDriveService googleDriveService;
  final DrivePdfImportsRepository drivePdfImportsRepository;
  final PrescriptionIntakesRepository prescriptionIntakesRepository;
  final PdfTextExtractionService pdfTextExtractionService;
  final PrescriptionPdfParserService prescriptionPdfParserService;

  const ImportedPdfProcessingService({
    required this.googleDriveService,
    required this.drivePdfImportsRepository,
    required this.prescriptionIntakesRepository,
    required this.pdfTextExtractionService,
    required this.prescriptionPdfParserService,
  });

  Future<ImportedPdfProcessingResult> processPendingImports() async {
    final List<DrivePdfImport> imports =
        await drivePdfImportsRepository.getAllImports();

    int processed = 0;
    int failed = 0;

    for (final DrivePdfImport item in imports) {
      if (item.status == 'parsed') continue;

      try {
        await drivePdfImportsRepository.saveImport(
          item.copyWith(
            status: 'processing',
            updatedAt: DateTime.now(),
            errorMessage: '',
          ),
        );

        final bytes = await googleDriveService.downloadPdfBytes(item.driveFileId);
        final String text = pdfTextExtractionService.extractText(bytes);
        final ParsedPrescriptionData parsed =
            prescriptionPdfParserService.parse(text, fileName: item.fileName);

        final PrescriptionIntake intake = PrescriptionIntake(
          id: item.driveFileId,
          driveFileId: item.driveFileId,
          fileName: item.fileName,
          patientName: parsed.patientName,
          fiscalCode: parsed.fiscalCode,
          doctorName: parsed.doctorName,
          exemptionCode: parsed.exemptionCode,
          city: parsed.city,
          prescriptionDate: parsed.prescriptionDate,
          dpcFlag: parsed.dpcFlag,
          prescriptionCount: parsed.prescriptionCount,
          medicines: parsed.medicines,
          rawText: parsed.rawText,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await prescriptionIntakesRepository.saveIntake(intake);

        await drivePdfImportsRepository.saveImport(
          item.copyWith(
            status: 'parsed',
            updatedAt: DateTime.now(),
            errorMessage: '',
          ),
        );

        processed++;
      } catch (e) {
        failed++;
        await drivePdfImportsRepository.saveImport(
          item.copyWith(
            status: 'error',
            updatedAt: DateTime.now(),
            errorMessage: '$e',
          ),
        );
      }
    }

    return ImportedPdfProcessingResult(
      processedCount: processed,
      failedCount: failed,
    );
  }
}
