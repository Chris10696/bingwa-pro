import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/logger.dart';
import '../providers/auth_provider.dart';

// Custom Biometric Types for UI display
enum CustomBiometricType {
  fingerprint,
  face,
  iris,
  unknown,
}

extension CustomBiometricTypeExtension on CustomBiometricType {
  String get displayName {
    switch (this) {
      case CustomBiometricType.fingerprint:
        return 'Fingerprint';
      case CustomBiometricType.face:
        return 'Face ID';
      case CustomBiometricType.iris:
        return 'Iris Scan';
      default:
        return 'Biometric';
    }
  }
  
  IconData get icon {
    switch (this) {
      case CustomBiometricType.fingerprint:
        return Icons.fingerprint;
      case CustomBiometricType.face:
        return Icons.face;
      case CustomBiometricType.iris:
        return Icons.remove_red_eye;
      default:
        return Icons.security;
    }
  }
}

// Helper function to map local_auth BiometricType to CustomBiometricType
CustomBiometricType _mapToCustomBiometricType(BiometricType bioType) {
  switch (bioType) {
    case BiometricType.fingerprint:
      return CustomBiometricType.fingerprint;
    case BiometricType.face:
      return CustomBiometricType.face;
    case BiometricType.weak:
      return CustomBiometricType.fingerprint; // Map weak biometric to fingerprint
    case BiometricType.strong:
      return CustomBiometricType.fingerprint; // Map strong biometric to fingerprint
    default:
      return CustomBiometricType.unknown;
  }
}

// State
class BiometricSetupState {
  final bool isLoading;
  final bool isAvailable;
  final bool isEnrolled;
  final bool setupComplete;
  final String? errorMessage;
  final List<CustomBiometricType> availableBiometrics;
  final CustomBiometricType? selectedBiometric;
  final bool canAuthenticate;
  final String? publicKey;
  
  const BiometricSetupState({
    this.isLoading = false,
    this.isAvailable = false,
    this.isEnrolled = false,
    this.setupComplete = false,
    this.errorMessage,
    this.availableBiometrics = const [],
    this.selectedBiometric,
    this.canAuthenticate = false,
    this.publicKey,
  });
  
  BiometricSetupState copyWith({
    bool? isLoading,
    bool? isAvailable,
    bool? isEnrolled,
    bool? setupComplete,
    String? errorMessage,
    List<CustomBiometricType>? availableBiometrics,
    CustomBiometricType? selectedBiometric,
    bool? canAuthenticate,
    String? publicKey,
  }) {
    return BiometricSetupState(
      isLoading: isLoading ?? this.isLoading,
      isAvailable: isAvailable ?? this.isAvailable,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      setupComplete: setupComplete ?? this.setupComplete,
      errorMessage: errorMessage ?? this.errorMessage,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      selectedBiometric: selectedBiometric ?? this.selectedBiometric,
      canAuthenticate: canAuthenticate ?? this.canAuthenticate,
      publicKey: publicKey ?? this.publicKey,
    );
  }
}

// Notifier
class BiometricSetupNotifier extends StateNotifier<BiometricSetupState> {
  final LocalAuthentication _localAuth;
  final Ref _ref;
  
  BiometricSetupNotifier(this._localAuth, this._ref) : super(const BiometricSetupState()) {
    _checkBiometrics();
  }
  
  Future<void> _checkBiometrics() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Check if biometrics are available
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheck || !isDeviceSupported) {
        state = state.copyWith(
          isLoading: false,
          isAvailable: false,
          errorMessage: 'Biometric authentication is not available on this device.',
        );
        return;
      }
      
      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      // Convert to our custom enum using the helper function
      final biometricTypes = availableBiometrics
          .map(_mapToCustomBiometricType)
          .where((type) => type != CustomBiometricType.unknown)
          .toList();
      
      // Check if any biometrics are enrolled
      final hasEnrolled = availableBiometrics.isNotEmpty;
      
      state = state.copyWith(
        isLoading: false,
        isAvailable: true,
        isEnrolled: hasEnrolled,
        availableBiometrics: biometricTypes,
        selectedBiometric: biometricTypes.isNotEmpty ? biometricTypes.first : null,
        canAuthenticate: hasEnrolled,
      );
      
    } catch (e) {
      AppLogger.e('Biometric check failed:', e);
      state = state.copyWith(
        isLoading: false,
        isAvailable: false,
        errorMessage: 'Failed to check biometric availability: ${e.toString()}',
      );
    }
  }
  
  Future<void> authenticate() async {
    if (!state.canAuthenticate || state.isLoading) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to setup biometric login',
        biometricOnly: true,
      );
      
      if (authenticated) {
        // Generate a mock public key (in real app, generate actual key pair)
        final publicKey = _generateMockPublicKey();
        
        // Setup biometric with backend
        final authNotifier = _ref.read(authNotifierProvider.notifier);
        await authNotifier.setupBiometric(publicKey);
        
        state = state.copyWith(
          isLoading: false,
          setupComplete: true,
          publicKey: publicKey,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Authentication cancelled or failed',
        );
      }
    } catch (e) {
      AppLogger.e('Biometric authentication failed:', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication failed: ${e.toString()}',
      );
    }
  }
  
  void selectBiometric(CustomBiometricType type) {
    state = state.copyWith(selectedBiometric: type);
  }
  
  void skipSetup() {
    state = state.copyWith(setupComplete: true);
  }
  
  String _generateMockPublicKey() {
    // In a real app, generate an actual RSA/ECC key pair
    // This is a mock implementation
    return 'MOCK_PUBLIC_KEY_${DateTime.now().millisecondsSinceEpoch}';
  }
}

