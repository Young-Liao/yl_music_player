import 'package:flutter/material.dart';
import '../controllers/network/lan_transfer_controller.dart';
import '../themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';

class LanTransferDialog extends StatefulWidget {
  final List<String> selectedPaths;

  const LanTransferDialog({
    super.key,
    required this.selectedPaths,
  });

  static Future<void> show(BuildContext context, List<String> selectedPaths) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => LanTransferDialog(selectedPaths: selectedPaths),
    );
  }

  @override
  State<LanTransferDialog> createState() => _LanTransferDialogState();
}

class _LanTransferDialogState extends State<LanTransferDialog> {
  late final LanTransferController _controller;
  final Map<String, String> _sendingStates = {}; // Track status per device ID

  @override
  void initState() {
    super.initState();
    _controller = LanTransferController();
    _controller.addListener(_onControllerUpdate);

    // Start mDNS discovery & receiver listener service
    _controller.startService(deviceName: 'This Device');
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.stopService();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSendToDevice(NearbyDevice device) async {
    if (widget.selectedPaths.isEmpty) return;

    setState(() {
      _sendingStates[device.id] = 'Sending...';
    });

    bool allSuccess = true;
    for (final path in widget.selectedPaths) {
      final success = await _controller.sendFile(
        target: device,
        filePath: path,
        myDeviceName: 'This Device',
      );
      if (!success) {
        allSuccess = false;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _sendingStates[device.id] = allSuccess ? 'Sent!' : 'Failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final devices = _controller.discoveredDevices;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
      backgroundColor: theme.cardBackgroundColor,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with Close Button
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Radar & Nearby Devices Section
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse Background Rings
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),

                  // Dynamic Discovered Devices List
                  if (devices.isEmpty)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Searching for nearby devices...',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: devices.map((device) {
                          final status = _sendingStates[device.id] ?? 'Tap to send';
                          final isSending = status == 'Sending...';
                          final isSuccess = status == 'Sent!';
                          final isFailed = status == 'Failed';

                          Color statusColor = theme.primaryColor;
                          if (isSuccess) statusColor = const Color(0xFF10B981);
                          if (isFailed) statusColor = Colors.redAccent;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildDeviceItem(
                              theme: theme,
                              deviceName: device.name,
                              label: device.name.isNotEmpty ? device.name[0].toUpperCase() : '?',
                              statusText: status,
                              avatarColor: isSuccess
                                  ? const Color(0xFF10B981)
                                  : (isFailed ? Colors.redAccent : theme.primaryColor),
                              statusColor: statusColor,
                              onTap: isSending ? () {} : () => _handleSendToDevice(device),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Selected Track Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.selectedPaths.isNotEmpty
                              ? widget.selectedPaths.first.split('/').last
                              : "None",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.selectedPaths.length > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            "${widget.selectedPaths.length} Tracks Selected",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Subtitle discoverability note
            Text(
              "You are discoverable by everyone nearby via local Wi-Fi network.",
              style: TextStyle(
                fontSize: 12.5,
                color: theme.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem({
    required IAppTheme theme,
    required String deviceName,
    required String label,
    required String statusText,
    required Color avatarColor,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            deviceName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
