import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:family_boxes_2/config/billing_config.dart';
import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/services/entitlement_service.dart';

class BillingState {
  final bool loading;
  final bool storeAvailable;
  final bool purchasePending;
  final ProductDetails? annualProduct;
  final List<String> notFoundIds;
  final String? message;
  final String? error;
  final DateTime? lastSyncAt;

  const BillingState({
    this.loading = false,
    this.storeAvailable = false,
    this.purchasePending = false,
    this.annualProduct,
    this.notFoundIds = const <String>[],
    this.message,
    this.error,
    this.lastSyncAt,
  });

  bool get isReady => storeAvailable && annualProduct != null && error == null;
  bool get productConfigured => BillingConfig.isConfigured;
  bool get productFound => annualProduct != null;

  BillingState copyWith({
    bool? loading,
    bool? storeAvailable,
    bool? purchasePending,
    ProductDetails? annualProduct,
    bool clearAnnualProduct = false,
    List<String>? notFoundIds,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
    DateTime? lastSyncAt,
  }) {
    return BillingState(
      loading: loading ?? this.loading,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      purchasePending: purchasePending ?? this.purchasePending,
      annualProduct: clearAnnualProduct ? null : (annualProduct ?? this.annualProduct),
      notFoundIds: notFoundIds ?? this.notFoundIds,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final ValueNotifier<BillingState> _state = ValueNotifier(const BillingState());

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  AuthUser? _currentUser;
  Future<void> Function()? _onEntitlementChanged;
  bool _initialized = false;

  ValueListenable<BillingState> get stateListenable => _state;
  BillingState get state => _state.value;

  Future<void> bindUser(
    AuthUser user, {
    Future<void> Function()? onEntitlementChanged,
  }) async {
    _currentUser = user;
    _onEntitlementChanged = onEntitlementChanged ?? _onEntitlementChanged;

    if (!_initialized) {
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (Object error, StackTrace stackTrace) {
          _state.value = _state.value.copyWith(
            purchasePending: false,
            error: 'Errore stream acquisti: $error',
            lastSyncAt: DateTime.now(),
          );
        },
      );
      _initialized = true;
    }

    await refreshCatalog();
  }

  Future<void> unbindUser() async {
    _currentUser = null;
    _onEntitlementChanged = null;
    _state.value = const BillingState();
  }

  Future<void> refreshCatalog() async {
    if (!BillingConfig.isConfigured) {
      _state.value = const BillingState(
        loading: false,
        storeAvailable: false,
        message: 'Configura productId Play Billing in lib/config/billing_config.dart',
      );
      return;
    }

    _state.value = _state.value.copyWith(
      loading: true,
      clearError: true,
      clearMessage: true,
      clearAnnualProduct: false,
    );

    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        _state.value = _state.value.copyWith(
          loading: false,
          storeAvailable: false,
          clearAnnualProduct: true,
          notFoundIds: const <String>[],
          message: 'Store Play non disponibile su questo dispositivo o build.',
          lastSyncAt: DateTime.now(),
        );
        return;
      }

      final response = await _inAppPurchase.queryProductDetails(
        {BillingConfig.annualSubscriptionProductId},
      );

      if (response.error != null) {
        _state.value = _state.value.copyWith(
          loading: false,
          storeAvailable: true,
          clearAnnualProduct: true,
          notFoundIds: response.notFoundIDs,
          error: response.error!.message,
          lastSyncAt: DateTime.now(),
        );
        return;
      }

      final annualProduct = response.productDetails
          .where((product) => product.id == BillingConfig.annualSubscriptionProductId)
          .cast<ProductDetails?>()
          .firstWhere((product) => product != null, orElse: () => null);

      _state.value = _state.value.copyWith(
        loading: false,
        storeAvailable: true,
        annualProduct: annualProduct,
        notFoundIds: response.notFoundIDs,
        message: annualProduct == null
            ? 'Prodotto Play non trovato. Controlla ID prodotto, track di test e account tester.'
            : 'Catalogo Play aggiornato.',
        clearError: true,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      _state.value = _state.value.copyWith(
        loading: false,
        storeAvailable: false,
        clearAnnualProduct: true,
        error: 'Catalogo Play non leggibile: $e',
        lastSyncAt: DateTime.now(),
      );
    }
  }

