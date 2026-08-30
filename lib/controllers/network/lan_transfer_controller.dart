import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../utils/data_structures/transfer_models.dart';
import '../../utils/device_info.dart';

class LanTransferController extends ChangeNotifier {
  static const String _serviceType = '_mp-transfer._tcp';

  HttpServer? _server;
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;

  final List<NearbyDevice> discoveredDevices = [];
  bool isServerRunning = false;
  bool isSearching = false;
  String? _currentDeviceName;

  // --- Receiver Progress & State Properties ---
  bool isReceiving = false;
  double incomingProgress = 0.0; // 0.0 to 1.0
  String incomingSpeedText = '';
  final List<String> receivedFiles = [];

  // Callback to prompt UI with metadata list for user consent
  Future<bool> Function(TransferBatchRequest request)? onRequestReceived;
  // Callback when a track stream finishes writing to disk
  Function(String savedFilePath)? onTrackReceived;


  Future<void> initService() async {
    final deviceName = await getDeviceName();
    await _startService(deviceName: deviceName);
  }

  Future<void> _startService({required String deviceName, int port = 8080}) async {
    debugPrint('[LanTransferController] Starting LAN Transfer Service for "$deviceName" on port $port...');
    await _startHttpServer(port);
    await _registerMDNSService(deviceName, port);
    await startDeviceDiscovery();
    debugPrint('[LanTransferController] Service startup complete.');
  }

  /// Helper to extract real client IP from shelf IO connection info
  String _getClientIp(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final clientIp = connectionInfo?.remoteAddress.address;
    if (clientIp != null && clientIp.isNotEmpty) {
      return clientIp;
    }
    return request.requestedUri.host;
  }

