import 'package:durakta_uyandir/presentation/cubit/settings_cubit.dart';
import 'package:durakta_uyandir/presentation/widgets/feedback_bottom_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, "settings.appearance".tr()),
        _buildThemeSelector(context),
        const SizedBox(height: 24),

        _buildSectionHeader(context, "settings.language".tr()),
        _buildLanguageSelector(context),
        const SizedBox(height: 24),

        _buildSectionHeader(context, "settings.alarm_prefs".tr()),
        _buildSwitchTile(
          context,
          title: "settings.sound".tr(),
          subtitle: "settings.sound_desc".tr(),
          icon: Icons.volume_up_outlined,
          stateSelector: (state) => state.isSoundEnabled,
          onChanged: (val) => context.read<SettingsCubit>().toggleSound(val),
        ),
        _buildSwitchTile(
          context,
          title: "settings.vibration".tr(),
          subtitle: "settings.vibration_desc".tr(),
          icon: Icons.vibration,
          stateSelector: (state) => state.isVibrationEnabled,
          onChanged: (val) => context.read<SettingsCubit>().toggleVibration(val),
        ),
        _buildSwitchTile(
          context,
          title: "settings.notification".tr(),
          subtitle: "settings.notification_desc".tr(),
          icon: Icons.notifications_active_outlined,
          stateSelector: (state) => state.isNotificationEnabled,
          onChanged: (val) => context.read<SettingsCubit>().toggleNotification(val),
        ),
        _buildHeadphoneSwitchTile(context),

        const SizedBox(height: 24),

        _buildSectionHeader(context, "settings.other".tr()),
        _buildSwitchTile(
          context,
          title: "settings.analytics".tr(),
          subtitle: "settings.analytics_desc".tr(),
          icon: Icons.analytics_outlined,
          stateSelector: (state) => state.isAnalyticsEnabled ?? false,
          onChanged: (val) => context.read<SettingsCubit>().setAnalyticsEnabled(val),
        ),
        _buildActionTile(
          context,
          title: "settings.feedback".tr(),
          icon: Icons.feedback_outlined,
          onTap: () => showFeedbackBottomSheet(context),
        ),
        _buildActionTile(
          context,
          title: "settings.privacy".tr(),
          icon: Icons.policy,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('settings.privacy'.tr()),
                content: SingleChildScrollView(child: Text("settings.privacy_text".tr())),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.ok'.tr()),
                  ),
                ],
              ),
            );
          },
        ),
        _buildActionTile(
          context,
          title: "settings.about".tr(),
          icon: Icons.info_outline,
          onTap: () async {
            final packageInfo = await PackageInfo.fromPlatform();
            if (!context.mounted) return;

            showAboutDialog(
              context: context,
              applicationName: "Durakta Uyandır",
              applicationVersion: packageInfo.buildNumber.isEmpty
                  ? 'v${packageInfo.version}'
                  : 'v${packageInfo.version}+${packageInfo.buildNumber}',
              applicationIcon: const Icon(Icons.location_on, size: 50, color: Colors.blue),
              applicationLegalese: '''MIT License

Copyright (c) 2025 Durakta Uyandır

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

---
${"settings.feedback_legalese".tr()}''',
            );
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.language, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Locale>(
                  value: context.locale,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: Locale('tr', 'TR'), child: Text("Türkçe")),
                    DropdownMenuItem(value: Locale('en', 'US'), child: Text("English")),
                  ],
                  onChanged: (Locale? locale) {
                    if (locale != null) {
                      context.setLocale(locale);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) => previous.themeMode != current.themeMode,
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildThemeOption(
                  context,
                  icon: Icons.brightness_auto,
                  label: "settings.system".tr(),
                  isSelected: state.themeMode == ThemeMode.system,
                  onTap: () => context.read<SettingsCubit>().updateTheme(ThemeMode.system),
                ),
                _buildThemeOption(
                  context,
                  icon: Icons.light_mode,
                  label: "settings.light".tr(),
                  isSelected: state.themeMode == ThemeMode.light,
                  onTap: () => context.read<SettingsCubit>().updateTheme(ThemeMode.light),
                ),
                _buildThemeOption(
                  context,
                  icon: Icons.dark_mode,
                  label: "settings.dark".tr(),
                  isSelected: state.themeMode == ThemeMode.dark,
                  onTap: () => context.read<SettingsCubit>().updateTheme(ThemeMode.dark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool Function(SettingsState) stateSelector,
    required ValueChanged<bool> onChanged,
  }) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) => stateSelector(previous) != stateSelector(current),
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            value: stateSelector(state),
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  Widget _buildHeadphoneSwitchTile(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) =>
          previous.isHeadphoneOnlyModeEnabled != current.isHeadphoneOnlyModeEnabled ||
          previous.isSoundEnabled != current.isSoundEnabled,
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            value: state.isHeadphoneOnlyModeEnabled,
            onChanged: state.isSoundEnabled
                ? (val) => context.read<SettingsCubit>().toggleHeadphoneOnly(val)
                : (val) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("settings.headphone_warn".tr())));
                  },
            activeThumbColor: Theme.of(context).colorScheme.primary,
            title: Text(
              "settings.headphone".tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("settings.headphone_desc".tr()),
            secondary: Icon(Icons.headphones, color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
