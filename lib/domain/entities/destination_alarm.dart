import 'package:equatable/equatable.dart';

class DestinationAlarm extends Equatable {
  final String id;
  final String name;
  final double targetLat;
  final double targetLng;
  final double triggerRadiusInMeters;
  final bool isActive;
  final bool vibrate;
  final String soundPath;

  const DestinationAlarm({
    required this.id,
    required this.name,
    required this.targetLat,
    required this.targetLng,
    this.triggerRadiusInMeters = 500.0,
    this.isActive = true,
    this.vibrate = true,
    this.soundPath = 'assets/sounds/alarm.mp3',
  });

  DestinationAlarm copyWith({
    String? id,
    String? name,
    double? targetLat,
    double? targetLng,
    double? triggerRadiusInMeters,
    bool? isActive,
    bool? vibrate,
    String? soundPath,
  }) {
    return DestinationAlarm(
      id: id ?? this.id,
      name: name ?? this.name,
      targetLat: targetLat ?? this.targetLat,
      targetLng: targetLng ?? this.targetLng,
      triggerRadiusInMeters: triggerRadiusInMeters ?? this.triggerRadiusInMeters,
      isActive: isActive ?? this.isActive,
      vibrate: vibrate ?? this.vibrate,
      soundPath: soundPath ?? this.soundPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    targetLat,
    targetLng,
    triggerRadiusInMeters,
    isActive,
    vibrate,
    soundPath,
  ];
}