// Provider
final biometricSetupNotifierProvider = StateNotifierProvider<BiometricSetupNotifier, BiometricSetupState>((ref) {
  final localAuth = LocalAuthentication();
  return BiometricSetupNotifier(localAuth, ref);
});

// Screen
class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(biometricSetupNotifierProvider);
      if (!state.isAvailable && !state.isLoading) {
        _showNotAvailableDialog();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(biometricSetupNotifierProvider);
    final notifier = ref.read(biometricSetupNotifierProvider.notifier);
    
    if (state.isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Checking biometrics...'),
      );
    }
    
    if (state.setupComplete) {
      return _buildSuccessScreen(context);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.skipSetup();
              context.go('/dashboard');
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      body: _buildContent(state, notifier),
    );
  }
  
  Widget _buildContent(BiometricSetupState state, BiometricSetupNotifier notifier) {
    if (!state.isAvailable) {
      return _buildNotAvailableScreen(state);
    }
    
    if (!state.isEnrolled) {
      return _buildNotEnrolledScreen(state);
    }
    
    return _buildSetupScreen(state, notifier);
  }
  
  Widget _buildNotAvailableScreen(BiometricSetupState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.device_unknown,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Biometric Unavailable',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              state.errorMessage ?? 'Your device does not support biometric authentication.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                child: const Text('CONTINUE WITHOUT BIOMETRIC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotEnrolledScreen(BiometricSetupState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Biometrics Enrolled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Please enroll fingerprints or set up face recognition '
              'in your device settings to use biometric authentication.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            // Available biometric types
            if (state.availableBiometrics.isNotEmpty) ...[
              const Text(
                'Available biometric types on this device:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ...state.availableBiometrics.map((bio) => ListTile(
                leading: Icon(bio.icon),
                title: Text(bio.displayName),
                enabled: false,
              )),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Could open device settings
                  context.go('/dashboard');
                },
                child: const Text('OPEN DEVICE SETTINGS'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                child: const Text('CONTINUE WITHOUT BIOMETRIC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSetupScreen(BiometricSetupState state, BiometricSetupNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: state.selectedBiometric != null
                  ? Icon(
                      state.selectedBiometric!.icon,
                      size: 70,
                      color: const Color(0xFF00C853),
                    )
                  : const Icon(
                      Icons.security,
                      size: 70,
                      color: Color(0xFF00C853),
                    ),
            ),
          ),
          const SizedBox(height: 30),
          // Title
          const Text(
            'Setup Biometric Login',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          // Description
          const Text(
            'Add an extra layer of security to your Bingwa Pro account. '
            'Use your fingerprint or face to login quickly and securely.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          // Benefits
          const Text(
            'Benefits:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          _buildBenefitItem(
            icon: Icons.lock_outline,
            title: 'Enhanced Security',
            description: 'Biometrics are unique to you and hard to replicate',
          ),
          _buildBenefitItem(
            icon: Icons.speed,
            title: 'Faster Login',
            description: 'Access your account instantly without typing PIN',
          ),
          _buildBenefitItem(
            icon: Icons.devices,
            title: 'Device Protection',
            description: 'Your biometric data stays on your device',
          ),
          const SizedBox(height: 40),
          // Biometric Type Selection (if multiple available)
          if (state.availableBiometrics.length > 1) ...[
            const Text(
              'Select biometric method:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              children: state.availableBiometrics.map((bio) {
                final isSelected = state.selectedBiometric == bio;
                return ChoiceChip(
                  label: Text(bio.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      notifier.selectBiometric(bio);
                    }
                  },
                  selectedColor: const Color(0xFF00C853),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
          ],
          // Setup Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => notifier.authenticate(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(state.selectedBiometric?.icon ?? Icons.fingerprint),
                  const SizedBox(width: 10),
                  const Text(
                    'SETUP BIOMETRIC LOGIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Error Message
          if (state.errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorWidget(state.errorMessage!),
          ],
          const SizedBox(height: 20),
          // Terms Note
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'By enabling biometric login, you agree that your biometric data '
              'will be used only for authentication on this device and will not '
              'be stored on our servers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00C853)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessScreen(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  size: 60,
                  color: Color(0xFF00C853),
                ),
              ),
              const SizedBox(height: 30),
              // Success Message
              const Text(
                'Biometric Setup Complete!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'You can now use biometric authentication to login to your Bingwa Pro account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'GO TO DASHBOARD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Test Button
              OutlinedButton(
                onPressed: () {
                  // Test biometric login
                  _testBiometricLogin();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C853)),
                ),
                child: const Text(
                  'TEST BIOMETRIC LOGIN',
                  style: TextStyle(color: Color(0xFF00C853)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showNotAvailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Not Available'),
        content: const Text(
          'Your device does not support biometric authentication. '
          'You can still use PIN login.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _testBiometricLogin() async {
    final state = ref.read(biometricSetupNotifierProvider);
    final notifier = ref.read(biometricSetupNotifierProvider.notifier);
    
    await notifier.authenticate();
    
    if (state.errorMessage == null && state.setupComplete) {
      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric login test successful!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}