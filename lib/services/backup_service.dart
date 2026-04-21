import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_boxes_2/models/app_data.dart';
import 'package:family_boxes_2/models/backup_settings.dart';

class BackupService {
  static const String _enabledKey = 'auto_backup_enabled';
  static const String _frequencyKey = 'auto_backup_frequency';
  static const String _folderPathKey = 'auto_backup_folder_path';
  static const String _lastRunKey = 'auto_backup_last_run';
  static const String _keepLastKey = 'auto_backup_keep_last';

  static Future<BackupSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return BackupSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      frequency: prefs.getString(_frequencyKey) ?? 'weekly',
      folderPath: prefs.getString(_folderPathKey) ?? '',
      lastRunIso: prefs.getString(_lastRunKey),
      keepLast: prefs.getInt(_keepLastKey) ?? 10,
    );
  }

  static Future<void> saveSettings(BackupSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setString(_frequencyKey, settings.frequency);
    await prefs.setString(_folderPathKey, settings.folderPath);
    await prefs.setInt(_keepLastKey, settings.keepLast);

    if (settings.lastRunIso == null || settings.lastRunIso!.isEmpty) {
      await prefs.remove(_lastRunKey);
    } else {
      await prefs.setString(_lastRunKey, settings.lastRunIso!);
    }
  }

  static Future<void> markRunNow() async {
    final settings = await loadSettings();
    await saveSettings(
      settings.copyWith(lastRunIso: DateTime.now().toIso8601String()),
    );
  }

  static bool shouldRunNow(BackupSettings settings, DateTime now) {
    if (!settings.enabled) return false;
    if (settings.folderPath.trim().isEmpty) return false;

    final lastRun = settings.lastRun;
    if (lastRun == null) return true;

    final nowDay = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastRun.year, lastRun.month, lastRun.day);

    switch (settings.frequency) {
      case 'daily':
        return nowDay.isAfter(lastDay);

      case 'weekly':
        return nowDay.difference(lastDay).inDays >= 7;

      case 'monthly':
        return now.year != lastRun.year || now.month != lastRun.month;

      default:
        return false;
    }
  }

  static Future<File?> createBackupInFolder({
    required AppData data,
    required String folderPath,
    int keepLast = 10,
    String prefix = 'family_boxes_backup',
  }) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final file = File('${dir.path}/$prefix$timestamp.json');
      final raw = const JsonEncoder.withIndent('  ').convert(data.toJson());
      await file.writeAsString(raw, flush: true);

      await _cleanupOldBackups(
        dir: dir,
        prefix: prefix,
        keepLast: keepLast,
      );

      return file;
    } catch (e, st) {
      debugPrint('BackupService.createBackupInFolder error: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<File?> runAutoBackupIfDue(AppData data) async {
    try {
      final settings = await loadSettings();
      if (!shouldRunNow(settings, DateTime.now())) {
        return null;
      }

      final file = await createBackupInFolder(
        data: data,
        folderPath: settings.folderPath,
        keepLast: settings.keepLast,
      );

      if (file != null) {
        await saveSettings(
          settings.copyWith(lastRunIso: DateTime.now().toIso8601String()),
        );
      }

      return file;
    } catch (e, st) {
      debugPrint('BackupService.runAutoBackupIfDue error: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<void> _cleanupOldBackups({
    required Directory dir,
    required String prefix,
    required int keepLast,
  }) async {
    if (keepLast <= 0) return;

    final entities = await dir.list().toList();

    final files = entities.whereType<File>().where((f) {
      final name = f.uri.pathSegments.isNotEmpty
          ? f.uri.pathSegments.last
          : f.path.split(Platform.pathSeparator).last;
      return name.startsWith(prefix) && name.endsWith('.json');
    }).toList();

    files.sort((a, b) => b.path.compareTo(a.path));

    if (files.length <= keepLast) return;

    for (final file in files.skip(keepLast)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
