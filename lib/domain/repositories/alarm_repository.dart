import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';

abstract class AlarmRepository {
  Future<void> saveAlarm(DestinationAlarm alarm);
  Future<void> deleteAlarm(String id);
  Future<List<DestinationAlarm>> getAlarms();
  Future<void> updateAlarmStatus(String id, bool isActive);
}
