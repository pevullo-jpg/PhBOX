import 'dart:async';

import 'package:flutter/material.dart';

mixin PageAutoRefreshMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  @protected
  Duration get autoRefreshInterval => const Duration(seconds: 30);

  @protected
  bool get shouldAutoRefresh => true;

  @protected
  void onAutoRefreshTick();

  @protected
  void startPageAutoRefresh() {
    WidgetsBinding.instance.addObserver(this);
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) {
      if (!mounted || !shouldAutoRefresh) {
        return;
      }
      onAutoRefreshTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted && shouldAutoRefresh) {
      onAutoRefreshTick();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
