import 'package:flutter/material.dart';

import '../main.dart';
import '../themes/theme_provider.dart';
import '../utils/data_structures/transfer_models.dart';

class LanReceiveDialog extends StatefulWidget {
  final TransferBatchRequest batchRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const LanReceiveDialog({
    super.key,
    required this.batchRequest,
    required this.onAccept,
    required this.onDecline,
  });

  static Future<bool?> show(
      BuildContext context, {
        required TransferBatchRequest batchRequest,
        required VoidCallback onAccept,
        required VoidCallback onDecline,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LanReceiveDialog(
        batchRequest: batchRequest,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  @override
  State<LanReceiveDialog> createState() => _LanReceiveDialogState();
}

class _LanReceiveDialogState extends State<LanReceiveDialog> {
  bool _isReceiving = false;

  @override
  void initState() {
    super.initState();
    lanTransferController.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (_isReceiving && !lanTransferController.isReceiving) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    lanTransferController.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _handleAccept() {
    setState(() {
      _isReceiving = true;
    });
    widget.onAccept(); // Signals 'true' to the waiting onRequestReceived completer
  }

  void _handleDecline() {
    widget.onDecline(); // Signals 'false' to the waiting onRequestReceived completer
    Navigator.of(context).pop(false);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final tracks = widget.batchRequest.tracks;

    final progress = lanTransferController.incomingProgress;
    final speed = lanTransferController.incomingSpeedText;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      backgroundColor: theme.cardBackgroundColor,
      child: Container(
        width: 460,
        height: 560,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isReceiving
                    ? Icons.downloading_rounded
                    : Icons.move_to_inbox_rounded,
                size: 26,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isReceiving
                  ? 'Receiving Files...'
                  : 'Incoming Tracks Transfer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isReceiving
                  ? 'Receiving ${tracks.length} track(s) from ${widget.batchRequest.sender.name}'
                  : '${widget.batchRequest.sender.name} wants to send ${tracks.length} track(s).',
              style: TextStyle(fontSize: 13, color: theme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Song List View Section
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.textSecondary.withValues(alpha: 0.1),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: theme.textSecondary.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final item = tracks[index];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.artworkBytes != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            item.artworkBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Icon(
                          Icons.music_note_rounded,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${item.artist} • ${_formatSize(item.fileSize)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action / Progress Section
            if (_isReceiving) ...[
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress > 0.0 ? progress : null,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor:
                    theme.primaryColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text(
                        speed,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Accept & Receive'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
