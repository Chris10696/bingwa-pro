import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formz/formz.dart' show FormzSubmissionStatus, FormzSubmissionStatusX;
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../shared/models/auth_model.dart';
import '../../../../shared/repositories/auth_repository.dart';

// State
class VerifyPhoneState {
  final String phone;
  final String verificationToken;
  final String otp;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isLoading;
  final bool otpSent;
  final bool otpVerified;
  final int? otpExpirySeconds;
  final int remainingSeconds;
  final bool canResend;
  
  const VerifyPhoneState({
    required this.phone,
    required this.verificationToken,
    this.otp = '',
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isLoading = false,
    this.otpSent = true,
    this.otpVerified = false,
    this.otpExpirySeconds = 300,
    this.remainingSeconds = 300,
    this.canResend = false,
  });
  
  VerifyPhoneState copyWith({
    String? phone,
    String? verificationToken,
    String? otp,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isLoading,
    bool? otpSent,
    bool? otpVerified,
    int? otpExpirySeconds,
    int? remainingSeconds,
    bool? canResend,
  }) {
    return VerifyPhoneState(
      phone: phone ?? this.phone,
      verificationToken: verificationToken ?? this.verificationToken,
      otp: otp ?? this.otp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      otpExpirySeconds: otpExpirySeconds ?? this.otpExpirySeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      canResend: canResend ?? this.canResend,
    );
  }
}

// Notifier
class VerifyPhoneNotifier extends StateNotifier<VerifyPhoneState> {
  final AuthRepository _authRepository;
  Timer? _otpTimer;
  
  VerifyPhoneNotifier({
    required String phone,
    required String verificationToken,
    required AuthRepository authRepository,
  }) : _authRepository = authRepository,
       super(VerifyPhoneState(
         phone: phone,
         verificationToken: verificationToken,
         remainingSeconds: 300,
       )) {
    _startOtpTimer();
  }
  
  void updateOtp(String value) {
    state = state.copyWith(
      otp: value,
      errorMessage: null,
    );
  }
  
  Future<void> verifyOtp() async {
    if (state.status.isInProgress || state.otp.length != 6) {
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      // In a real app, you would verify OTP with backend
      // For now, simulate verification with the token
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock verification logic
      if (state.otp == '123456' || state.otp == '000000') {
        _otpTimer?.cancel();
        
        state = state.copyWith(
          status: FormzSubmissionStatus.success,
          isLoading: false,
          otpVerified: true,
        );
      } else {
        throw Exception('Invalid OTP');
      }
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Invalid OTP. Please try again.',
        isLoading: false,
      );
    }
  }
  
  Future<void> resendOtp() async {
    if (state.status.isInProgress) return;
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      await _authRepository.verifyPhone(state.phone);
      
      // Reset timer
      _otpTimer?.cancel();
      _startOtpTimer();
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
        remainingSeconds: 300,
        canResend: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Failed to resend OTP. Please try again.',
        isLoading: false,
      );
    }
  }
  
  void _startOtpTimer() {
    _otpTimer?.cancel();
    
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 0) {
        timer.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          canResend: true,
        );
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          canResend: false,
        );
      }
    });
  }
  
  String get formattedRemainingTime {
    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }
}

// Provider factory
final verifyPhoneNotifierProvider = StateNotifierProvider.family<
  VerifyPhoneNotifier, VerifyPhoneState, Map<String, String>>(
  (ref, params) {
    final authRepository = ref.watch(authRepositoryProvider);
    return VerifyPhoneNotifier(
      phone: params['phone'] ?? '',
      verificationToken: params['token'] ?? '',
      authRepository: authRepository,
    );
  },
);

// Screen
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  final String phone;
  final String token;
  
  const VerifyPhoneScreen({
    super.key,
    required this.phone,
    required this.token,
  });
  
  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  String _enteredOtp = '';
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyPhoneNotifierProvider({
      'phone': widget.phone,
      'token': widget.token,
    }));
    final notifier = ref.read(verifyPhoneNotifierProvider({
      'phone': widget.phone,
      'token': widget.token,
    }).notifier);
    
    if (state.isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Verifying...'),
      );
    }
    
    if (state.otpVerified) {
      return _buildSuccessScreen(context, state);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // Illustration/Icon
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms,
                  size: 60,
                  color: Color(0xFF00C853),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Title
            const Text(
              'Verify Phone Number',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Description
            Text.rich(
              TextSpan(
                text: 'Enter the 6-digit code sent to ',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                children: [
                  TextSpan(
                    text: widget.phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // OTP Input
            Center(
              child: OtpTextField(
                numberOfFields: 6,
                fieldWidth: 45,
                borderRadius: BorderRadius.circular(10),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                showFieldAsBox: true,
                borderColor: Colors.grey[300]!,
                focusedBorderColor: const Color(0xFF00C853),
                cursorColor: const Color(0xFF00C853),
                onSubmit: (value) {
                  _enteredOtp = value;
                  notifier.updateOtp(value);
                },
              ),
            ),
            const SizedBox(height: 30),
            // Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  'Code expires in ${notifier.formattedRemainingTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: state.remainingSeconds < 60 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Resend OTP
            Center(
              child: TextButton(
                onPressed: state.canResend ? () => notifier.resendOtp() : null,
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: state.canResend ? const Color(0xFF00C853) : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _enteredOtp.length == 6
                    ? () => notifier.verifyOtp()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'VERIFY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Error Message
            if (state.errorMessage != null) ...[
              const SizedBox(height: 20),
              _buildErrorWidget(state.errorMessage!),
            ],
            const SizedBox(height: 30),
            // Help Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "If you don't receive the code within a few minutes, "
                "please check your spam folder or request a new code.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSuccessScreen(BuildContext context, VerifyPhoneState state) {
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
                  Icons.check_circle,
                  size: 60,
                  color: Color(0xFF00C853),
                ),
              ),
              const SizedBox(height: 30),
              // Success Message
              const Text(
                'Phone Verified!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Your phone number has been successfully verified.',
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
                    // Navigate to next screen (e.g., biometric setup or dashboard)
                    context.go('/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'CONTINUE TO DASHBOARD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Alternative Action
              TextButton(
                onPressed: () {
                  // Go to settings or other options
                },
                child: const Text(
                  'Setup Biometric Authentication',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF00C853),
                  ),
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
}