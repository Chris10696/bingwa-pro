// lib/app_router.dart
// W1 edits:
//   - Dropped imports of airtime_screen, data_screen, sms_screen
//   - Removed AppRoutes.airtime, AppRoutes.data, AppRoutes.sms constants
//   - Removed /airtime, /data, /sms GoRoute blocks
//   - Removed goToAirtime, goToData, goToSMS extension methods
// Every surviving route still resolves to a present screen.
import 'package:bingwa_pro/core/security/secure_storage_manager.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/biometric_setup_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/forgot_pin_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/login_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/register_screen.dart';
import 'package:bingwa_pro/features/auth/presentation/screens/verify_phone_screen.dart';
import 'package:bingwa_pro/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bingwa_pro/features/settings/presentation/screens/settings_screen.dart';
import 'package:bingwa_pro/features/transactions/presentation/screens/transaction_history_screen.dart';
import 'package:bingwa_pro/features/wallet/presentation/screens/redeem_coupon_screen.dart';
import 'package:bingwa_pro/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:bingwa_pro/features/offers/presentation/screens/offers_screen.dart';
import 'package:bingwa_pro/features/customers/presentation/screens/customers_screen.dart';
import 'package:bingwa_pro/features/reports/presentation/screens/reports_screen.dart';
import 'package:bingwa_pro/features/help/presentation/screens/help_screen.dart';
import 'package:bingwa_pro/features/quick_dial/presentation/screens/quick_dial_screen.dart';
import 'package:bingwa_pro/features/auto_renewals/presentation/screens/auto_renewals_screen.dart';
import 'package:bingwa_pro/features/sitelink/presentation/screens/sitelink_screen.dart';
import 'package:bingwa_pro/features/auto_reply/presentation/screens/auto_reply_screen.dart';
import 'package:bingwa_pro/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:bingwa_pro/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/auth/auth_state_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route path constants
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  static const String walletTopUp = '/wallet/topup';
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
  static const String redeemCoupon = '/redeem-coupon';
  // W1: airtime, data, sms route constants removed (screens deleted)
  static const String transactionHistory = '/transaction-history';
  static const String settings = '/settings';
  static const String profile = '/profile';
  // Feature routes
  static const String offers = '/offers';
  static const String customers = '/customers';
  static const String reports = '/reports';
  static const String help = '/help';
  static const String customerDetail = '/customers/:id';
  static const String quickDial = '/quick-dial';
  static const String autoRenewals = '/auto-renewals';
  static const String siteLink = '/sitelink';
  static const String autoReply = '/auto-reply';
  // Settings sub-routes
  static const String editProfile = '/settings/profile';
  // Root
  static const String root = '/';
}

