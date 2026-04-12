import 'package:durakta_uyandir/core/utils/location_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationUtils - Distance Calculation', () {
    test('calculateDistance() should return 0 for identical coordinates', () {
      const double lat = 41.0082;
      const double lon = 28.9784; // Istanbul

      final distance = LocationUtils.calculateDistance(lat, lon, lat, lon);

      expect(distance, 0.0);
    });

    test('calculateDistance() should calculate distance accurately using Haversine/Vincenty', () {
      // Ankara (Kızılay)
      const double lat1 = 39.9208;
      const double lon1 = 32.8541;

      // Istanbul (Taksim)
      const double lat2 = 41.0369;
      const double lon2 = 28.9850;

      // Approximate bird-flight distance between Ankara and Istanbul is ~350 km
      final distance = LocationUtils.calculateDistance(lat1, lon1, lat2, lon2);

      // Checking if distance is somewhere between 340,000 meters and 360,000 meters
      expect(distance, greaterThan(340000));
      expect(distance, lessThan(360000));
    });
  });
}
