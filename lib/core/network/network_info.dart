import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkInfo {
  final Connectivity _connectivity;
  
  NetworkInfo(this._connectivity);
  
  Future<bool> get isConnected async {
    final connectivityResult = await _connectivity.checkConnectivity();
    
    // In newer versions, connectivityResult is always a List
    // We need to check if any connection type is available
    return connectivityResult.isNotEmpty && 
           !connectivityResult.contains(ConnectivityResult.none);
    }
  
  Future<List<ConnectivityResult>> get connectivityStatus async {
    final result = await _connectivity.checkConnectivity();
    
    // In newer versions, result is already a List
    return result;
    }
  
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo(Connectivity());
});