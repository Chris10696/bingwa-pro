import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../errors/exceptions.dart';

class DeviceFingerprint {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  static Future<String> generateDeviceId() async {
    try {
      final deviceData = await _getDeviceData();
      final packageInfo = await PackageInfo.fromPlatform();
      
      // Combine device data
      final fingerprintData = {
        'device': deviceData,
        'app': {
          'packageName': packageInfo.packageName,
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Create hash
      final jsonString = jsonEncode(fingerprintData);
      final bytes = utf8.encode(jsonString);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      throw StorageException('Failed to generate device ID: $e');
    }
  }
  
  static Future<Map<String, dynamic>> _getDeviceData() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'device': androidInfo.device,
        'product': androidInfo.product,
        'board': androidInfo.board,
        'hardware': androidInfo.hardware,
        'androidId': androidInfo.id,
        'manufacturer': androidInfo.manufacturer,
        'version': {
          'sdkInt': androidInfo.version.sdkInt,
          'release': androidInfo.version.release,
          'previewSdkInt': androidInfo.version.previewSdkInt,
          'incremental': androidInfo.version.incremental,
          'codename': androidInfo.version.codename,
        },
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
        'systemFeatures': androidInfo.systemFeatures,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'name': iosInfo.name,
        'model': iosInfo.model,
        'systemName': iosInfo.systemName,
        'systemVersion': iosInfo.systemVersion,
        'utsname': {
          'sysname': iosInfo.utsname.sysname,
          'nodename': iosInfo.utsname.nodename,
          'release': iosInfo.utsname.release,
          'version': iosInfo.utsname.version,
          'machine': iosInfo.utsname.machine,
        },
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
      };
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
  
  static Future<bool> isDeviceRooted() async {
    if (Platform.isAndroid) {
      try {
        // Check for common root indicators
        final buildTags = await _deviceInfo.androidInfo
            .then((info) => info.tags.toLowerCase());
        
        const rootIndicators = [
          'test-keys',
          'debug',
          'eng.',
          'userdebug',
        ];
        
        for (final indicator in rootIndicators) {
          if (buildTags.contains(indicator)) {
            return true;
          }
        }
        
        // Check for Superuser/SuperSU
        final suExists = await File('/system/app/Superuser.apk').exists() ||
            await File('/system/bin/su').exists() ||
            await File('/system/xbin/su').exists() ||
            await File('/sbin/su').exists() ||
            await File('/system/su').exists() ||
            await File('/system/bin/.ext/.su').exists() ||
            await File('/system/usr/we-need-root/su-backup').exists() ||
            await File('/system/xbin/mu').exists();
        
        return suExists;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
  
  static Future<bool> isEmulator() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }
    return false;
  }
  
  static Future<String> getPlatformVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.release;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.systemVersion;
    }
    return 'Unknown';
  }
}