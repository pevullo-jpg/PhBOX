class BillingConfig {
  /// ID prodotto subscription configurato in Play Console.
  /// Conviene mantenerlo stabile anche in futuro.
  static const String annualSubscriptionProductId = 'family_box_premium_annual';

  /// Metadata utile per docs e futuri agganci backend.
  static const String annualBasePlanId = 'annual';
  static const String introductoryOfferId = 'trial_3m';

  static const String trialLabel = '3 mesi gratuiti';
  static const String renewalLabel = 'Poi rinnovo annuale automatico';

  static bool get isConfigured => annualSubscriptionProductId.trim().isNotEmpty;
}
