import '../../data/models/drive_pdf_import.dart';
import '../../data/repositories/drive_pdf_imports_repository.dart';
import '../../data/repositories/parser_reference_values_repository.dart';
import 'gmail_service.dart';
import 'google_drive_service.dart';
import 'pdf_text_extraction_service.dart';
import 'prescription_pdf_parser_service.dart';

class EmailPrescriptionScanResult {
  final int scannedMessages;
  final int uploadedPdfs;
  final int trashedMessages;
  final int ignoredMessages;
  final int errorCount;

  const EmailPrescriptionScanResult({
    required this.scannedMessages,
    required this.uploadedPdfs,
    required this.trashedMessages,
    required this.ignoredMessages,
    required this.errorCount,
  });
}

class EmailPrescriptionScanService {
  final GmailService gmailService;
  final GoogleDriveService googleDriveService;
  final DrivePdfImportsRepository drivePdfImportsRepository;
  final ParserReferenceValuesRepository parserReferenceValuesRepository;
  final PdfTextExtractionService pdfTextExtractionService;
  final PrescriptionPdfParserService prescriptionPdfParserService;

  const EmailPrescriptionScanService({
    required this.gmailService,
    required this.googleDriveService,
    required this.drivePdfImportsRepository,
    required this.parserReferenceValuesRepository,
    required this.pdfTextExtractionService,
    required this.prescriptionPdfParserService,
  });

