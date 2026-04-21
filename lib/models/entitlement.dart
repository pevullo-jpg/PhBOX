import 'package:family_boxes_2/models/access_mode.dart';

class Entitlement {
  final String uid;
  final String accessSource;
  final DateTime? trialStartAt;
  final DateTime? trialEndAt;
  final DateTime? subscriptionStartAt;
  final DateTime? subscriptionEndAt;
  final bool isAutoRenewing;
  final String? productId;
  final String? basePlanId;
  final String? offerId;
  final String? purchaseToken;
  final DateTime? lastVerifiedAt;
  final DateTime updatedAt;

  const Entitlement({
    required this.uid,
    required this.accessSource,
    required this.updatedAt,
    this.trialStartAt,
    this.trialEndAt,
    this.subscriptionStartAt,
    this.subscriptionEndAt,
    this.isAutoRenewing = false,
    this.productId,
    this.basePlanId,
    this.offerId,
    this.purchaseToken,
    this.lastVerifiedAt,
  });

  factory Entitlement.startTrial({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return Entitlement(
      uid: uid,
      accessSource: 'local_trial',
      trialStartAt: startAt,
      trialEndAt: endAt,
      updatedAt: startAt,
      lastVerifiedAt: startAt,
    );
  }

  bool trialActiveAt(DateTime now) {
    return trialEndAt != null && !now.isAfter(trialEndAt!);
  }

  bool subscriptionActiveAt(DateTime now) {
    return subscriptionEndAt != null && !now.isAfter(subscriptionEndAt!);
  }

  AccessMode accessModeAt(DateTime now, {AccessMode? debugOverride}) {
    if (debugOverride != null) {
      return debugOverride;
    }
    if (subscriptionActiveAt(now)) {
      return AccessMode.subscriptionActive;
    }
    if (trialActiveAt(now)) {
      return AccessMode.trialActive;
    }
    return AccessMode.readOnly;
  }

  String get phaseLabel {
    final now = DateTime.now();
    if (subscriptionActiveAt(now)) return 'Abbonamento attivo';
    if (trialActiveAt(now)) return 'Trial attivo';
    return 'Sola lettura';
  }

  DateTime? get activeUntil {
    final now = DateTime.now();
    if (subscriptionActiveAt(now)) return subscriptionEndAt;
    if (trialActiveAt(now)) return trialEndAt;
    return subscriptionEndAt ?? trialEndAt;
  }

  int? remainingDaysAt(DateTime now) {
    final target = accessModeAt(now) == AccessMode.subscriptionActive ? subscriptionEndAt : trialEndAt;
    if (target == null) return null;
    return target.difference(now).inDays;
  }

  Entitlement copyWith({
    String? uid,
    String? accessSource,
    DateTime? trialStartAt,
    DateTime? trialEndAt,
    bool clearTrialStartAt = false,
    bool clearTrialEndAt = false,
    DateTime? subscriptionStartAt,
    DateTime? subscriptionEndAt,
    bool clearSubscriptionStartAt = false,
    bool clearSubscriptionEndAt = false,
    bool? isAutoRenewing,
    String? productId,
    String? basePlanId,
    String? offerId,
    String? purchaseToken,
    bool clearProductId = false,
    bool clearBasePlanId = false,
    bool clearOfferId = false,
    bool clearPurchaseToken = false,
    DateTime? lastVerifiedAt,
    bool clearLastVerifiedAt = false,
    DateTime? updatedAt,
  }) {
    return Entitlement(
      uid: uid ?? this.uid,
      accessSource: accessSource ?? this.accessSource,
      trialStartAt: clearTrialStartAt ? null : (trialStartAt ?? this.trialStartAt),
      trialEndAt: clearTrialEndAt ? null : (trialEndAt ?? this.trialEndAt),
      subscriptionStartAt: clearSubscriptionStartAt ? null : (subscriptionStartAt ?? this.subscriptionStartAt),
      subscriptionEndAt: clearSubscriptionEndAt ? null : (subscriptionEndAt ?? this.subscriptionEndAt),
      isAutoRenewing: isAutoRenewing ?? this.isAutoRenewing,
      productId: clearProductId ? null : (productId ?? this.productId),
      basePlanId: clearBasePlanId ? null : (basePlanId ?? this.basePlanId),
      offerId: clearOfferId ? null : (offerId ?? this.offerId),
      purchaseToken: clearPurchaseToken ? null : (purchaseToken ?? this.purchaseToken),
      lastVerifiedAt: clearLastVerifiedAt ? null : (lastVerifiedAt ?? this.lastVerifiedAt),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'accessSource': accessSource,
      'trialStartAt': trialStartAt?.toIso8601String(),
      'trialEndAt': trialEndAt?.toIso8601String(),
      'subscriptionStartAt': subscriptionStartAt?.toIso8601String(),
      'subscriptionEndAt': subscriptionEndAt?.toIso8601String(),
      'isAutoRenewing': isAutoRenewing,
      'productId': productId,
      'basePlanId': basePlanId,
      'offerId': offerId,
      'purchaseToken': purchaseToken,
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      uid: (json['uid'] ?? '').toString(),
      accessSource: (json['accessSource'] ?? 'local_trial').toString(),
      trialStartAt: DateTime.tryParse((json['trialStartAt'] ?? '').toString()),
      trialEndAt: DateTime.tryParse((json['trialEndAt'] ?? '').toString()),
      subscriptionStartAt: DateTime.tryParse((json['subscriptionStartAt'] ?? '').toString()),
      subscriptionEndAt: DateTime.tryParse((json['subscriptionEndAt'] ?? '').toString()),
      isAutoRenewing: json['isAutoRenewing'] == true,
      productId: (json['productId'] ?? '').toString().trim().isEmpty ? null : (json['productId'] ?? '').toString(),
      basePlanId: (json['basePlanId'] ?? '').toString().trim().isEmpty ? null : (json['basePlanId'] ?? '').toString(),
      offerId: (json['offerId'] ?? '').toString().trim().isEmpty ? null : (json['offerId'] ?? '').toString(),
      purchaseToken: (json['purchaseToken'] ?? '').toString().trim().isEmpty ? null : (json['purchaseToken'] ?? '').toString(),
      lastVerifiedAt: DateTime.tryParse((json['lastVerifiedAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
