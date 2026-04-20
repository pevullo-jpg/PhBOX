import 'dart:async';

import 'package:flutter/material.dart';

mixin PageAutoRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;
  _PageAutoRefreshBindingObserver? _pageAutoRefreshObserver;

  @protected
  Duration get autoRefreshInterval => const Duration(seconds: 30);

  @protected
  bool get shouldAutoRefresh => true;

  @protected
  void onAutoRefreshTick();

  @protected
  void startPageAutoRefresh() {
    _pageAutoRefreshObserver ??= _PageAutoRefreshBindingObserver(
      onResumed: () {
        if (!mounted || !shouldAutoRefresh) {
          return;
        }
        onAutoRefreshTick();
      },
    );
    WidgetsBinding.instance.removeObserver(_pageAutoRefreshObserver!);
    WidgetsBinding.instance.addObserver(_pageAutoRefreshObserver!);
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) {
      if (!mounted || !shouldAutoRefresh) {
        return;
      }
      onAutoRefreshTick();
    });
  }

  @override
  void dispose() {
    final _PageAutoRefreshBindingObserver? observer = _pageAutoRefreshObserver;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _pageAutoRefreshObserver = null;
    }
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    super.dispose();
  }
}

class _PageAutoRefreshBindingObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;

  const _PageAutoRefreshBindingObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
