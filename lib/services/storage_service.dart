import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:family_boxes_2/models/app_data.dart';

class StorageService {
  static const String _baseFileName = 'family_boxes_data';
  static String _scope = 'default';

  static void setScope(String? scope) {
    final value = (scope ?? '').trim();
    if (value.isEmpty) {
      _scope = 'default';
      return;
    }
    _scope = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final suffix = _scope == 'default' ? '' : '_$_scope';
    return File('${dir.path}/${_baseFileName}${suffix}.json');
  }

  static Future<AppData?> loadData() async {
    try {
      final file = await _localFile();

      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return AppData.empty();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AppData.empty();
      }

      return AppData.fromJson(decoded);
    } catch (_) {
      return AppData.empty();
    }
  }

  static Future<void> saveData(AppData data) async {
    final file = await _localFile();
    final raw = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(raw, flush: true);
  }

  static Future<void> save(AppData data) async {
    await saveData(data);
  }

  static Future<AppData> parseJsonString(String raw) async {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return AppData.fromJson(decoded);
      }

      if (decoded is Map) {
        return AppData.fromJson(Map<String, dynamic>.from(decoded));
      }

      return AppData.empty();
    } catch (_) {
      return AppData.empty();
    }
  }

  static Future<File?> exportToTempFile({
    required AppData data,
    String prefix = 'family_boxes_export',
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();

      final timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final file = File('${dir.path}/${prefix}_$timestamp.json');
      final raw = const JsonEncoder.withIndent('  ').convert(data.toJson());

      await file.writeAsString(raw, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> exportToChosenFolder({
    required AppData data,
    String? folderPath,
    String prefix = 'family_boxes_export',
  }) async {
    try {
      String? targetFolder = folderPath;

      if (targetFolder == null || targetFolder.trim().isEmpty) {
        targetFolder = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Seleziona cartella export',
        );
      }

      if (targetFolder == null || targetFolder.trim().isEmpty) {
        return null;
      }

      final dir = Directory(targetFolder);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final file = File('${dir.path}/${prefix}_$timestamp.json');
      final raw = const JsonEncoder.withIndent('  ').convert(data.toJson());

      await file.writeAsString(raw, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<AppData?> importFromPickedJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.single;

      if (file.bytes != null) {
        final raw = utf8.decode(file.bytes!);
        return parseJsonString(raw);
      }

      if (file.path != null && file.path!.isNotEmpty) {
        final raw = await File(file.path!).readAsString();
        return parseJsonString(raw);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<AppData> ensureCompatibleData(AppData? data) async {
    return data ?? AppData.empty();
  }

  static AppData normalizeImportedData(Map<String, dynamic> json) {
    return AppData.fromJson({
      'boxes': json['boxes'] ?? [],
      'funds': json['funds'] ?? [],
      'transactions': json['transactions'] ?? [],
      'recurring': json['recurring'] ?? [],
      'cashflows': json['cashflows'] ?? [],
      'recurringGroups': json['recurringGroups'] ?? [],
      'categories': json['categories'] ?? [],
      'monthlySnapshots': json['monthlySnapshots'] ?? [],
    });
  }
}