class AppTransitions {
  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;
    final tween =
        Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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

final secureStorageManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final initialLocation =
      authState.isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: authState,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final location = state.uri.toString();
      const publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.verifyPhone,
        AppRoutes.forgotPin,
        AppRoutes.biometricSetup,
      ];
      final isOnPublicRoute = publicRoutes.contains(location);

      if (!isAuthenticated && !isOnPublicRoute) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isOnPublicRoute) {
        return AppRoutes.dashboard;
      }
      if (location == AppRoutes.root) {
        return isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;
      }
      return null;
    },

    routes: [
      // ======================================================================
      // AUTH ROUTES
      // ======================================================================
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: AppTransitions.fadeTransition,
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 400),
        ),
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
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ForgotPinScreen(),
          transitionsBuilder: AppTransitions.fadeTransition,
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: AppRoutes.biometricSetup,
        name: 'biometricSetup',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const BiometricSetupScreen(),
          transitionsBuilder: AppTransitions.scaleTransition,
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),

      // ======================================================================
      // MAIN APP ROUTES
      // ======================================================================
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const DashboardScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) => child,
        ),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const WalletScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.redeemCoupon,
        name: 'redeemCoupon',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RedeemCouponScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      // W2.4A: topup merged into wallet — these paths now alias to /wallet so
      // any lingering goToTopUp()/push('/top-up') calls land on the wallet
      // screen. TopUpScreen is deleted.
      GoRoute(
        path: AppRoutes.topUp,
        redirect: (context, state) => AppRoutes.wallet,
      ),
      GoRoute(
        path: AppRoutes.walletTopUp,
        redirect: (context, state) => AppRoutes.wallet,
      ),

      // ======================================================================
      // TRANSACTION ROUTES
      // W1: /airtime, /data, /sms routes removed (screens deleted)
      // ======================================================================
      GoRoute(
        path: AppRoutes.transactionHistory,
        name: 'transactionHistory',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const TransactionHistoryScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),

      // ======================================================================
      // OFFERS, CUSTOMERS, REPORTS, HELP
      // ======================================================================
      GoRoute(
        path: AppRoutes.offers,
        name: 'offers',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const OffersScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.customers,
        name: 'customers',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const CustomersScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerDetail,
        name: 'customerDetail',
        pageBuilder: (context, state) {
          final customerId = state.pathParameters['id'] ?? '';
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: CustomerDetailScreen(customerId: customerId),
            transitionsBuilder: AppTransitions.slideTransition,
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ReportsScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        name: 'help',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const HelpScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),

      // ======================================================================
      // FEATURE ROUTES
      // ======================================================================
      GoRoute(
        path: AppRoutes.quickDial,
        name: 'quickDial',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const QuickDialScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.autoRenewals,
        name: 'autoRenewals',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AutoRenewalsScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.siteLink,
        name: 'siteLink',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SiteLinkScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.autoReply,
        name: 'autoReply',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AutoReplyScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),

      // ======================================================================
      // SETTINGS AND PROFILE
      // ======================================================================
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const EditProfileScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'editProfile',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const EditProfileScreen(),
          transitionsBuilder: AppTransitions.slideTransition,
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

// ─────────────────────────────────────────────────────────────────────────────
// Convenience extension on BuildContext
// W1: goToAirtime, goToData, goToSMS methods removed (routes deleted).
// ─────────────────────────────────────────────────────────────────────────────

extension GoRouterExtension on BuildContext {
  void goToLogin() => go(AppRoutes.login);
  void goToRegister() => go(AppRoutes.register);
  void goToVerifyPhone({String? phone, String? token}) =>
      go('${AppRoutes.verifyPhone}?phone=${phone ?? ''}&token=${token ?? ''}');
  void goToForgotPin() => go(AppRoutes.forgotPin);
  void goToBiometricSetup() => go(AppRoutes.biometricSetup);
  void goToDashboard() => go(AppRoutes.dashboard);
  void goToWallet() => go(AppRoutes.wallet);
  void goToTopUp() => go(AppRoutes.topUp);
  void goToRedeemCoupon() => go(AppRoutes.redeemCoupon);
  void goToTransactionHistory() => go(AppRoutes.transactionHistory);
  void goToSettings() => go(AppRoutes.settings);
  void goToProfile() => go(AppRoutes.profile);
  void goToEditProfile() => go(AppRoutes.editProfile);
  void goToOffers() => go(AppRoutes.offers);
  void goToCustomers() => go(AppRoutes.customers);
  void goToCustomerDetails(String customerId) => go('/customers/$customerId');
  void goToReports() => go(AppRoutes.reports);
  void goToHelp() => go(AppRoutes.help);
  void goToQuickDial() => go(AppRoutes.quickDial);
  void goToAutoRenewals() => go(AppRoutes.autoRenewals);
  void goToSiteLink() => go(AppRoutes.siteLink);
  void goToAutoReply() => go(AppRoutes.autoReply);
  void replaceWithDashboard() => go(AppRoutes.dashboard);
  void replaceWithLogin() => go(AppRoutes.login);
  void goToTransactionDetails(String transactionId) =>
      go('/transaction/$transactionId');
}

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