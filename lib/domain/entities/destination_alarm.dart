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