  Future<void> _startHttpServer(int port) async {
    final router = Router();

    // 1. Handshake Phase: Receiver gets metadata list & asks user for approval
    router.post('/request-transfer', (shelf.Request request) async {
      final clientIp = _getClientIp(request);
      debugPrint('[LanTransferController] [HTTP] Received /request-transfer from IP: $clientIp');

      try {
        final bodyText = await request.readAsString();
        final body = jsonDecode(bodyText) as Map<String, dynamic>;

        final sender = NearbyDevice(
          id: clientIp,
          name: body['senderName'] as String? ?? 'Unknown Device',
          ip: clientIp,
          port: port,
        );

        final tracksRaw = body['tracks'] as List<dynamic>;
        final tracks = tracksRaw
            .map((t) => TransferTrackInfo.fromJson(t as Map<String, dynamic>))
            .toList();

        debugPrint('[LanTransferController] [HTTP] Parsed Handshake request from "${sender.name}" ($clientIp) with ${tracks.length} track(s)');

        final batchRequest = TransferBatchRequest(sender: sender, tracks: tracks);

        bool accepted = false;
        if (onRequestReceived != null) {
          debugPrint('[LanTransferController] [HTTP] Prompting user consent via onRequestReceived callback...');
          accepted = await onRequestReceived!(batchRequest);
        } else {
          debugPrint('[LanTransferController] [HTTP] Warning: onRequestReceived callback is null! Automatically returning false.');
        }

        debugPrint('[LanTransferController] [HTTP] Sending response back to $clientIp: accepted = $accepted');
        return shelf.Response.ok(
          jsonEncode({'accepted': accepted}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e, stackTrace) {
        debugPrint('[LanTransferController] [HTTP] Error processing /request-transfer payload: $e\n$stackTrace');
        return shelf.Response.badRequest(body: jsonEncode({'accepted': false, 'error': e.toString()}));
      }
    });

    // 2. Binary Stream Phase: Receives chunked Multipart data streams directly to disk
    router.post('/stream-transfer', (shelf.Request request) async {
      final clientIp = _getClientIp(request);
      debugPrint('[LanTransferController] [HTTP] Incoming /stream-transfer connection from IP: $clientIp');

      if (request.multipart() case var multipart?) {
        final tempDir = Directory.systemTemp;
        int receivedCount = 0;

        // Reset receiving metrics
        isReceiving = true;
        incomingProgress = 0.0;
        incomingSpeedText = '0 KB/s';
        notifyListeners();

        final contentLengthHeader = request.headers['content-length'];
        final totalExpectedBytes = contentLengthHeader != null
            ? int.tryParse(contentLengthHeader) ?? 0
            : 0;

        int totalBytesRead = 0;
        final startTime = DateTime.now().millisecondsSinceEpoch;

        try {
          await for (final part in multipart.parts) {
            // Look up content-disposition key case-insensitively
            final contentDispositionKey = part.headers.keys.firstWhere(
                  (k) => k.toLowerCase() == 'content-disposition',
              orElse: () => '',
            );
            final contentDisposition = part.headers[contentDispositionKey];

            String filename = 'track_${DateTime.now().millisecondsSinceEpoch}_$receivedCount.mp3';

            if (contentDisposition != null) {
              final match = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
                  .firstMatch(contentDisposition);
              if (match != null && match.group(1) != null) {
                filename = match.group(1)!.trim();
              }
            }

            final savePath = path.join(tempDir.path, filename);
            final saveFile = File(savePath);
            debugPrint('[LanTransferController] [HTTP] Streaming part to file: $savePath');

            final sink = saveFile.openWrite();

            await for (final chunk in part) {
              sink.add(chunk);
              totalBytesRead += chunk.length;

              final elapsedSec = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000.0;
              final speedBytesPerSec = elapsedSec > 0 ? totalBytesRead / elapsedSec : 0.0;

              final speedMb = speedBytesPerSec / (1024 * 1024);
              if (speedMb >= 1.0) {
                incomingSpeedText = '${speedMb.toStringAsFixed(1)} MB/s';
              } else {
                final speedKb = speedBytesPerSec / 1024;
                incomingSpeedText = '${speedKb.toStringAsFixed(0)} KB/s';
              }

              if (totalExpectedBytes > 0) {
                incomingProgress = (totalBytesRead / totalExpectedBytes).clamp(0.0, 1.0);
              }

              notifyListeners();
            }

            await sink.flush();
            await sink.close();

            receivedCount++;
            receivedFiles.add(saveFile.path);
            debugPrint('[LanTransferController] [HTTP] File saved successfully ($receivedCount count): $savePath');

            if (onTrackReceived != null) {
              await onTrackReceived!(saveFile.path);
            }
          }
        } finally {
          isReceiving = false;
          incomingProgress = 1.0;
          incomingSpeedText = '';
          notifyListeners();
        }

        debugPrint('[LanTransferController] [HTTP] Completed /stream-transfer batch with $receivedCount track(s).');
        return shelf.Response.ok(
          jsonEncode({
            'status': 'success',
            'receivedCount': receivedCount,
          }),
          headers: {'content-type': 'application/json'},
        );
      } else {
        debugPrint('[LanTransferController] [HTTP] Error: Non-multipart payload received on /stream-transfer from $clientIp');
        return shelf.Response.badRequest(body: 'Multipart request required.');
      }
    });

    try {
      _server = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      isServerRunning = true;
      debugPrint('[LanTransferController] HTTP Server successfully listening on http://0.0.0.0:${_server!.port}');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[LanTransferController] Failed to bind HTTP Server on port $port: $e\n$stackTrace');
    }
  }

  // --- Client Operations ---

  Future<bool> sendBatchTracks({
    required NearbyDevice target,
    required List<TransferTrackInfo> trackMetadatas,
    required List<String> filePaths,
    required String myDeviceName,
    TransferProgressCallback? onProgress,
  }) async {
    debugPrint('[LanTransferController] Starting batch upload to "${target.name}" (${target.ip}:${target.port}). Target tracks: ${trackMetadatas.length}');
    try {
      // Step A: Handshake Request
      final handshakeUri = Uri.parse('http://${target.ip}:${target.port}/request-transfer');
      final handshakeResponse = await http.post(
        handshakeUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': myDeviceName,
          'tracks': trackMetadatas.map((t) => t.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (handshakeResponse.statusCode != 200) return false;

      final handshakeResult = jsonDecode(handshakeResponse.body) as Map<String, dynamic>;
      if (!(handshakeResult['accepted'] as bool? ?? false)) return false;

      // Step B: Calculate total bytes for progress
      int totalBytes = 0;
      final existingFiles = <File>[];
      for (final p in filePaths) {
        final f = File(p);
        if (await f.exists()) {
          totalBytes += await f.length();
          existingFiles.add(f);
        }
      }

      // Step C: Multipart Request
      final streamUri = Uri.parse('http://${target.ip}:${target.port}/stream-transfer');
      final multipartRequest = http.MultipartRequest('POST', streamUri);

      for (final file in existingFiles) {
        multipartRequest.files.add(
          await http.MultipartFile.fromPath('files', file.path),
        );
      }

      // Step D: Stream payload and track sent byte progress
      final startTime = DateTime.now().millisecondsSinceEpoch;
      int bytesSentAcc = 0;

      final byteStream = multipartRequest.finalize();
      final totalPayloadLength = multipartRequest.contentLength;

      final request = await HttpClient().postUrl(streamUri);
      if (multipartRequest.headers['content-type'] != null) {
        request.headers.contentType =
            ContentType.parse(multipartRequest.headers['content-type']!);
      }

      multipartRequest.headers.forEach((k, v) => request.headers.set(k, v));

      await request.addStream(byteStream.map((chunk) {
        bytesSentAcc += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsedSeconds = (now - startTime) / 1000.0;
        final speed = elapsedSeconds > 0 ? (bytesSentAcc / elapsedSeconds) : 0.0;

        if (onProgress != null) {
          onProgress(
            bytesSentAcc,
            totalPayloadLength > 0 ? totalPayloadLength : totalBytes,
            speed,
          );
        }
        return chunk;
      }));

      final httpResponse = await request.close();
      return httpResponse.statusCode == 200;
    } catch (e, stackTrace) {
      debugPrint('[LanTransferController] Error sending batch tracks: $e\n$stackTrace');
      return false;
    }
  }

  // --- mDNS Discovery ---

  Future<void> _registerMDNSService(String deviceName, int port) async {
    _currentDeviceName = deviceName;
    debugPrint('[LanTransferController] [mDNS] Registering mDNS service: "$deviceName" ($_serviceType) on port $port');
    try {
      _registration = await nsd.register(
        nsd.Service(name: deviceName, type: _serviceType, port: port),
      );
      debugPrint('[LanTransferController] [mDNS] Service successfully registered as "$deviceName".');
    } catch (e, stackTrace) {
      debugPrint('[LanTransferController] [mDNS] Registration failed: $e\n$stackTrace');
    }
  }

  Future<void> startDeviceDiscovery() async {
    if (isSearching) {
      debugPrint('[LanTransferController] [mDNS] Discovery already running. Skipping request.');
      return;
    }

    discoveredDevices.clear();
    isSearching = true;
    notifyListeners();
    debugPrint('[LanTransferController] [mDNS] Starting mDNS device discovery for type $_serviceType...');

    // 1. Gather all local IPv4 addresses of the current device to exclude self-discovery
    final Set<String> localIps = {};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          localIps.add(addr.address);
        }
      }
    } catch (e) {
      debugPrint('[LanTransferController] Error retrieving local network interfaces: $e');
    }

    try {
      _discovery = await nsd.startDiscovery(_serviceType, ipLookupType: nsd.IpLookupType.v4);
      _discovery?.addListener(() {
        final Map<String, NearbyDevice> uniqueDevices = {};

        for (final service in _discovery!.services) {
          final serviceName = service.name;

          // Exclude services without valid names or missing port configurations
          if (serviceName == null || service.port == null || service.port == 0) {
            continue;
          }

          // Extract non-loopback IPv4 addresses
          final validIpv4s = service.addresses
              ?.where((addr) => addr.type == InternetAddressType.IPv4)
              .map((addr) => addr.address)
              .where((ip) => !ip.startsWith('127.'))
              .toList() ??
              [];

          // Priority 1: Private LAN Subnets
          String? chosenIp = validIpv4s.firstWhere(
                (ip) =>
            ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(ip),
            orElse: () => '',
          );

          // Priority 2: Other valid IPv4s
          if (chosenIp.isEmpty && validIpv4s.isNotEmpty) {
            chosenIp = validIpv4s.first;
          }

          // Priority 3: Fallback to host address
          if (chosenIp.isEmpty && service.host != null && service.host != 'localhost') {
            chosenIp = service.host;
          }

          // Exclude invalid/empty IP addresses
          if (chosenIp == null || chosenIp.isEmpty) {
            continue;
          }

          // 2. Ignore self by matching against both device name and local IP addresses
          final isSelfByName = _currentDeviceName != null &&
              (serviceName == _currentDeviceName || serviceName.startsWith('$_currentDeviceName ('));
          final isSelfByIp = localIps.contains(chosenIp);

          if (isSelfByName || isSelfByIp) {
            continue;
          }

          final device = NearbyDevice(
            id: serviceName,
            name: serviceName,
            ip: chosenIp,
            port: service.port!,
          );
          uniqueDevices[device.id] = device;
        }

        discoveredDevices.clear();
        discoveredDevices.addAll(uniqueDevices.values);
        debugPrint('[LanTransferController] [mDNS] Discovered devices updated: '
            '${discoveredDevices.map((d) => "${d.name} (${d.ip}:${d.port})").toList()}');
        notifyListeners();
      });
    } catch (e, stackTrace) {
      debugPrint('[LanTransferController] [mDNS] Device discovery failed: $e\n$stackTrace');
    }
  }

  Future<void> stopService() async {
    debugPrint('[LanTransferController] Stopping LAN Transfer Service...');

    if (_registration != null) {
      debugPrint('[LanTransferController] [mDNS] Unregistering mDNS service...');
      await nsd.unregister(_registration!);
    }

    if (_discovery != null) {
      debugPrint('[LanTransferController] [mDNS] Stopping mDNS discovery...');
      await nsd.stopDiscovery(_discovery!);
    }

    if (_server != null) {
      debugPrint('[LanTransferController] Closing HTTP Server...');
      await _server?.close(force: true);
    }

    _registration = null;
    _discovery = null;
    _server = null;
    isServerRunning = false;
    isSearching = false;
    isReceiving = false;
    incomingProgress = 0.0;
    incomingSpeedText = '';
    discoveredDevices.clear();
    receivedFiles.clear();

    notifyListeners();
    debugPrint('[LanTransferController] LAN Transfer Service fully stopped.');
  }

  @override
  void dispose() {
    debugPrint('[LanTransferController] Disposing LanTransferController instance.');
    stopService();
    super.dispose();
  }
}
