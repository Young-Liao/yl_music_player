import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getDeviceName() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  try {
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.name; // e.g. "Young's iPhone"
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      return macInfo.computerName; // e.g. "Young's MacBook Pro"
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // Android requires model/device fallback if device name is unavailable
      return androidInfo.model;
    }
  } catch (e) {
    // Fallback to cleaned local hostname if device info fails
  }

  String host = Platform.localHostname;
  if (host.endsWith('.local')) {
    host = host.substring(0, host.length - 6);
  }
  return host.replaceAll('-', ' ');
}