import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Logo and Title
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 80,
                              width: 80,
                              errorBuilder: (context, error, stackTrace) =>
                                  const FlutterLogo(size: 80),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Bingwa Pro',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C853),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Safaricom Agent Platform',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Phone Number Field
                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Safaricom Number',
                          hintText: '0712 345 678',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorText: state.phoneNumber.error,
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: notifier.updatePhoneNumber,
                      ),
                      const SizedBox(height: 20),
                      // PIN Field
                      TextField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          hintText: '••••',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                          errorText: state.pin.error,
                        ),
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        onChanged: notifier.updatePin,
                      ),
                      const SizedBox(height: 10),
                      // Forgot PIN
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            context.push('/forgot-pin');
                          },
                          child: const Text(
                            'Forgot PIN?',
                            style: TextStyle(color: Color(0xFF00C853)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Login Button
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: state.phoneNumber.isValid &&
                                  state.pin.isValid &&
                                  !state.status.isInProgress
                              ? () async {
                                  // Call login
                                  await notifier.login();
                                  
                                  // Check result after login
                                  if (mounted) {
                                    if (state.isAuthenticated) {
                                      if (state.requiresBiometricSetup) {
                                        context.push('/biometric-setup');
                                      } else {
                                        // Use go_router to navigate to dashboard
                                        context.go('/dashboard');
                                      }
                                    } else if (state.errorMessage != null) {
                                      // Show error in snackbar for better visibility
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(state.errorMessage!),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: state.status.isInProgress
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'CONTINUE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      // Error Message
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: notifier.clearError,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Terms and Conditions
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // Spacer replacement - use flexible space
                      const Expanded(
                        child: SizedBox.shrink(),
                      ),
                      // Register Link
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                context.push('/register');
                              },
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}