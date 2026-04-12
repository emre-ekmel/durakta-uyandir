import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'favorite_location.g.dart';

@HiveType(typeId: 2)
class FavoriteLocation extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final double defaultRadius;

  const FavoriteLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.defaultRadius = 500.0,
  });

  @override
  List<Object?> get props => [id, name, latitude, longitude, defaultRadius];
}
