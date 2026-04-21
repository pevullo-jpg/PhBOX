import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_boxes_2/config/firebase_backend_config.dart';
import 'package:family_boxes_2/models/access_mode.dart';
import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/models/entitlement.dart';
import 'package:family_boxes_2/services/auth_service.dart';

class EntitlementService {
  static const String _cachePrefix = 'entitlement_cache_v2_';

  static Future<Entitlement> loadOrCreateForUser(AuthUser user) async {
    return refreshForUser(user);
  }

  static Future<Entitlement> refreshForUser(AuthUser user) async {
    if (!FirebaseBackendConfig.isConfigured) {
      return _loadCachedOrReadOnly(user);
    }

    try {
      final idToken = await AuthService.currentIdToken();
      if (idToken == null || idToken.isEmpty) {
        return _loadCachedOrReadOnly(user);
      }

      await _upsertUserProfile(user, idToken);
      final remote = await _fetchRemoteEntitlement(user, idToken);
      if (remote != null) {
        await _cacheEntitlement(user, remote);
        return remote;
      }

      final created = Entitlement.startTrial(
        uid: user.uid,
        startAt: DateTime.now(),
        endAt: _addMonths(DateTime.now(), 3),
      ).copyWith(
        accessSource: 'firebase_trial',
        updatedAt: DateTime.now(),
        lastVerifiedAt: DateTime.now(),
      );
      await saveForUser(user, created);
      return created;
    } catch (_) {
      return _loadCachedOrReadOnly(user);
    }
  }

