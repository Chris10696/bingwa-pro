import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formz/formz.dart' show FormzInput, FormzSubmissionStatus, FormzSubmissionStatusX;
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/models/auth_model.dart';
import '../../../../shared/repositories/auth_repository.dart';

// Form Models
class PhoneNumberInput extends FormzInput<String, String> {
  const PhoneNumberInput.pure() : super.pure('');
  const PhoneNumberInput.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidSafaricomNumber(value);
  }
}

class NationalIdInput extends FormzInput<String, String> {
  const NationalIdInput.pure() : super.pure('');
  const NationalIdInput.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidNationalId(value);
  }
}

class OtpInput extends FormzInput<String, String> {
  const OtpInput.pure() : super.pure('');
  const OtpInput.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'OTP must contain only digits';
    }
    return null;
  }
}

class NewPinInput extends FormzInput<String, String> {
  const NewPinInput.pure() : super.pure('');
  const NewPinInput.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidPin(value);
  }
}

class ConfirmNewPinInput extends FormzInput<String, String> {
  final String newPin;
  
  const ConfirmNewPinInput.pure({this.newPin = ''}) : super.pure('');
  const ConfirmNewPinInput.dirty({required this.newPin, String value = ''}) 
      : super.dirty(value);
  
  @override
  String? validator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm PIN is required';
    }
    if (value != newPin) {
      return 'PINs do not match';
    }
    return null;
  }
}

// State
class ForgotPinState {
  final PhoneNumberInput phoneNumber;
  final NationalIdInput nationalId;
  final OtpInput otp;
  final NewPinInput newPin;
  final ConfirmNewPinInput confirmNewPin;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isLoading;
  final bool otpSent;
  final bool otpVerified;
  final bool showNewPinForm;
  final String? verificationToken;
  final int? otpExpirySeconds;
  final int remainingSeconds;
  
  ForgotPinState({
    this.phoneNumber = const PhoneNumberInput.pure(),
    this.nationalId = const NationalIdInput.pure(),
    this.otp = const OtpInput.pure(),
    this.newPin = const NewPinInput.pure(),
    this.confirmNewPin = const ConfirmNewPinInput.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isLoading = false,
    this.otpSent = false,
    this.otpVerified = false,
    this.showNewPinForm = false,
    this.verificationToken,
    this.otpExpirySeconds = 300,
    this.remainingSeconds = 0,
  });
  
