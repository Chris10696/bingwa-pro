import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/security/secure_storage_manager.dart';
import '../../core/security/device_fingerprint.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../models/auth_model.dart';

class AuthRepository {
  final Dio _dio;
  
  AuthRepository(this._dio);
  
  // Login
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.login,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.login,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.login,
        data: response.data,
      );
      
      // SAFELY parse the response
      if (response.data == null) {
        throw AppException('Login failed: Empty response');
      }
      
      try {
        final loginResponse = LoginResponse.fromJson(response.data);
        
        // Save tokens and session data
        await SecureStorageManager.saveAuthToken(loginResponse.accessToken);
        await SecureStorageManager.saveRefreshToken(loginResponse.refreshToken);
        await SecureStorageManager.saveSessionExpiry(loginResponse.expiresAt);
        await SecureStorageManager.saveAgentId(loginResponse.agent.id);
        
        // Save device ID if not already saved
        final deviceId = await SecureStorageManager.getDeviceId();
        if (deviceId == null) {
          final newDeviceId = await DeviceFingerprint.generateDeviceId();
          await SecureStorageManager.saveDeviceId(newDeviceId);
        }
        
        AppLogger.logSessionEvent(
          event: 'Login successful',
          agentId: loginResponse.agent.id,
          details: 'Device: ${request.deviceId}',
        );
        
        return loginResponse;
      } catch (parseError) {
        // If parsing fails, try to manually create response
        AppLogger.w('Login response parsing failed, using manual creation', parseError);
        
        // Extract data manually
        final data = response.data;
        
        // Parse agent data
        final agentData = data['agent'] as Map<String, dynamic>? ?? {};
        
        // Create agent profile manually
        final agent = AgentProfile(
          id: agentData['id']?.toString() ?? '',
          fullName: agentData['fullName']?.toString() ?? '',
          phoneNumber: agentData['phoneNumber']?.toString() ?? '',
          email: agentData['email']?.toString() ?? '',
          status: _parseAgentStatus(agentData['status']?.toString() ?? 'PENDING'),
          tokenBalance: (agentData['tokenBalance'] is num 
              ? (agentData['tokenBalance'] as num).toDouble() 
              : 0.0),
          registeredAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          nationalId: '',
          agentCode: '',
          businessName: '',
          location: '',
          totalCommission: 0.0,
          totalTransactions: 0,
          successRate: 0.0,
        );
        
        // Parse expiry date
        DateTime expiresAt;
        try {
          expiresAt = DateTime.parse(data['expiresAt']?.toString() ?? DateTime.now().toIso8601String());
        } catch (e) {
          expiresAt = DateTime.now().add(const Duration(days: 7));
        }
        
        final loginResponse = LoginResponse(
          accessToken: data['accessToken']?.toString() ?? '',
          refreshToken: data['refreshToken']?.toString() ?? '',
          expiresAt: expiresAt,
          agent: agent,
          requiresBiometricSetup: data['requiresBiometricSetup'] == true,
        );
        
        // Save tokens and session data
        await SecureStorageManager.saveAuthToken(loginResponse.accessToken);
        await SecureStorageManager.saveRefreshToken(loginResponse.refreshToken);
        await SecureStorageManager.saveSessionExpiry(loginResponse.expiresAt);
        await SecureStorageManager.saveAgentId(loginResponse.agent.id);
        
        AppLogger.logSessionEvent(
          event: 'Login successful (manual parse)',
          agentId: loginResponse.agent.id,
        );
        
        return loginResponse;
      }
    } on DioException catch (e) {
      AppLogger.e('Login failed:', e);
      throw _handleDioError(e);
    } on TypeError catch (e) {
      AppLogger.e('Login type error:', e);
      throw AppException('Login failed: Invalid response format from server');
    } catch (e) {
      AppLogger.e('Login error:', e);
      throw AppException('Login failed: ${e.toString()}');
    }
  }
  
  // Helper method to parse agent status
  AgentAuthStatus _parseAgentStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AgentAuthStatus.active;
      case 'SUSPENDED':
        return AgentAuthStatus.suspended;
      case 'TERMINATED':
        return AgentAuthStatus.terminated;
      case 'PENDING_VERIFICATION':
        return AgentAuthStatus.pendingVerification;
      case 'PENDING':
      default:
        return AgentAuthStatus.pending;
    }
  }
  
  // Logout
  Future<void> logout() async {
    try {
      final token = await SecureStorageManager.getAuthToken();
      final agentId = await SecureStorageManager.getAgentId();
      
      if (token != null) {
        AppLogger.logNetworkRequest(
          method: 'POST',
          url: ApiConstants.logout,
        );
        
        await _dio.post(
          ApiConstants.logout,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
      
      // Clear local storage regardless of API response
      await SecureStorageManager.clearAll();
      
      AppLogger.logSessionEvent(
        event: 'Logout successful',
        agentId: agentId,
      );
    } on DioException catch (e) {
      // Even if API call fails, clear local storage
      await SecureStorageManager.clearAll();
      AppLogger.w('Logout API failed, but local data cleared:', e);
    } catch (e) {
      await SecureStorageManager.clearAll();
      AppLogger.e('Logout error:', e);
    }
  }
  
  // Refresh Token
  Future<LoginResponse> refreshToken() async {
    try {
      final refreshToken = await SecureStorageManager.getRefreshToken();
      if (refreshToken == null) {
        throw UnauthorizedException('No refresh token available');
      }
      
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      
      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.refreshToken,
        data: response.data,
      );
      
      if (response.data == null) {
        throw AppException('Token refresh failed: Empty response');
      }
      
      try {
        final loginResponse = LoginResponse.fromJson(response.data);
        
        // Save new tokens
        await SecureStorageManager.saveAuthToken(loginResponse.accessToken);
        await SecureStorageManager.saveRefreshToken(loginResponse.refreshToken);
        await SecureStorageManager.saveSessionExpiry(loginResponse.expiresAt);
        
        AppLogger.logSessionEvent(
          event: 'Token refreshed',
          agentId: loginResponse.agent.id,
        );
        
        return loginResponse;
      } catch (parseError) {
        AppLogger.w('Token refresh parsing failed, using manual creation', parseError);
        
        final data = response.data;
        
        // Parse agent data if available
        final agentData = data['agent'] as Map<String, dynamic>? ?? {};
        final agent = AgentProfile(
          id: agentData['id']?.toString() ?? '',
          fullName: agentData['fullName']?.toString() ?? '',
          phoneNumber: agentData['phoneNumber']?.toString() ?? '',
          email: agentData['email']?.toString() ?? '',
          status: _parseAgentStatus(agentData['status']?.toString() ?? 'ACTIVE'),
          tokenBalance: (agentData['tokenBalance'] is num 
              ? (agentData['tokenBalance'] as num).toDouble() 
              : 0.0),
          registeredAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          nationalId: '',
          agentCode: '',
          businessName: '',
          location: '',
          totalCommission: 0.0,
          totalTransactions: 0,
          successRate: 0.0,
        );
        
        DateTime expiresAt;
        try {
          expiresAt = DateTime.parse(data['expiresAt']?.toString() ?? DateTime.now().toIso8601String());
        } catch (e) {
          expiresAt = DateTime.now().add(const Duration(days: 7));
        }
        
        final loginResponse = LoginResponse(
          accessToken: data['accessToken']?.toString() ?? '',
          refreshToken: data['refreshToken']?.toString() ?? '',
          expiresAt: expiresAt,
          agent: agent,
          requiresBiometricSetup: data['requiresBiometricSetup'] == true,
        );
        
        await SecureStorageManager.saveAuthToken(loginResponse.accessToken);
        await SecureStorageManager.saveRefreshToken(loginResponse.refreshToken);
        await SecureStorageManager.saveSessionExpiry(loginResponse.expiresAt);
        
        return loginResponse;
      }
    } on DioException catch (e) {
      AppLogger.e('Token refresh failed:', e);
      // If refresh fails, logout the user
      await logout();
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Token refresh error:', e);
      await logout();
      throw AppException('Token refresh failed: ${e.toString()}');
    }
  }
  
  // Register
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.register,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.register,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.register,
        data: response.data,
      );
      
      // SAFELY parse the response
      if (response.data == null) {
        throw AppException('Registration failed: Empty response');
      }
      
      try {
        final registrationResponse = RegistrationResponse.fromJson(response.data);
        
        AppLogger.logSessionEvent(
          event: 'Registration successful',
          details: 'Agent ID: ${registrationResponse.agentId}',
        );
        
        return registrationResponse;
      } catch (parseError) {
        // If parsing fails, create a manual response with just the fields we have
        AppLogger.w('Registration response parsing failed, using manual creation', parseError);
        
        // Manually create response with available data
        return RegistrationResponse(
          message: response.data['message']?.toString() ?? 'Registration successful',
          agentId: response.data['agentId']?.toString() ?? '',
          verificationToken: null,
          verificationExpiry: null,
          requiresManualApproval: true,
        );
      }
    } on DioException catch (e) {
      AppLogger.e('Registration failed:', e);
      throw _handleDioError(e);
    } on TypeError catch (e) {
      AppLogger.e('Registration type error:', e);
      throw AppException('Registration failed: Invalid response format from server');
    } catch (e) {
      AppLogger.e('Registration error:', e);
      throw AppException('Registration failed: ${e.toString()}');
    }
  }
  
  // Verify Phone (Send OTP)
  Future<void> verifyPhone(String phoneNumber) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.verifyPhone,
        data: {'phone_number': phoneNumber},
      );
      
      final response = await _dio.post(
        ApiConstants.verifyPhone,
        data: {'phone_number': phoneNumber},
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.verifyPhone,
        data: response.data,
      );
      
      AppLogger.logSessionEvent(
        event: 'Phone verification OTP sent',
        details: 'Phone: $phoneNumber',
      );
    } on DioException catch (e) {
      AppLogger.e('Phone verification failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Phone verification error:', e);
      throw AppException('Phone verification failed: ${e.toString()}');
    }
  }
  
  // Reset PIN
  Future<void> resetPin(PinResetRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.resetPin,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.resetPin,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.resetPin,
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'PIN reset successful',
        details: 'Phone: ${request.phoneNumber}',
      );
    } on DioException catch (e) {
      AppLogger.e('PIN reset failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('PIN reset error:', e);
      throw AppException('PIN reset failed: ${e.toString()}');
    }
  }
  
  // Get Agent Profile
  Future<AgentProfile> getAgentProfile() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.agentProfile,
      );
      
      final response = await _dio.get(ApiConstants.agentProfile);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.agentProfile,
        data: response.data,
      );
      
      if (response.data == null) {
        throw AppException('Failed to get agent profile: Empty response');
      }
      
      return AgentProfile.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get agent profile failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Get agent profile error:', e);
      throw AppException('Failed to get agent profile: ${e.toString()}');
    }
  }
  
  // Update Profile
  Future<AgentProfile> updateProfile(AgentUpdateRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'PUT',
        url: ApiConstants.updateProfile,
        data: request.toJson(),
      );
      
      final response = await _dio.put(
        ApiConstants.updateProfile,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.updateProfile,
        data: response.data,
      );
      
      if (response.data == null) {
        throw AppException('Profile update failed: Empty response');
      }
      
      final updatedProfile = AgentProfile.fromJson(response.data);
      
      AppLogger.logSessionEvent(
        event: 'Profile updated',
        agentId: updatedProfile.id,
      );
      
      return updatedProfile;
    } on DioException catch (e) {
      AppLogger.e('Profile update failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Profile update error:', e);
      throw AppException('Profile update failed: ${e.toString()}');
    }
  }
  
  // Check Session Validity
  Future<bool> checkSessionValidity() async {
    try {
      final isValid = await SecureStorageManager.isSessionValid();
      if (!isValid) {
        await logout();
        return false;
      }
      
      // Check if token is about to expire
      final expiry = await SecureStorageManager.getSessionExpiry();
      if (expiry != null) {
        final now = DateTime.now();
        final difference = expiry.difference(now);
        final minutesLeft = difference.inMinutes;
        
        // Refresh token if less than 5 minutes left
        if (minutesLeft <= 5) {
          try {
            await refreshToken();
          } catch (e) {
            AppLogger.w('Token refresh failed during validity check', e);
          }
        }
      }
      
      return true;
    } catch (e) {
      AppLogger.e('Session validity check failed:', e);
      await logout();
      return false;
    }
  }
  
  // Get Active Sessions
  Future<List<SessionInfo>> getActiveSessions() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/auth/sessions',
      );
      
      final response = await _dio.get('/auth/sessions');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/auth/sessions',
        data: response.data,
      );
      
      if (response.data == null || response.data['sessions'] == null) {
        return [];
      }
      
      final sessions = (response.data['sessions'] as List)
          .map((json) => SessionInfo.fromJson(json))
          .toList();
      
      return sessions;
    } on DioException catch (e) {
      AppLogger.e('Get sessions failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Get sessions error:', e);
      throw AppException('Failed to get sessions: ${e.toString()}');
    }
  }
  
  // Terminate Session
  Future<void> terminateSession(String sessionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'DELETE',
        url: '/auth/sessions/$sessionId',
      );
      
      final response = await _dio.delete('/auth/sessions/$sessionId');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/auth/sessions/$sessionId',
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'Session terminated',
        details: 'Session ID: $sessionId',
      );
    } on DioException catch (e) {
      AppLogger.e('Terminate session failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Terminate session error:', e);
      throw AppException('Failed to terminate session: ${e.toString()}');
    }
  }
  
  // Terminate All Other Sessions
  Future<void> terminateAllOtherSessions() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'DELETE',
        url: '/auth/sessions/others',
      );
      
      final response = await _dio.delete('/auth/sessions/others');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/auth/sessions/others',
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'All other sessions terminated',
      );
    } on DioException catch (e) {
      AppLogger.e('Terminate all sessions failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Terminate all sessions error:', e);
      throw AppException('Failed to terminate all sessions: ${e.toString()}');
    }
  }
  
  // Setup Biometric Authentication
  Future<void> setupBiometric(BiometricSetupRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/auth/biometric/setup',
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        '/auth/biometric/setup',
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/auth/biometric/setup',
        data: response.data,
      );
      
      // Save biometric key locally
      await SecureStorageManager.saveBiometricKey(request.publicKey);
      
      AppLogger.logSecurityEvent(
        event: 'Biometric setup successful',
        agentId: request.agentId,
      );
    } on DioException catch (e) {
      AppLogger.e('Biometric setup failed:', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('Biometric setup error:', e);
      throw AppException('Biometric setup failed: ${e.toString()}');
    }
  }
  
  // Helper method to handle Dio errors
  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      final message = data is Map ? (data['message'] ?? 'Request failed') : 'Request failed';
      final code = data is Map ? (data['code'] ?? 'UNKNOWN_ERROR') : 'UNKNOWN_ERROR';
      
      switch (e.response!.statusCode) {
        case 400:
          return ValidationException(message, data is Map ? (data['errors'] ?? {}) : {});
        case 401:
          return UnauthorizedException(message);
        case 403:
          return ForbiddenException(message);
        case 404:
          return NotFoundException(message);
        case 409:
          return AppException(message);
        case 422:
          return ValidationException(message, data is Map ? (data['errors'] ?? {}) : {});
        case 429:
          return AppException('Too many requests. Please try again later.');
        case 500:
        case 502:
        case 503:
        case 504:
          return AppException('Server error. Please try again later.');
        default:
          return ApiException(message, code: code, statusCode: e.response!.statusCode);
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
               e.type == DioExceptionType.receiveTimeout ||
               e.type == DioExceptionType.sendTimeout) {
      return TimeoutException('Request timeout');
    } else if (e.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    } else {
      return AppException(e.message ?? 'Unknown error occurred');
    }
  }
}

// Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return AuthRepository(dio);
});