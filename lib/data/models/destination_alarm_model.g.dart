// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'destination_alarm_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DestinationAlarmModel _$DestinationAlarmModelFromJson(Map<String, dynamic> json) =>
    DestinationAlarmModel(
      id: json['id'] as String,
      name: json['name'] as String,
      targetLat: (json['targetLat'] as num).toDouble(),
      targetLng: (json['targetLng'] as num).toDouble(),
      triggerRadiusInMeters: (json['triggerRadiusInMeters'] as num?)?.toDouble() ?? 500.0,
      isActive: json['isActive'] as bool? ?? true,
      vibrate: json['vibrate'] as bool? ?? true,
      soundPath: json['soundPath'] as String? ?? 'assets/sounds/alarm.mp3',
    );

Map<String, dynamic> _$DestinationAlarmModelToJson(DestinationAlarmModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'targetLat': instance.targetLat,
      'targetLng': instance.targetLng,
      'triggerRadiusInMeters': instance.triggerRadiusInMeters,
      'isActive': instance.isActive,
      'vibrate': instance.vibrate,
      'soundPath': instance.soundPath,
    };