  ForgotPinState copyWith({
    PhoneNumberInput? phoneNumber,
    NationalIdInput? nationalId,
    OtpInput? otp,
    NewPinInput? newPin,
    ConfirmNewPinInput? confirmNewPin,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isLoading,
    bool? otpSent,
    bool? otpVerified,
    bool? showNewPinForm,
    String? verificationToken,
    int? otpExpirySeconds,
    int? remainingSeconds,
  }) {
    return ForgotPinState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationalId: nationalId ?? this.nationalId,
      otp: otp ?? this.otp,
      newPin: newPin ?? this.newPin,
      confirmNewPin: confirmNewPin ?? this.confirmNewPin,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      showNewPinForm: showNewPinForm ?? this.showNewPinForm,
      verificationToken: verificationToken ?? this.verificationToken,
      otpExpirySeconds: otpExpirySeconds ?? this.otpExpirySeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

// Notifier
class ForgotPinNotifier extends StateNotifier<ForgotPinState> {
  final AuthRepository _authRepository;
  Timer? _otpTimer;
  
  ForgotPinNotifier(this._authRepository) : super(ForgotPinState());
  
  // Update methods
  void updatePhoneNumber(String value) {
    state = state.copyWith(
      phoneNumber: PhoneNumberInput.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateNationalId(String value) {
    state = state.copyWith(
      nationalId: NationalIdInput.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateOtp(String value) {
    state = state.copyWith(
      otp: OtpInput.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateNewPin(String value) {
    final newPin = NewPinInput.dirty(value);
    state = state.copyWith(
      newPin: newPin,
      confirmNewPin: ConfirmNewPinInput.dirty(
        newPin: value,
        value: state.confirmNewPin.value,
      ),
      errorMessage: null,
    );
  }
  
  void updateConfirmNewPin(String value) {
    state = state.copyWith(
      confirmNewPin: ConfirmNewPinInput.dirty(
        newPin: state.newPin.value,
        value: value,
      ),
      errorMessage: null,
    );
  }
  
  // Send OTP
  Future<void> sendOtp() async {
    if (state.status.isInProgress) return;
    
    if (!state.phoneNumber.isValid || !state.nationalId.isValid) {
      state = state.copyWith(
        errorMessage: 'Please fix validation errors',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      await _authRepository.verifyPhone(state.phoneNumber.value);
      
      // Start OTP timer
      _startOtpTimer();
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
        otpSent: true,
        otpExpirySeconds: 300,
        remainingSeconds: 300,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Failed to send OTP: ${e.toString()}',
        isLoading: false,
      );
    }
  }
  
  // Verify OTP
  Future<void> verifyOtp() async {
    if (state.status.isInProgress || !state.otp.isValid) {
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      // In a real app, you would verify OTP with backend
      // For now, we'll simulate verification
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate a verification token
      final verificationToken = 'VERIFY_${DateTime.now().millisecondsSinceEpoch}';
      
      _otpTimer?.cancel();
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
        otpVerified: true,
        showNewPinForm: true,
        verificationToken: verificationToken,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Invalid OTP. Please try again.',
        isLoading: false,
      );
    }
  }
  
  // Reset PIN
  Future<void> resetPin() async {
    if (state.status.isInProgress) return;
    
    if (!state.newPin.isValid || !state.confirmNewPin.isValid) {
      state = state.copyWith(
        errorMessage: 'Please fix validation errors',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      final request = PinResetRequest(
        phoneNumber: state.phoneNumber.value,
        nationalId: state.nationalId.value,
        newPin: state.newPin.value,
        confirmPin: state.confirmNewPin.value,
        otp: state.otp.value,
      );
      
      await _authRepository.resetPin(request);
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Failed to reset PIN: ${e.toString()}',
        isLoading: false,
      );
    }
  }
  
  // Resend OTP
  Future<void> resendOtp() async {
    await sendOtp();
  }
  
  // Timer methods
  void _startOtpTimer() {
    _otpTimer?.cancel();
    
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 0) {
        timer.cancel();
        state = state.copyWith(
          otpSent: false,
          remainingSeconds: 0,
        );
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
        );
      }
    });
  }
  
  String get formattedRemainingTime {
    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Back to first step
  void backToFirstStep() {
    _otpTimer?.cancel();
    state = ForgotPinState();
  }
  
  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }
}

// Provider
final forgotPinNotifierProvider = StateNotifierProvider<ForgotPinNotifier, ForgotPinState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return ForgotPinNotifier(authRepository);
});

// Screen
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  
  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _nationalIdController.addListener(_onNationalIdChanged);
    _otpController.addListener(_onOtpChanged);
    _newPinController.addListener(_onNewPinChanged);
    _confirmPinController.addListener(_onConfirmPinChanged);
  }
  
  void _onPhoneChanged() {
    ref.read(forgotPinNotifierProvider.notifier).updatePhoneNumber(_phoneController.text);
  }
  
  void _onNationalIdChanged() {
    ref.read(forgotPinNotifierProvider.notifier).updateNationalId(_nationalIdController.text);
  }
  
  void _onOtpChanged() {
    ref.read(forgotPinNotifierProvider.notifier).updateOtp(_otpController.text);
  }
  
  void _onNewPinChanged() {
    ref.read(forgotPinNotifierProvider.notifier).updateNewPin(_newPinController.text);
  }
  
  void _onConfirmPinChanged() {
    ref.read(forgotPinNotifierProvider.notifier).updateConfirmNewPin(_confirmPinController.text);
  }
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPinNotifierProvider);
    final notifier = ref.read(forgotPinNotifierProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.otpSent || state.showNewPinForm) {
              notifier.backToFirstStep();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: state.isLoading
          ? const LoadingIndicator(message: 'Processing...')
          : _buildContent(state, notifier),
    );
  }
  
  Widget _buildContent(ForgotPinState state, ForgotPinNotifier notifier) {
    if (state.showNewPinForm) {
      return _buildNewPinForm(state, notifier);
    } else if (state.otpSent) {
      return _buildOtpForm(state, notifier);
    } else {
      return _buildInitialForm(state, notifier);
    }
  }
  
  Widget _buildInitialForm(ForgotPinState state, ForgotPinNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Reset Your PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your registered phone number and national ID to reset your PIN.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          // Phone Number
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
          ),
          const SizedBox(height: 20),
          // National ID
          TextField(
            controller: _nationalIdController,
            decoration: InputDecoration(
              labelText: 'National ID',
              hintText: '12345678',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              errorText: state.nationalId.error,
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
          ),
          const SizedBox(height: 30),
          // Send OTP Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.phoneNumber.isValid && state.nationalId.isValid
                  ? () => notifier.sendOtp()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'SEND OTP',
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
        ],
      ),
    );
  }
  
  Widget _buildOtpForm(ForgotPinState state, ForgotPinNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Verify OTP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the 6-digit OTP sent to ${state.phoneNumber.value}.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          // OTP Input
          TextField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: '6-digit OTP',
              hintText: '123456',
              prefixIcon: const Icon(Icons.sms),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              errorText: state.otp.error,
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 10),
          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OTP expires in ${notifier.formattedRemainingTime}',
                style: TextStyle(
                  color: state.remainingSeconds < 60 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: state.remainingSeconds > 0 ? null : () => notifier.resendOtp(),
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: state.remainingSeconds > 0 ? Colors.grey : const Color(0xFF00C853),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.otp.isValid
                  ? () => notifier.verifyOtp()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'VERIFY OTP',
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
        ],
      ),
    );
  }
  
  Widget _buildNewPinForm(ForgotPinState state, ForgotPinNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Set New PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create a new 4-digit PIN for your account.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          // New PIN
          TextField(
            controller: _newPinController,
            decoration: InputDecoration(
              labelText: 'New PIN',
              hintText: '••••',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPin ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPin = !_obscureNewPin;
                  });
                },
              ),
              errorText: state.newPin.error,
            ),
            obscureText: _obscureNewPin,
            keyboardType: TextInputType.number,
            maxLength: 4,
          ),
          const SizedBox(height: 20),
          // Confirm PIN
          TextField(
            controller: _confirmPinController,
            decoration: InputDecoration(
              labelText: 'Confirm New PIN',
              hintText: '••••',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPin ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
              ),
              errorText: state.confirmNewPin.error,
            ),
            obscureText: _obscureConfirmPin,
            keyboardType: TextInputType.number,
            maxLength: 4,
          ),
          const SizedBox(height: 30),
          // Reset PIN Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.newPin.isValid && state.confirmNewPin.isValid
                  ? () async {
                      await notifier.resetPin();
                      if (state.status == FormzSubmissionStatus.success) {
                        if (mounted) {
                          _showSuccessDialog(context);
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
              child: const Text(
                'RESET PIN',
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
        ],
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
  
  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(
          Icons.check_circle,
          size: 64,
          color: Colors.green,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PIN Reset Successful',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Your PIN has been successfully reset. You can now login with your new PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop(); // Go back to login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('LOGIN NOW'),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _nationalIdController.dispose();
    _otpController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}