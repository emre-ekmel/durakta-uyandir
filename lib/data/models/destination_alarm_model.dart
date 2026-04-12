import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:json_annotation/json_annotation.dart';

part 'destination_alarm_model.g.dart';

@JsonSerializable()
class DestinationAlarmModel extends DestinationAlarm {
  const DestinationAlarmModel({
    required super.id,
    required super.name,
    required super.targetLat,
    required super.targetLng,
    super.triggerRadiusInMeters,
    super.isActive,
    super.vibrate,
    super.soundPath,
  });

  factory DestinationAlarmModel.fromJson(Map<String, dynamic> json) =>
      _$DestinationAlarmModelFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationAlarmModelToJson(this);

  factory DestinationAlarmModel.fromEntity(DestinationAlarm entity) {
    return DestinationAlarmModel(
      id: entity.id,
      name: entity.name,
      targetLat: entity.targetLat,
      targetLng: entity.targetLng,
      triggerRadiusInMeters: entity.triggerRadiusInMeters,
      isActive: entity.isActive,
      vibrate: entity.vibrate,
      soundPath: entity.soundPath,
    );
  }
}
