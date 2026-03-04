import 'package:bingwa_pro/core/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
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
    extends ConsumerState<BiometricProtectedWidget> with WidgetsBindingObserver {
  bool _isAuthenticating = true;
  bool _biometricSuccess = false;
  // Keep these fields for future use
  final bool _isDeviceSupported = false;
  final bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  
  final LocalAuthentication _auth = LocalAuthentication();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricAvailability();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-authenticate when app returns from background
    if (state == AppLifecycleState.resumed && !_biometricSuccess) {
      _checkBiometricAvailability();
    }
  }
  
  Future<void> _checkBiometricAvailability() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final availableBiometrics = await _auth.getAvailableBiometrics();
      
      setState(() {
        _availableBiometrics = availableBiometrics;
      });
      
      // Check if biometric is enabled in settings
      final biometricEnabled = await SecureStorageManager.getBiometricEnabled(false);
      
      if (!biometricEnabled || !isDeviceSupported || !canCheckBiometrics || availableBiometrics.isEmpty) {
        // Fallback - allow access without biometric if not enabled or not available
        setState(() {
          _isAuthenticating = false;
          _biometricSuccess = true;
        });
        return;
      }
      
      // Start biometric authentication
      _authenticateWithBiometrics();
      
    } catch (e) {
      AppLogger.e('Biometric availability check failed:', e);
      setState(() {
        _isAuthenticating = false;
        _biometricSuccess = true; // Fallback to allow access
      });
    }
  }
  
  Future<void> _authenticateWithBiometrics() async {
    try {
      setState(() {
        _isAuthenticating = true;
      });
      
      // Use only the required parameters - remove stickyAuth if not available
      final authenticated = await _auth.authenticate(
        localizedReason: widget.biometricReason,
        biometricOnly: true, // Keep only this if stickyAuth isn't available
      );
      
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _biometricSuccess = authenticated;
        });
        
        if (authenticated) {
          AppLogger.logSecurityEvent(
            event: 'Biometric authentication successful',
          );
        } else {
          AppLogger.logSecurityEvent(
            event: 'Biometric authentication failed - user cancelled',
          );
        }
      }
    } catch (e) {
      AppLogger.e('Biometric authentication failed:', e);
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _biometricSuccess = false;
        });
      }
    }
  }
  
  Future<void> _retryAuthentication() async {
    final biometricEnabled = await SecureStorageManager.getBiometricEnabled(false);
    
    if (!biometricEnabled) {
      // If user disabled biometric, allow access
      setState(() {
        _biometricSuccess = true;
      });
      return;
    }
    
    _authenticateWithBiometrics();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return widget.loadingWidget ?? Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Authenticating with biometrics...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }
    
    if (!_biometricSuccess) {
      return widget.failedWidget ?? _buildBiometricFailedWidget();
    }
    
    return widget.child;
  }
  
  Widget _buildBiometricFailedWidget() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon based on available biometrics
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _getBiometricIcon(),
                  size: 50,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Biometric Authentication Failed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'Please try again or use your PIN to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // Available biometrics info
              if (_availableBiometrics.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Available on this device:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _availableBiometrics.map((bio) {
                          return Chip(
                            label: Text(_getBiometricName(bio)),
                            avatar: Icon(
                              _getBiometricIconForType(bio),
                              size: 16,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryAuthentication,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to PIN entry
                      Navigator.pushNamed(context, '/pin-entry');
                    },
                    icon: const Icon(Icons.pin),
                    label: const Text('Use PIN'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C853),
                      side: const BorderSide(color: Color(0xFF00C853)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Option to disable biometric
              TextButton(
                onPressed: () async {
                  await SecureStorageManager.setBiometricEnabled(false);
                  if (mounted) {
                    setState(() {
                      _biometricSuccess = true;
                    });
                  }
                },
                child: const Text(
                  'Disable biometric and continue',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else {
      return Icons.security;
    }
  }
  
  IconData _getBiometricIconForType(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.weak:
      case BiometricType.strong:
        return Icons.fingerprint;
      default:
        return Icons.security;
    }
  }
  
  String _getBiometricName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.weak:
        return 'Weak Biometric';
      case BiometricType.strong:
        return 'Strong Biometric';
      default:
        return 'Biometric';
    }
  }
}