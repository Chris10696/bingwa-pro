// lib/features/app_update/presentation/providers/app_update_provider.dart
// W5.H — CheckForUpdates state. Compares the installed versionCode (package_info_plus) with
// the advertised latest, and drives the native installer (bingwa_pro/update channel).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:bingwa_nexus/shared/models/app_update_model.dart';
import 'package:bingwa_nexus/shared/repositories/app_update_repository.dart';

@immutable
class AppUpdateState {
  final bool isChecking;
  final bool isDownloading;
  final String currentVersion;
  final int currentVersionCode;
  final AppUpdateInfo? latest;
  final String? error;

  const AppUpdateState({
    this.isChecking = false,
    this.isDownloading = false,
    this.currentVersion = '',
    this.currentVersionCode = 0,
    this.latest,
    this.error,
  });

  bool get updateAvailable =>
      latest != null &&
      latest!.hasApk &&
      latest!.latestVersionCode > currentVersionCode;

  AppUpdateState copyWith({
    bool? isChecking,
    bool? isDownloading,
    String? currentVersion,
    int? currentVersionCode,
    AppUpdateInfo? latest,
    String? error,
  }) {
    return AppUpdateState(
      isChecking: isChecking ?? this.isChecking,
      isDownloading: isDownloading ?? this.isDownloading,
      currentVersion: currentVersion ?? this.currentVersion,
      currentVersionCode: currentVersionCode ?? this.currentVersionCode,
      latest: latest ?? this.latest,
      error: error,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier(this._repo) : super(const AppUpdateState()) {
    checkForUpdate();
  }

  final AppUpdateRepository _repo;
  static const MethodChannel _channel = MethodChannel('bingwa_pro/update');

  Future<void> checkForUpdate() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber) ?? 0;
      final latest = await _repo.getLatest();
      state = state.copyWith(
        isChecking: false,
        currentVersion: info.version,
        currentVersionCode: code,
        latest: latest,
      );
    } catch (e) {
      state = state.copyWith(isChecking: false, error: _clean(e));
    }
  }

  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallUnknownSources') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  /// Hand the APK URL to the native DownloadManager → it downloads + prompts to install.
  Future<void> install() async {
    final latest = state.latest;
    if (latest == null || !latest.hasApk) return;
    state = state.copyWith(isDownloading: true, error: null);
    try {
      await _channel
          .invokeMethod('downloadAndInstall', {'apkUrl': latest.apkUrl});
      state = state.copyWith(isDownloading: false);
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: _clean(e));
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}

final appUpdateProvider =
    StateNotifierProvider.autoDispose<AppUpdateNotifier, AppUpdateState>((ref) {
  return AppUpdateNotifier(ref.watch(appUpdateRepositoryProvider));
});
