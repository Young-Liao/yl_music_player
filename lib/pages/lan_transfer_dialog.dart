import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../controllers/song_list/song_list_managers.dart';
import '../main.dart';
import '../themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';
import '../utils/data_structures/transfer_models.dart';
import '../utils/device_info.dart';

class LanTransferDialog extends StatefulWidget {
  final List<String> selectedPaths;

  const LanTransferDialog({
    super.key,
    required this.selectedPaths,
  });

  static Future<void> show(
      BuildContext context,
      List<String> selectedPaths,
      ) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LanTransferDialog(
        selectedPaths: selectedPaths,
      ),
    );
  }

  @override
  State<LanTransferDialog> createState() => _LanTransferDialogState();
}

class _LanTransferDialogState extends State<LanTransferDialog>
    with SingleTickerProviderStateMixin {
  late final SongListManager _songListManager;

  // Track outgoing transfer states per device ID
  final Map<String, String> _statusMessages = {};
  final Map<String, double> _transferProgress = {}; // 0.0 to 1.0
  final Map<String, String> _transferSpeedText = {};

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _songListManager = SongListManager(db: null);
    lanTransferController.addListener(_onControllerUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    lanTransferController.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _handleSendToDevice(NearbyDevice device) async {
    if (widget.selectedPaths.isEmpty) return;

    setState(() {
      _statusMessages[device.id] = 'Parsing metadata...';
      _transferProgress[device.id] = 0.0;
      _transferSpeedText[device.id] = '';
    });

    final List<TransferTrackInfo> metadatas = [];

    for (int i = 0; i < widget.selectedPaths.length; i++) {
      final p = widget.selectedPaths[i];

      var cached = _songListManager.peekCache(p);
      if (cached == null) {
        cached = await _songListManager.extractMetadata(p);
        _songListManager.putToCache(p, cached);
      }

      metadatas.add(TransferTrackInfo(
        id: 'track_$i',
        fileName: path.basename(p),
        title: cached.title,
        artist: cached.artist,
        fileSize: cached.getFileSize(),
        artworkBytes: cached.compressedArtwork,
      ));
    }

    setState(() {
      _statusMessages[device.id] = 'Waiting for acceptance...';
    });

    final success = await lanTransferController.sendBatchTracks(
      target: device,
      trackMetadatas: metadatas,
      filePaths: widget.selectedPaths,
      myDeviceName: await getDeviceName(),
      onProgress: (sentBytes, totalBytes, speedBytesPerSec) {
        if (!mounted) return;
        setState(() {
          final progress = totalBytes > 0 ? sentBytes / totalBytes : 0.0;
          _transferProgress[device.id] = progress.clamp(0.0, 1.0);

          final speedMb = speedBytesPerSec / (1024 * 1024);
          if (speedMb >= 1.0) {
            _transferSpeedText[device.id] =
            '${speedMb.toStringAsFixed(1)} MB/s';
          } else {
            final speedKb = speedBytesPerSec / 1024;
            _transferSpeedText[device.id] =
            '${speedKb.toStringAsFixed(0)} KB/s';
          }

          _statusMessages[device.id] =
          'Sending (${(progress * 100).toInt()}%)';
        });
      },
    );

    if (mounted) {
      setState(() {
        _transferProgress[device.id] = success ? 1.0 : 0.0;
        _transferSpeedText[device.id] = '';
        _statusMessages[device.id] =
        success ? 'Sent Successfully!' : 'Declined or Failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final devices = lanTransferController.discoveredDevices;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
      ),
      backgroundColor: theme.cardBackgroundColor,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.air_rounded,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Share',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Radar / Device Container
            SizedBox(
              height: 200,
              child: devices.isEmpty
                  ? _buildRadarSearchingView(theme)
                  : _buildDeviceListView(theme, devices),
            ),
            const SizedBox(height: 16),

            // Selection Summary
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.selectedPaths.length} Selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarSearchingView(IAppTheme theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar pulse waves
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: List.generate(3, (index) {
                        final delay = index * 0.33;
                        final progress =
                            (_pulseController.value + delay) % 1.0;
                        return Container(
                          width: 40 + (progress * 95),
                          height: 40 + (progress * 95),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primaryColor.withValues(
                                  alpha: (1.0 - progress) * 0.4),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                // Center Icon
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.sensors_rounded,
                    color: theme.primaryColor,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Searching for nearby devices...',
          style: TextStyle(
            fontSize: 13,
            color: theme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceListView(IAppTheme theme, List<NearbyDevice> devices) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final status = _statusMessages[device.id] ?? 'Tap to Send';
        final progress = _transferProgress[device.id] ?? 0.0;
        final speedText = _transferSpeedText[device.id] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: progress > 0.0 && progress < 1.0
                ? null
                : () => _handleSendToDevice(device),
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress Ring & Device Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: CircularProgressIndicator(
                          value: progress > 0.0 ? progress : null,
                          strokeWidth: 3.5,
                          backgroundColor: progress > 0.0
                              ? theme.primaryColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0 ? Colors.green : theme.primaryColor,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: progress == 1.0
                            ? Colors.green
                            : theme.primaryColor,
                        child: progress == 1.0
                            ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 28)
                            : Text(
                          device.name.isNotEmpty
                              ? device.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Device Name
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Transfer Status
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                      progress == 1.0 ? Colors.green : theme.primaryColor,
                    ),
                  ),

                  // Speed Info
                  if (speedText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      speedText,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
