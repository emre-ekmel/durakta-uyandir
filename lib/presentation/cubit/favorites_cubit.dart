import 'package:durakta_uyandir/data/repositories/favorites_repository.dart';
import 'package:durakta_uyandir/domain/entities/favorite_location.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();
  @override
  List<Object> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<FavoriteLocation> favorites;
  const FavoritesLoaded(this.favorites);
  @override
  List<Object> get props => [favorites];
}

class FavoritesError extends FavoritesState {
  final String message;
  const FavoritesError(this.message);
  @override
  List<Object> get props => [message];
}

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesCubit({required FavoritesRepository repository})
    : _repository = repository,
      super(FavoritesInitial()) {
    loadFavorites();
  }

  void loadFavorites() {
    try {
      emit(FavoritesLoading());
      final favorites = _repository.getFavorites();
      emit(FavoritesLoaded(favorites));
    } catch (e) {
      emit(FavoritesError("Favoriler yüklenemedi: $e"));
    }
  }

  bool isLocationFavorite(double lat, double lng) {
    if (state is FavoritesLoaded) {
      return (state as FavoritesLoaded).favorites.any(
        (fav) => (fav.latitude - lat).abs() < 0.0001 && (fav.longitude - lng).abs() < 0.0001,
      );
    }
    return false;
  }

  FavoriteLocation? getFavoriteByLocation(double lat, double lng) {
    if (state is FavoritesLoaded) {
      try {
        return (state as FavoritesLoaded).favorites.firstWhere(
          (fav) => (fav.latitude - lat).abs() < 0.0001 && (fav.longitude - lng).abs() < 0.0001,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> toggleFavorite({
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    final existing = getFavoriteByLocation(lat, lng);
    if (existing != null) {
      await removeFavorite(existing.id);
    } else {
      final newFav = FavoriteLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        latitude: lat,
        longitude: lng,
        defaultRadius: radius,
      );
      await addFavorite(newFav);
    }
  }

  Future<void> addFavorite(FavoriteLocation location) async {
    try {
      await _repository.addFavorite(location);
      loadFavorites();
    } catch (e) {
      emit(FavoritesError("Favori eklenemedi: $e"));
    }
  }

  Future<void> removeFavorite(String id) async {
    try {
      await _repository.removeFavorite(id);
      loadFavorites();
    } catch (e) {
      emit(FavoritesError("Favori silinemedi: $e"));
    }
  }
}
