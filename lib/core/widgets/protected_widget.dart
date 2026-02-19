import 'package:bingwa_pro/core/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/secure_storage_manager.dart';
import '../utils/logger.dart';

class ProtectedWidget extends ConsumerStatefulWidget {
  final Widget child;
  final bool requireAuthentication;
  final Widget? loadingWidget;
  final Widget? unauthorizedWidget;
  
  const ProtectedWidget({
    super.key,
    required this.child,
    this.requireAuthentication = true,
    this.loadingWidget,
    this.unauthorizedWidget,
  });
  
  @override
  ConsumerState<ProtectedWidget> createState() => _ProtectedWidgetState();
}

class _ProtectedWidgetState extends ConsumerState<ProtectedWidget> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }
  
  Future<void> _checkAuthentication() async {
    if (!widget.requireAuthentication) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = true;
      });
      return;
    }
    
    try {
      final isLoggedIn = await SecureStorageManager.isLoggedIn();
      final isSessionValid = await SecureStorageManager.isSessionValid();
      
      setState(() {
        _isAuthenticated = isLoggedIn && isSessionValid;
        _isLoading = false;
      });
      
      if (!_isAuthenticated) {
        AppLogger.logSecurityEvent(
          event: 'Access denied - Not authenticated',
        );
      }
    } catch (e) {
      AppLogger.e('Error checking authentication:', e);
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? const LoadingIndicator();
    }
    
    if (!_isAuthenticated && widget.requireAuthentication) {
      return widget.unauthorizedWidget ?? _buildUnauthorizedWidget();
    }
    
    return widget.child;
  }
  
  Widget _buildUnauthorizedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          const Text(
            'Access Denied',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You need to login to access this page',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Navigate to login
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }
}

class BiometricProtectedWidget extends ConsumerStatefulWidget {
  final Widget child;
  final String biometricReason;
  final Widget? loadingWidget;
  final Widget? failedWidget;
  
  const BiometricProtectedWidget({
    super.key,
    required this.child,
    required this.biometricReason,
    this.loadingWidget,
    this.failedWidget,
  });
  
  @override
  ConsumerState<BiometricProtectedWidget> createState() => 
      _BiometricProtectedWidgetState();
}

class _BiometricProtectedWidgetState 
    extends ConsumerState<BiometricProtectedWidget> {
  bool _isAuthenticating = true;
  bool _biometricSuccess = false;
  
  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }
  
  Future<void> _authenticateWithBiometrics() async {
    try {
      // TODO: Implement biometric authentication
      // final isAvailable = await LocalAuthentication().canCheckBiometrics;
      // if (!isAvailable) {
      //   setState(() {
      //     _isAuthenticating = false;
      //     _biometricSuccess = true; // Fallback to normal auth
      //   });
      //   return;
      // }
      
      // final authenticated = await LocalAuthentication().authenticate(
      //   localizedReason: widget.biometricReason,
      // );
      
      // setState(() {
      //   _isAuthenticating = false;
      //   _biometricSuccess = authenticated;
      // });
      
      // For now, simulate success
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isAuthenticating = false;
        _biometricSuccess = true;
      });
      
    } catch (e) {
      AppLogger.e('Biometric authentication failed:', e);
      setState(() {
        _isAuthenticating = false;
        _biometricSuccess = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return widget.loadingWidget ?? const LoadingIndicator();
    }
    
    if (!_biometricSuccess) {
      return widget.failedWidget ?? _buildBiometricFailedWidget();
    }
    
    return widget.child;
  }
  
  Widget _buildBiometricFailedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fingerprint,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 20),
          const Text(
            'Biometric Authentication Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please try again or use your PIN',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _authenticateWithBiometrics,
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  // Navigate to PIN entry
                  Navigator.pushNamed(context, '/pin-entry');
                },
                child: const Text('Use PIN'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}