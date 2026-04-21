import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_boxes_2/models/access_mode.dart';

class AccessService {
  static const String _debugOverrideKey = 'debug_access_mode_override';

  static Future<AccessMode?> loadDebugOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_debugOverrideKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return AccessMode.fromStorageValue(raw);
  }

  static Future<void> saveDebugOverride(AccessMode? mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_debugOverrideKey);
      return;
    }
    await prefs.setString(_debugOverrideKey, mode.storageValue);
  }
}
