enum AccessMode {
  trialActive,
  subscriptionActive,
  readOnly;

  bool get hasFullAccess => this != AccessMode.readOnly;
  bool get oracleEnabled => this != AccessMode.readOnly;

  String get storageValue {
    switch (this) {
      case AccessMode.trialActive:
        return 'trial_active';
      case AccessMode.subscriptionActive:
        return 'subscription_active';
      case AccessMode.readOnly:
        return 'read_only';
    }
  }

  String get label {
    switch (this) {
      case AccessMode.trialActive:
        return 'Trial attivo';
      case AccessMode.subscriptionActive:
        return 'Abbonamento attivo';
      case AccessMode.readOnly:
        return 'Sola lettura';
    }
  }

  static AccessMode fromStorageValue(String? value) {
    switch (value) {
      case 'subscription_active':
        return AccessMode.subscriptionActive;
      case 'read_only':
        return AccessMode.readOnly;
      case 'trial_active':
      default:
        return AccessMode.trialActive;
    }
  }
}
