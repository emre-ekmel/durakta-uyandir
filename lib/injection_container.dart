import 'package:durakta_uyandir/data/datasources/alarm_local_data_source.dart';
import 'package:durakta_uyandir/data/repositories/alarm_repository_impl.dart';
import 'package:durakta_uyandir/data/repositories/settings_repository.dart';
import 'package:durakta_uyandir/domain/repositories/alarm_repository.dart';
import 'package:durakta_uyandir/presentation/bloc/alarm_bloc.dart';
import 'package:durakta_uyandir/presentation/cubit/settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await Hive.initFlutter();

  final localDataSource = AlarmLocalDataSourceImpl();
  await localDataSource.init();
  sl.registerLazySingleton<AlarmLocalDataSource>(() => localDataSource);

  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  sl.registerLazySingleton(() => settingsRepository);

  sl.registerLazySingleton<AlarmRepository>(
    () => AlarmRepositoryImpl(localDataSource: sl()),
  );

  sl.registerFactory(() => SettingsCubit(repository: sl()));
  sl.registerFactory(
    () => AlarmBloc(repository: sl(), settingsRepository: sl()),
  );
}
