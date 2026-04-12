import 'package:durakta_uyandir/core/services/background_service.dart';
import 'package:durakta_uyandir/core/theme/app_theme.dart';
import 'package:durakta_uyandir/injection_container.dart' as di;
import 'package:durakta_uyandir/presentation/bloc/alarm_bloc.dart';
import 'package:durakta_uyandir/presentation/cubit/settings_cubit.dart';
import 'package:durakta_uyandir/presentation/pages/main_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await di.init();

  await BackgroundLocationService.initializeService();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr', 'TR'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AlarmBloc>()..add(LoadAlarms())),
        BlocProvider(create: (_) => di.sl<SettingsCubit>()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Durakta Uyandır',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            home: MainPage(),
          );
        },
      ),
    );
  }
}
