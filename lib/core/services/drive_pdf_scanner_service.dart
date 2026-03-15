import '../../data/models/drive_pdf_import.dart';
import '../../data/repositories/drive_pdf_imports_repository.dart';
import 'google_drive_service.dart';

class DrivePdfScannerResult {
  final int importedCount;
  final List<DrivePdfImport> imports;

  const DrivePdfScannerResult({
    required this.importedCount,
    required this.imports,
  });
}

class DrivePdfScannerService {
  final GoogleDriveService googleDriveService;
  final DrivePdfImportsRepository importsRepository;

  const DrivePdfScannerService({
    required this.googleDriveService,
    required this.importsRepository,
  });

  Future<DrivePdfScannerResult> scanFolder(String folderId) async {
    final List<GoogleDriveFile> files =
        await googleDriveService.listPdfFiles(folderId);

    final List<DrivePdfImport> imports = <DrivePdfImport>[];

    for (final GoogleDriveFile file in files) {
      final DrivePdfImport import = DrivePdfImport(
        id: file.id,
        driveFileId: file.id,
        fileName: file.name,
        mimeType: file.mimeType,
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await importsRepository.saveImport(import);
      imports.add(import);
    }

    return DrivePdfScannerResult(
      importedCount: imports.length,
      imports: imports,
    );
  }
}
