//import 'dart:async';

import 'package:bingwa_pro/core/security/secure_storage_manager.dart';
import 'package:bingwa_pro/core/utils/session_manager.dart';
import 'package:bingwa_pro/core/utils/session_state_provider.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/biometric_setup_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/forgot_pin_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/login_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/register_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/verify_phone_screen.dart';
import 'package:bingwa_pro/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bingwa_pro/features/settings/presentation/screens/settings_screen.dart';
import 'package:bingwa_pro/features/transactions/presentation/screens/airtime_screen.dart';
import 'package:bingwa_pro/features/transactions/presentation/screens/data_screen.dart';
import 'package:bingwa_pro/features/transactions/presentation/screens/sms_screen.dart';
import 'package:bingwa_pro/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:bingwa_pro/features/wallet/presentation/screens/topup_screen.dart';
import 'package:bingwa_pro/features/wallet/presentation/screens/wallet_screen.dart';

// ========== NEW SCREEN IMPORTS ==========
import 'package:bingwa_pro/features/offers/presentation/screens/offers_screen.dart';
import 'package:bingwa_pro/features/customers/presentation/screens/customers_screen.dart';
import 'package:bingwa_pro/features/reports/presentation/screens/reports_screen.dart';
import 'package:bingwa_pro/features/help/presentation/screens/help_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Define route names as constants for type safety
class AppRoutes {
  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyPhone = '/verify-phone';
  static const String forgotPin = '/forgot-pin';
  static const String biometricSetup = '/biometric-setup';
  
  // Main app routes
  static const String dashboard = '/dashboard';
  static const String wallet = '/wallet';
  static const String topUp = '/top-up';
  static const String airtime = '/airtime';
  static const String data = '/data';
  static const String sms = '/sms';
  static const String transactionHistory = '/transaction-history';
  static const String settings = '/settings';
  static const String profile = '/profile';
  
  // ========== NEW ROUTES ==========
  static const String offers = '/offers';
  static const String customers = '/customers';
  static const String reports = '/reports';
  static const String help = '/help';
  
  // Root paths
  static const String root = '/';
}

/// Custom transition builders for consistent animations
class AppTransitions {
  static Widget fadeTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
  
  static Widget slideTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;
    
    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    var offsetAnimation = animation.drive(tween);
    
    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }
  
  static Widget scaleTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutBack,
        ),
      ),
      child: child,
    );
  }
}

// Create providers if they don't exist
//final sessionManagerProvider = Provider<SessionManager>((ref) {
 // return SessionManager(ref);
//});

final secureStorageManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

