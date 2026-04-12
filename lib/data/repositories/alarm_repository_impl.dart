import 'package:durakta_uyandir/data/datasources/alarm_local_data_source.dart';
import 'package:durakta_uyandir/data/models/destination_alarm_model.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/domain/repositories/alarm_repository.dart';

class AlarmRepositoryImpl implements AlarmRepository {
  final AlarmLocalDataSource localDataSource;

  AlarmRepositoryImpl({required this.localDataSource});

  @override
  Future<void> deleteAlarm(String id) async {
    await localDataSource.deleteAlarm(id);
  }

  @override
  Future<List<DestinationAlarm>> getAlarms() async {
    return await localDataSource.getAlarms();
  }

  @override
  Future<void> saveAlarm(DestinationAlarm alarm) async {
    final model = DestinationAlarmModel.fromEntity(alarm);
    await localDataSource.cacheAlarm(model);
  }

  @override
  Future<void> updateAlarmStatus(String id, bool isActive) async {
    await localDataSource.updateAlarmStatus(id, isActive);
  }
}
