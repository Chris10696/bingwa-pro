// lib/shared/models/app_update_model.dart
// W5.H — latest-version metadata from GET /app-update/latest.
class AppUpdateInfo {
  final String latestVersion;
  final int latestVersionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool forced;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forced,
  });

  bool get hasApk => apkUrl.isNotEmpty;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> j) => AppUpdateInfo(
        latestVersion: j['latestVersion'] as String? ?? '',
        latestVersionCode: (j['latestVersionCode'] as num?)?.toInt() ?? 0,
        apkUrl: j['apkUrl'] as String? ?? '',
        releaseNotes: j['releaseNotes'] as String? ?? '',
        forced: j['forced'] as bool? ?? false,
      );
}
