import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _acceptTerms = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    if (state.isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Processing...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Full Name
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'John Doe',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: Validators.isValidFullName,
                onChanged: notifier.updateFullName,
              ),
              const SizedBox(height: 20),
              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Safaricom Number',
                  hintText: '0712 345 678',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: Validators.isValidSafaricomNumber,
                onChanged: notifier.updatePhoneNumber,
              ),
              const SizedBox(height: 20),
              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'email@example.com',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    return Validators.isValidEmail(value);
                  }
                  return null;
                },
                onChanged: notifier.updateEmail,
              ),
              const SizedBox(height: 20),
              // National ID
              TextFormField(
                controller: _nationalIdController,
                decoration: InputDecoration(
                  labelText: 'National ID',
                  hintText: '12345678',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                validator: Validators.isValidNationalId,
                onChanged: notifier.updateNationalId,
              ),
              const SizedBox(height: 20),
              // PIN
              TextFormField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'PIN (4 digits)',
                  hintText: '••••',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: Validators.isValidPin,
                onChanged: (value) {
                  notifier.updatePin(value);
                  // Update confirm pin validation
                  notifier.updateConfirmPin(_confirmPinController.text);
                },
              ),
              const SizedBox(height: 20),
              // Confirm PIN
              TextFormField(
                controller: _confirmPinController,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  hintText: '••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPin
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPin = !_obscureConfirmPin;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm PIN is required';
                  }
                  if (value != _pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
                onChanged: notifier.updateConfirmPin,
              ),
              const SizedBox(height: 20),
              // Terms and Conditions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF00C853),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'I agree to the Terms of Service and Privacy Policy',
                          style: TextStyle(fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            // Show terms dialog
                            _showTermsDialog(context);
                          },
                          child: const Text(
                            'Read Terms',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _acceptTerms &&
                          !state.status.isInProgress &&
                          _formKey.currentState?.validate() == true
                      ? () async {
                          await notifier.register();
                          if (state.isRegistering &&
                              state.registrationToken != null &&
                              mounted) {
                            context.push('/verify-phone',
                                extra: {
                                  'phone': _phoneController.text,
                                  'token': state.registrationToken,
                                });
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
                      ? const ButtonLoadingIndicator()
                      : const Text(
                          'CREATE ACCOUNT',
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
                        const Icon(Icons.error_outline, color: Colors.red),
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
              // Already have account
              Center(
                child: TextButton(
                  onPressed: () {
                    context.pop();
                  },
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(color: Color(0xFF00C853)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bingwa Pro Agent Platform Terms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '1. You must be a registered Safaricom agent to use this platform.',
              ),
              SizedBox(height: 5),
              Text(
                '2. Tokens are non-transferable and non-refundable.',
              ),
              SizedBox(height: 5),
              Text(
                '3. You are responsible for all transactions made from your account.',
              ),
              SizedBox(height: 5),
              Text(
                '4. The platform is not liable for network failures or USSD changes.',
              ),
              SizedBox(height: 5),
              Text(
                '5. You must maintain adequate token balance for transactions.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: null, // Will be set by showDialog
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      // Dialog closed
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}