  Future<EmailPrescriptionScanResult> scan({
    required String incomingDriveFolderId,
    required String processedLabelName,
    required String ignoredLabelName,
    required String query,
    required int maxResults,
    required bool trashEmailsWithPrescriptions,
  }) async {
    if (incomingDriveFolderId.trim().isEmpty) {
      throw Exception('Imposta prima la cartella Drive PDF in ingresso.');
    }

    final String processedLabelId = await gmailService.ensureLabel(processedLabelName);
    final String ignoredLabelId = await gmailService.ensureLabel(ignoredLabelName);

    final String finalQuery = _buildQuery(
      baseQuery: query,
      processedLabelName: processedLabelName,
      ignoredLabelName: ignoredLabelName,
    );

    final List<String> messageIds = await gmailService.listMessageIds(
      query: finalQuery,
      maxResults: maxResults,
    );

    final PrescriptionParserReferenceSet references =
        await _loadReferenceSet();

    int uploadedPdfs = 0;
    int trashedMessages = 0;
    int ignoredMessages = 0;
    int errorCount = 0;

    for (final String messageId in messageIds) {
      try {
        final GmailMessageDetail message = await gmailService.getMessage(messageId);
        final List<GmailAttachmentRef> pdfAttachments = message.attachments
            .where((GmailAttachmentRef item) => _isPdfAttachment(item))
            .toList();

        if (pdfAttachments.isEmpty) {
          await gmailService.modifyMessageLabels(
            messageId: messageId,
            addLabelIds: <String>[ignoredLabelId],
          );
          ignoredMessages++;
          continue;
        }

        bool uploadedSomething = false;

        for (final GmailAttachmentRef attachment in pdfAttachments) {
          final bool attachmentLooksRelevant = _looksLikePrescriptionAttachment(
            attachment.filename,
            subject: message.subject,
            snippet: message.snippet,
          );
          if (!attachmentLooksRelevant) {
            continue;
          }

          final bytes = await gmailService.downloadAttachment(
            messageId: messageId,
            attachment: attachment,
          );
          final String text = pdfTextExtractionService.extractText(bytes);

          if (!_looksLikePrescriptionText(text)) {
            continue;
          }

          final ParsedPrescriptionData parsed = prescriptionPdfParserService.parse(
            text,
            fileName: attachment.filename,
            references: references,
          );

          if (!_parsedLooksUsable(parsed)) {
            continue;
          }

          final String uploadedFileId = await googleDriveService.uploadPdfBytes(
            fileName: _buildDriveFileName(message, attachment),
            bytes: bytes,
            parentFolderId: incomingDriveFolderId,
          );

          final DateTime now = DateTime.now();
          await drivePdfImportsRepository.saveImport(
            DrivePdfImport(
              id: uploadedFileId,
              driveFileId: uploadedFileId,
              fileName: _buildDriveFileName(message, attachment),
              mimeType: 'application/pdf',
              status: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

          uploadedPdfs++;
          uploadedSomething = true;
        }

        if (uploadedSomething) {
          await gmailService.modifyMessageLabels(
            messageId: messageId,
            addLabelIds: <String>[processedLabelId],
          );

          if (trashEmailsWithPrescriptions) {
            await gmailService.trashMessage(messageId);
            trashedMessages++;
          }
        } else {
          await gmailService.modifyMessageLabels(
            messageId: messageId,
            addLabelIds: <String>[ignoredLabelId],
          );
          ignoredMessages++;
        }
      } catch (_) {
        errorCount++;
      }
    }

    return EmailPrescriptionScanResult(
      scannedMessages: messageIds.length,
      uploadedPdfs: uploadedPdfs,
      trashedMessages: trashedMessages,
      ignoredMessages: ignoredMessages,
      errorCount: errorCount,
    );
  }

  String _buildQuery({
    required String baseQuery,
    required String processedLabelName,
    required String ignoredLabelName,
  }) {
    final String trimmed = baseQuery.trim().isEmpty
        ? 'in:inbox has:attachment'
        : baseQuery.trim();
    return '$trimmed -label:"${processedLabelName.trim()}" -label:"${ignoredLabelName.trim()}"';
  }

  Future<PrescriptionParserReferenceSet> _loadReferenceSet() async {
    final values = await parserReferenceValuesRepository.getAllReferences();
    return PrescriptionParserReferenceSet(
      patientNames: values
          .where((item) => item.type == 'patient')
          .map((item) => item.value)
          .toList(),
      doctorNames: values
          .where((item) => item.type == 'doctor')
          .map((item) => item.value)
          .toList(),
      cities: values
          .where((item) => item.type == 'city')
          .map((item) => item.value)
          .toList(),
    );
  }

  bool _isPdfAttachment(GmailAttachmentRef item) {
    final String name = item.filename.toLowerCase();
    return item.mimeType.toLowerCase().contains('pdf') || name.endsWith('.pdf');
  }

  bool _looksLikePrescriptionAttachment(
    String fileName, {
    required String subject,
    required String snippet,
  }) {
    final String haystack = '$fileName $subject $snippet'.toUpperCase();
    const List<String> hints = <String>[
      'RICET',
      'NRE',
      'PROMEMORIA',
      'FARMAC',
      'PRESCRIZ',
      'DEMATERIAL',
      'SSN',
      'DPC',
    ];
    return hints.any(haystack.contains) || fileName.toLowerCase().endsWith('.pdf');
  }

  bool _looksLikePrescriptionText(String text) {
    final String upper = text.toUpperCase();
    const List<String> markers = <String>[
      'SERVIZIO SANITARIO NAZIONALE',
      'RICETTA ELETTRONICA',
      'PROMEMORIA',
      'COGNOME E NOME DEL MEDICO',
      'ESENZIONE',
      'NRE',
    ];
    int found = 0;
    for (final String marker in markers) {
      if (upper.contains(marker)) found++;
    }
    return found >= 2;
  }

  bool _parsedLooksUsable(ParsedPrescriptionData parsed) {
    if (parsed.patientName.isNotEmpty) return true;
    if (parsed.doctorName.isNotEmpty) return true;
    if (parsed.fiscalCode.isNotEmpty) return true;
    if (parsed.medicines.isNotEmpty) return true;
    if (parsed.prescriptionDate != null) return true;
    return false;
  }

  String _buildDriveFileName(GmailMessageDetail message, GmailAttachmentRef attachment) {
    final String cleanAttachment = attachment.filename.trim().isEmpty
        ? 'ricetta_email.pdf'
        : attachment.filename.trim();
    final String subject = message.subject.trim();
    if (subject.isEmpty) return cleanAttachment;

    final String sanitizedSubject = subject.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitizedSubject.isEmpty) return cleanAttachment;
    return '${sanitizedSubject}_$cleanAttachment';
  }
}
