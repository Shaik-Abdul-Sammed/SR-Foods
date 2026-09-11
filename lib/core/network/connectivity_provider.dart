import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = NotifierProvider<ConnectivityNotifier, ConnectivityResult>(ConnectivityNotifier.new);

class ConnectivityNotifier extends Notifier<ConnectivityResult> {
  @override
  ConnectivityResult build() {
    _init();
    return ConnectivityResult.none;
  }

  void _init() async {
    final result = await Connectivity().checkConnectivity();
    state = result.contains(ConnectivityResult.none) ? ConnectivityResult.none : result.first;
    
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty) {
        state = results.contains(ConnectivityResult.none) ? ConnectivityResult.none : results.first;
      }
    });
  }

  bool get isOnline => state != ConnectivityResult.none;
}
