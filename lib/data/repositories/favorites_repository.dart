import 'package:durakta_uyandir/domain/entities/favorite_location.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FavoritesRepository {
  static const String _boxName = 'favorites_box';
  late Box<FavoriteLocation> _box;

  Future<void> init() async {
    _box = await Hive.openBox<FavoriteLocation>(_boxName);
  }

  List<FavoriteLocation> getFavorites() {
    return _box.values.toList();
  }

  Future<void> addFavorite(FavoriteLocation location) async {
    await _box.put(location.id, location);
  }

  Future<void> removeFavorite(String id) async {
    await _box.delete(id);
  }
}