/// Router configuration for the entire application
final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionStateNotifier = ref.read(sessionStateProvider.notifier);
  
  return GoRouter(
    initialLocation: AppRoutes.login, // Start at login to avoid initial redirect
    debugLogDiagnostics: false, // Set to false to reduce console noise
    redirect: (context, state) async {
      final location = state.uri.toString();
      
      // Routes that don't require authentication
      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.verifyPhone,
        AppRoutes.forgotPin,
        AppRoutes.biometricSetup,
      ];
      
      // If navigating to a public route, allow it immediately
      if (publicRoutes.contains(location)) {
        return null;
      }
      
      // For protected routes, check session
      try {
        final sessionState = await sessionStateNotifier.getOrRefreshSessionState();
        
        final isAuthenticated = sessionState.isAuthenticated;
        final isSessionValid = sessionState.isSessionValid;
        final hasBiometric = sessionState.hasBiometric;
        
        // If user is not authenticated and trying to access protected route
        if (!isAuthenticated || !isSessionValid) {
          return AppRoutes.login;
        }
        
        // Root path redirect
        if (location == AppRoutes.root) {
          return AppRoutes.dashboard;
        }
        
        // ========== TEMPORARILY BYPASS BIOMETRIC CHECK ==========
        // Commented out until biometric is properly implemented
        /*
        // Check biometric requirement for sensitive routes
        final sensitiveRoutes = [AppRoutes.wallet, AppRoutes.topUp, AppRoutes.transactionHistory];
        if (sensitiveRoutes.contains(location) && !hasBiometric) {
          return AppRoutes.biometricSetup;
        }
        */
        
        return null;
      } catch (e) {
        debugPrint('Router redirect error: $e');
        // On error, redirect to login
        return AppRoutes.login;
      }
    },
    routes: [
      // ========== AUTHENTICATION ROUTES ==========
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: AppTransitions.fadeTransition,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 400),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.verifyPhone,
        name: 'verifyPhone',
        pageBuilder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: VerifyPhoneScreen(phone: phone, token: token),
            transitionsBuilder: AppTransitions.fadeTransition,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.forgotPin,
        name: 'forgotPin',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const ForgotPinScreen(),
            transitionsBuilder: AppTransitions.fadeTransition,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.biometricSetup,
        name: 'biometricSetup',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const BiometricSetupScreen(),
            transitionsBuilder: AppTransitions.scaleTransition,
            transitionDuration: const Duration(milliseconds: 500),
          );
        },
      ),
      
      // ========== MAIN APP ROUTES ==========
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return child;
            },
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const WalletScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.topUp,
        name: 'topUp',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const TopUpScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      // ========== TRANSACTION ROUTES ==========
      GoRoute(
        path: AppRoutes.airtime,
        name: 'airtime',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const AirtimeScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.data,
        name: 'data',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const DataScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.sms,
        name: 'sms',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const SMSScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.transactionHistory,
        name: 'transactionHistory',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const TransactionHistoryScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      // ========== NEW FEATURE ROUTES ==========
      GoRoute(
        path: AppRoutes.offers,
        name: 'offers',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const OffersScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.customers,
        name: 'customers',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const CustomersScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const ReportsScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.help,
        name: 'help',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const HelpScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      // ========== SETTINGS AND PROFILE ==========
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: const Center(
                child: Text('Profile Screen - To be implemented'),
              ),
            ),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
    ],
    
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'The requested page could not be found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to Dashboard'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

/// Extension methods for easier navigation
extension GoRouterExtension on BuildContext {
  // Auth navigation
  void goToLogin() => go(AppRoutes.login);
  void goToRegister() => go(AppRoutes.register);
  void goToVerifyPhone({String? phone, String? token}) => go('${AppRoutes.verifyPhone}?phone=${phone ?? ''}&token=${token ?? ''}');
  void goToForgotPin() => go(AppRoutes.forgotPin);
  void goToBiometricSetup() => go(AppRoutes.biometricSetup);
  
  // Main app navigation
  void goToDashboard() => go(AppRoutes.dashboard);
  void goToWallet() => go(AppRoutes.wallet);
  void goToTopUp() => go(AppRoutes.topUp);
  void goToAirtime() => go(AppRoutes.airtime);
  void goToData() => go(AppRoutes.data);
  void goToSMS() => go(AppRoutes.sms);
  void goToTransactionHistory() => go(AppRoutes.transactionHistory);
  void goToSettings() => go(AppRoutes.settings);
  void goToProfile() => go(AppRoutes.profile);
  
  // ========== NEW NAVIGATION METHODS ==========
  void goToOffers() => go(AppRoutes.offers);
  void goToCustomers() => go(AppRoutes.customers);
  void goToReports() => go(AppRoutes.reports);
  void goToHelp() => go(AppRoutes.help);
  
  // Replace navigation (no back button)
  void replaceWithDashboard() => go(AppRoutes.dashboard);
  void replaceWithLogin() => go(AppRoutes.login);
  
  // Deep linking helpers
  void goToTransactionDetails(String transactionId) {
    go('/transaction/$transactionId');
  }
}

/// Route observer for analytics
class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange('Pushed', route.settings.name);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange('Popped', route.settings.name);
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRouteChange('Replaced', newRoute?.settings.name);
  }
  
  void _logRouteChange(String action, String? routeName) {
    debugPrint('Route $action: $routeName');
  }
}