  Future<void> buyAnnualSubscription() async {
    final user = _currentUser;
    final product = _state.value.annualProduct;
    if (user == null) {
      _state.value = _state.value.copyWith(
        error: 'Account non associato al BillingService.',
        lastSyncAt: DateTime.now(),
      );
      return;
    }
    if (product == null) {
      _state.value = _state.value.copyWith(
        error: 'Prodotto Play non disponibile.',
        lastSyncAt: DateTime.now(),
      );
      return;
    }

    _state.value = _state.value.copyWith(
      purchasePending: true,
      clearError: true,
      message: 'Apertura flusso di acquisto Play…',
      lastSyncAt: DateTime.now(),
    );

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _state.value = _state.value.copyWith(
        purchasePending: false,
        error: 'Acquisto non avviato: $e',
        lastSyncAt: DateTime.now(),
      );
    }
  }

  Future<void> restorePurchases() async {
    _state.value = _state.value.copyWith(
      purchasePending: true,
      clearError: true,
      message: 'Ripristino acquisti in corso…',
      lastSyncAt: DateTime.now(),
    );

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _state.value = _state.value.copyWith(
        purchasePending: false,
        error: 'Ripristino non riuscito: $e',
        lastSyncAt: DateTime.now(),
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _state.value = _state.value.copyWith(
            purchasePending: true,
            clearError: true,
            message: 'Acquisto in attesa di conferma Play…',
            lastSyncAt: DateTime.now(),
          );
          break;
        case PurchaseStatus.error:
          _state.value = _state.value.copyWith(
            purchasePending: false,
            error: purchase.error?.message ?? 'Errore Play Billing.',
            lastSyncAt: DateTime.now(),
          );
          break;
        case PurchaseStatus.canceled:
          _state.value = _state.value.copyWith(
            purchasePending: false,
            message: 'Acquisto annullato.',
            clearError: true,
            lastSyncAt: DateTime.now(),
          );
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.restored:
        case PurchaseStatus.purchased:
          await _deliverSubscription(purchase);
          break;
      }
    }
  }

  Future<void> _deliverSubscription(PurchaseDetails purchase) async {
    final user = _currentUser;
    if (user == null) {
      _state.value = _state.value.copyWith(
        purchasePending: false,
        error: 'Acquisto ricevuto ma nessun account è associato alla sessione.',
        lastSyncAt: DateTime.now(),
      );
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
      return;
    }

    if (purchase.productID != BillingConfig.annualSubscriptionProductId) {
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData.trim();
    if (purchaseToken.isEmpty) {
      _state.value = _state.value.copyWith(
        purchasePending: false,
        error: 'Token acquisto Play mancante.',
        lastSyncAt: DateTime.now(),
      );
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
      return;
    }

    await EntitlementService.applyPlaySubscriptionPurchase(
      user,
      productId: purchase.productID,
      purchaseToken: purchaseToken,
      basePlanId: BillingConfig.annualBasePlanId,
      offerId: BillingConfig.introductoryOfferId,
      restored: purchase.status == PurchaseStatus.restored,
    );

    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }

    _state.value = _state.value.copyWith(
      purchasePending: false,
      clearError: true,
      message: purchase.status == PurchaseStatus.restored
          ? 'Acquisto ripristinato. Stato accesso in aggiornamento.'
          : 'Acquisto registrato. Stato accesso in aggiornamento.',
      lastSyncAt: DateTime.now(),
    );

    if (_onEntitlementChanged != null) {
      await _onEntitlementChanged!.call();
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
    _currentUser = null;
    _onEntitlementChanged = null;
    _state.value = const BillingState();
  }
}
