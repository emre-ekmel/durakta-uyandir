import 'package:durakta_uyandir/presentation/pages/add_alarm_page.dart';
import 'package:durakta_uyandir/presentation/pages/home_page.dart';
import 'package:durakta_uyandir/presentation/pages/settings_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  static final GlobalKey<_MainPageState> globalKey = GlobalKey<_MainPageState>();

  MainPage({Key? key}) : super(key: globalKey);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void switchTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [const HomePage(), const AddAlarmPage(), const SettingsPage()];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.locationWhenInUse]?.isGranted ?? false) {
      if (await Permission.locationAlways.isDenied) {
        if (!mounted) return;

        await _showBackgroundPermissionDialog();
      }
    }
  }

  Future<void> _showBackgroundPermissionDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("permissions.background_title".tr()),
        content: Text("permissions.background_desc".tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text("permissions.later".tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final status = await Permission.locationAlways.request();

              if (!status.isGranted) {
                await openAppSettings();
              }
            },
            child: Text("add_alarm.open_settings".tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Durakta Uyandır'), centerTitle: true),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_filled),
            label: 'common.nav_home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: 'common.nav_add'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'common.nav_settings'.tr(),
          ),
        ],
      ),
    );
  }
}
