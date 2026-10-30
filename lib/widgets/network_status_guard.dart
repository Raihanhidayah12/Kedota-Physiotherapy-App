import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../screens/errors/no_internet_screen.dart';
import '../screens/errors/server_down_screen.dart';
import '../services/network_status_service.dart';

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
  AppNetworkStatus _status = AppNetworkStatus.online;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = NetworkStatusService.statusNotifier.value;
    NetworkStatusService.statusNotifier.addListener(_onNotifierChanged);

    _connectivitySubscription = NetworkStatusService.onConnectivityChanged
        .listen((_) => _checkStatus(), onError: (_) => _checkStatus());

    _checkStatus();

    _timer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkStatus(),
    );
  }

  void _onNotifierChanged() {
    final newStatus = NetworkStatusService.statusNotifier.value;
    if (mounted && newStatus != _status) {
      setState(() => _status = newStatus);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<bool> _checkStatus() async {
    if (_isChecking) return _status == AppNetworkStatus.online;
    _isChecking = true;
    try {
      final currentStatus = await NetworkStatusService.checkStatus();
      if (mounted && currentStatus != _status) {
        setState(() => _status = currentStatus);
      }
      return currentStatus == AppNetworkStatus.online;
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    NetworkStatusService.statusNotifier.removeListener(_onNotifierChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_status == AppNetworkStatus.noInternet)
          Positioned.fill(
            child: NoInternetScreen(onRetry: _checkStatus),
          )
        else if (_status == AppNetworkStatus.serverDown)
          Positioned.fill(
            child: ServerDownScreen(onRetry: _checkStatus),
          ),
      ],
    );
  }
}
