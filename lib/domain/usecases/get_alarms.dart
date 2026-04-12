import 'package:durakta_uyandir/core/usecases/usecase.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/domain/repositories/alarm_repository.dart';

class GetAlarms implements UseCase<List<DestinationAlarm>, NoParams> {
  final AlarmRepository repository;

  GetAlarms(this.repository);

  @override
  Future<List<DestinationAlarm>> call(NoParams params) async {
    return await repository.getAlarms();
  }
}
