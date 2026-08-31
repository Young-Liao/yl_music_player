import 'package:flutter/material.dart';
import '../../controllers/themes/theme_controller.dart';
import '../../main.dart';
import '../../themes/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  final ValueChanged<bool>? onTransferServiceChanged;

  const SettingsPage({
    super.key,
    this.onTransferServiceChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _toggleTransferService(bool enabled) async {
    setState(() {
      isTransferEnabled = enabled;
    });

    if (enabled) {
      await lanTransferController.initService();
    } else {
      await lanTransferController.stopService();
    }

    widget.onTransferServiceChanged?.call(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Card Container
              Container(
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: theme.textMuted.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Setting 1: LAN File Transfer Switch
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.sync_alt_rounded,
                          color: isTransferEnabled
                              ? theme.primaryColor
                              : theme.textSecondary,
                        ),
                      ),
                      title: Text(
                        'LAN File Transfer',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Enable local network sync and wireless file sharing service',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: theme.textSecondary,
                        ),
                      ),
                      trailing: Switch(
                        value: isTransferEnabled,
                        activeTrackColor: theme.primaryColor,
                        onChanged: _toggleTransferService,
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: theme.textMuted.withValues(alpha: 0.1)),

                    // Setting 2: Theme Switcher
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                        child: theme.themeIcon,
                      ),
                      title: Text(
                        'Appearance Theme',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Switch application visual style between light and dark modes',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: theme.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: theme.themeIcon,
                        onPressed: ThemeController.instance.toggleTheme,
                        tooltip: 'Toggle Theme',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