  static Future<void> saveForUser(AuthUser user, Entitlement entitlement) async {
    await _cacheEntitlement(user, entitlement);

    if (!FirebaseBackendConfig.isConfigured) return;
    final idToken = await AuthService.currentIdToken();
    if (idToken == null || idToken.isEmpty) return;

    final uri = _documentUri('entitlements', user.uid);
    final body = jsonEncode({
      'fields': _entitlementToFirestoreFields(entitlement),
    });

    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode >= 400) {
      throw Exception('Entitlement remote save failed: ${response.body}');
    }
  }


  static Future<Entitlement> applyPlaySubscriptionPurchase(
    AuthUser user, {
    required String productId,
    required String purchaseToken,
    String? basePlanId,
    String? offerId,
    bool restored = false,
  }) async {
    final now = DateTime.now();
    final current = await refreshForUser(user);
    final updated = current.copyWith(
      accessSource: restored
          ? 'play_restore_pending_server'
          : 'play_subscription_pending_server',
      subscriptionStartAt: now,
      subscriptionEndAt: _addMonths(now, 12),
      isAutoRenewing: true,
      productId: productId,
      basePlanId: basePlanId,
      offerId: offerId,
      purchaseToken: purchaseToken,
      updatedAt: now,
      lastVerifiedAt: now,
    );
    await saveForUser(user, updated);
    return updated;
  }

  static Future<AccessMode> resolveAccessMode(
    AuthUser user, {
    AccessMode? debugOverride,
  }) async {
    final entitlement = await refreshForUser(user);
    return entitlement.accessModeAt(DateTime.now(), debugOverride: debugOverride);
  }

  static Future<Entitlement> activateDebugSubscription(AuthUser user) async {
    final now = DateTime.now();
    final updated = (await refreshForUser(user)).copyWith(
      accessSource: 'debug_subscription',
      subscriptionStartAt: now,
      subscriptionEndAt: _addMonths(now, 12),
      isAutoRenewing: true,
      updatedAt: now,
      lastVerifiedAt: now,
    );
    await saveForUser(user, updated);
    return updated;
  }

  static Future<Entitlement> resetTrialFromNow(AuthUser user) async {
    final now = DateTime.now();
    final updated = (await refreshForUser(user)).copyWith(
      accessSource: 'debug_trial_reset',
      trialStartAt: now,
      trialEndAt: _addMonths(now, 3),
      clearSubscriptionStartAt: true,
      clearSubscriptionEndAt: true,
      isAutoRenewing: false,
      clearProductId: true,
      clearBasePlanId: true,
      clearOfferId: true,
      clearPurchaseToken: true,
      updatedAt: now,
      lastVerifiedAt: now,
    );
    await saveForUser(user, updated);
    return updated;
  }

  static Future<Entitlement> forceReadOnlyNow(AuthUser user) async {
    final now = DateTime.now();
    final updated = (await refreshForUser(user)).copyWith(
      accessSource: 'debug_read_only',
      trialEndAt: now.subtract(const Duration(minutes: 1)),
      subscriptionEndAt: now.subtract(const Duration(minutes: 1)),
      clearProductId: true,
      clearBasePlanId: true,
      clearOfferId: true,
      clearPurchaseToken: true,
      updatedAt: now,
      lastVerifiedAt: now,
    );
    await saveForUser(user, updated);
    return updated;
  }

  static Future<Entitlement?> _fetchRemoteEntitlement(AuthUser user, String idToken) async {
    final uri = _documentUri('entitlements', user.uid);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode >= 400) {
      throw Exception('Entitlement remote fetch failed: ${response.body}');
    }

    final decoded = _decodeJson(response.body);
    final fields = decoded['fields'];
    if (fields is! Map) return null;
    return _entitlementFromFirestoreFields(user.uid, Map<String, dynamic>.from(fields));
  }

  static Future<void> _upsertUserProfile(AuthUser user, String idToken) async {
    final uri = _documentUri('users', user.uid);
    final now = DateTime.now();
    final body = jsonEncode({
      'fields': {
        'uid': {'stringValue': user.uid},
        'email': {'stringValue': user.email},
        'displayName': {'stringValue': user.displayName},
        'createdAt': {'timestampValue': user.createdAt.toUtc().toIso8601String()},
        'lastLoginAt': {'timestampValue': (user.lastLoginAt ?? now).toUtc().toIso8601String()},
        'updatedAt': {'timestampValue': now.toUtc().toIso8601String()},
      }
    });

    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode >= 400) {
      throw Exception('User profile save failed: ${response.body}');
    }
  }

  static Future<Entitlement> _loadCachedOrReadOnly(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachePrefix${user.uid}');
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return Entitlement.fromJson(decoded);
        }
        if (decoded is Map) {
          return Entitlement.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return Entitlement(
      uid: user.uid,
      accessSource: 'unverified_read_only',
      updatedAt: DateTime.now(),
      lastVerifiedAt: null,
    );
  }

  static Future<void> _cacheEntitlement(AuthUser user, Entitlement entitlement) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix${user.uid}', jsonEncode(entitlement.toJson()));
  }

  static Uri _documentUri(String collection, String documentId) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${FirebaseBackendConfig.projectId}/databases/(default)/documents/$collection/$documentId',
    );
  }

  static Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _entitlementToFirestoreFields(Entitlement entitlement) {
    final fields = <String, dynamic>{
      'uid': {'stringValue': entitlement.uid},
      'accessSource': {'stringValue': entitlement.accessSource},
      'isAutoRenewing': {'booleanValue': entitlement.isAutoRenewing},
      'updatedAt': {'timestampValue': entitlement.updatedAt.toUtc().toIso8601String()},
    };

    void setString(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        fields[key] = {'stringValue': value};
      }
    }

    void setTimestamp(String key, DateTime? value) {
      if (value != null) {
        fields[key] = {'timestampValue': value.toUtc().toIso8601String()};
      }
    }

    setString('productId', entitlement.productId);
    setString('basePlanId', entitlement.basePlanId);
    setString('offerId', entitlement.offerId);
    setString('purchaseToken', entitlement.purchaseToken);

    setTimestamp('trialStartAt', entitlement.trialStartAt);
    setTimestamp('trialEndAt', entitlement.trialEndAt);
    setTimestamp('subscriptionStartAt', entitlement.subscriptionStartAt);
    setTimestamp('subscriptionEndAt', entitlement.subscriptionEndAt);
    setTimestamp('lastVerifiedAt', entitlement.lastVerifiedAt);
    return fields;
  }

  static Entitlement _entitlementFromFirestoreFields(String uid, Map<String, dynamic> fields) {
    DateTime? timestampOf(String key) {
      final raw = fields[key];
      if (raw is Map && raw['timestampValue'] != null) {
        return DateTime.tryParse(raw['timestampValue'].toString())?.toLocal();
      }
      return null;
    }

    String stringOf(String key, String fallback) {
      final raw = fields[key];
      if (raw is Map && raw['stringValue'] != null) {
        return raw['stringValue'].toString();
      }
      return fallback;
    }

    bool boolOf(String key) {
      final raw = fields[key];
      if (raw is Map && raw['booleanValue'] != null) {
        return raw['booleanValue'] == true;
      }
      return false;
    }

    return Entitlement(
      uid: stringOf('uid', uid),
      accessSource: stringOf('accessSource', 'firebase_trial'),
      trialStartAt: timestampOf('trialStartAt'),
      trialEndAt: timestampOf('trialEndAt'),
      subscriptionStartAt: timestampOf('subscriptionStartAt'),
      subscriptionEndAt: timestampOf('subscriptionEndAt'),
      isAutoRenewing: boolOf('isAutoRenewing'),
      productId: stringOf('productId', '').trim().isEmpty ? null : stringOf('productId', ''),
      basePlanId: stringOf('basePlanId', '').trim().isEmpty ? null : stringOf('basePlanId', ''),
      offerId: stringOf('offerId', '').trim().isEmpty ? null : stringOf('offerId', ''),
      purchaseToken: stringOf('purchaseToken', '').trim().isEmpty ? null : stringOf('purchaseToken', ''),
      lastVerifiedAt: timestampOf('lastVerifiedAt'),
      updatedAt: timestampOf('updatedAt') ?? DateTime.now(),
    );
  }

  static DateTime _addMonths(DateTime input, int months) {
    final totalMonths = input.month + months;
    final year = input.year + ((totalMonths - 1) ~/ 12);
    final month = ((totalMonths - 1) % 12) + 1;
    final day = input.day;
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      day > maxDay ? maxDay : day,
      input.hour,
      input.minute,
      input.second,
      input.millisecond,
      input.microsecond,
    );
  }
}
