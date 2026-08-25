import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

class NearbyDevice {
  final String id;
  final String name;
  final String ip;
  final int port;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
  });
}

class LanTransferController extends ChangeNotifier {
  static const String _serviceType = '_mp-transfer._tcp';

  HttpServer? _server;
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;

  final List<NearbyDevice> discoveredDevices = [];
  bool isServerRunning = false;
  bool isSearching = false;

  Function(NearbyDevice sender, String fileName, double fileSize, List<int> rawBytes)? onReceiveRequest;

  Future<void> startService({required String deviceName, int port = 8080}) async {
    await _startHttpServer(port);
    await _registerMDNSService(deviceName, port);
    await startDeviceDiscovery();
  }

  Future<void> _startHttpServer(int port) async {
    final router = Router();

    router.post('/transfer', (shelf.Request request) async {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      final String senderName = data['senderName'] ?? 'Unknown';
      final String fileName = data['fileName'];
      final double fileSize = (data['fileSize'] as num).toDouble();
      final List<int> rawBytes = base64Decode(data['bytes']);

      final sender = NearbyDevice(
        id: request.requestedUri.host,
        name: senderName,
        ip: request.requestedUri.host,
        port: port,
      );

      onReceiveRequest?.call(sender, fileName, fileSize, rawBytes);

      return shelf.Response.ok(jsonEncode({'status': 'received'}));
    });

    try {
      _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, port);
      isServerRunning = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to bind HTTP Server: $e');
    }
  }

  Future<void> _registerMDNSService(String deviceName, int port) async {
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: _serviceType,
          port: port,
        ),
      );
    } catch (e) {
      debugPrint('mDNS Registration failed: $e');
    }
  }

  Future<void> startDeviceDiscovery() async {
    if (isSearching) return;

    discoveredDevices.clear();
    isSearching = true;
    notifyListeners();

    try {
      // Set ipLookupType to resolve host IP addresses
      _discovery = await nsd.startDiscovery(
        _serviceType,
        ipLookupType: nsd.IpLookupType.any,
      );

      _discovery?.addListener(() {
        for (final service in _discovery!.services) {
          final host = service.addresses?.firstOrNull?.address ?? service.host;
          if (service.name != null && host != null) {
            final device = NearbyDevice(
              id: service.name!,
              name: service.name!,
              ip: host,
              port: service.port ?? 8080,
            );

            if (!discoveredDevices.any((d) => d.id == device.id)) {
              discoveredDevices.add(device);
              notifyListeners();
            }
          }
        }
      });
    } catch (e) {
      debugPrint('mDNS Discovery failed: $e');
    }
  }

  Future<bool> sendFile({
    required NearbyDevice target,
    required String filePath,
    required String myDeviceName,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final bytes = await file.readAsBytes();
    final fileName = filePath.split('/').last;

    try {
      final uri = Uri.parse('http://${target.ip}:${target.port}/transfer');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': myDeviceName,
          'fileName': fileName,
          'fileSize': bytes.length,
          'bytes': base64Encode(bytes),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending file: $e');
      return false;
    }
  }

  Future<void> stopService() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    await _server?.close(force: true);

    isServerRunning = false;
    isSearching = false;
    discoveredDevices.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopService();
    super.dispose();
  }
}
