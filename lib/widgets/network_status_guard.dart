import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/network_status_service.dart';
import '../screens/errors/no_internet_screen.dart';

class NetworkStatusGuard extends StatefulWidget {
  const NetworkStatusGuard({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkStatusGuard> createState() => _NetworkStatusGuardState();
}

class _NetworkStatusGuardState extends State<NetworkStatusGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternet = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = NetworkStatusService.onConnectivityChanged
        .listen((_) => _checkInternet(), onError: (_) => _checkInternet());
    _checkInternet();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkInternet(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkInternet();
  }

  Future<bool> _checkInternet() async {
    if (_isChecking) return _hasInternet;
    _isChecking = true;
    try {
      final online = await NetworkStatusService.hasInternet();
      if (mounted && online != _hasInternet) {
        setState(() => _hasInternet = online);
      }
      return online;
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_hasInternet)
        Positioned.fill(child: NoInternetScreen(onRetry: _checkInternet)),
    ],
  );
}
