import 'package:bengs/services/route_matching.dart';
import 'package:flutter_test/flutter_test.dart';

// A straight line of points 0..10 (degrees latitude, arbitrary scale) —
// enough to reason about ordering without real-world coordinates.
GeoPoint _pt(double lat, String name) => GeoPoint(name: name, latitude: lat, longitude: 0);

int _occupancyNeverExceeds(List<RouteStopPlan> route, int cap) {
  var occupancy = 0;
  var peak = 0;
  for (final stop in route) {
    if (stop.kind == StopKind.pickup) occupancy++;
    if (stop.kind == StopKind.dropoff) occupancy--;
    peak = occupancy > peak ? occupancy : peak;
  }
  return peak;
}

void _expectPrecedence(List<RouteStopPlan> route) {
  final pickupIndex = <String, int>{};
  for (var i = 0; i < route.length; i++) {
    final stop = route[i];
    if (stop.kind == StopKind.pickup) pickupIndex[stop.passengerId] = i;
    if (stop.kind == StopKind.dropoff) {
      expect(pickupIndex.containsKey(stop.passengerId), isTrue, reason: '${stop.passengerId} dropped off without a pickup');
      expect(pickupIndex[stop.passengerId]! < i, isTrue, reason: '${stop.passengerId} dropped off before/at their own pickup');
    }
  }
}

void main() {
  group('RouteMatcher (BR-09 concurrent-seat cap)', () {
    test('single passenger between origin and destination', () {
      final matcher = RouteMatcher(
        driverId: 'driver-1',
        origin: _pt(0, 'origin'),
        destination: _pt(10, 'destination'),
        maxPassenger: 2,
      );
      final route = matcher.build([
        PassengerLeg(passengerId: 'p1', pickup: _pt(3, 'p1-pickup'), dropoff: _pt(7, 'p1-dropoff')),
      ]);

      expect(route.first.kind, StopKind.driverDepart);
      expect(route.last.kind, StopKind.driverArrive);
      _expectPrecedence(route);
      expect(_occupancyNeverExceeds(route, 2), lessThanOrEqualTo(2));
    });

    test('two overlapping legs are serialized when maxPassenger is 1', () {
      final matcher = RouteMatcher(
        driverId: 'driver-1',
        origin: _pt(0, 'origin'),
        destination: _pt(10, 'destination'),
        maxPassenger: 1,
      );
      // Physically overlapping windows: A wants 2->6, B wants 4->8.
      // With only 1 seat, they can never both be in the car at once.
      final route = matcher.build([
        PassengerLeg(passengerId: 'A', pickup: _pt(2, 'A-pickup'), dropoff: _pt(6, 'A-dropoff')),
        PassengerLeg(passengerId: 'B', pickup: _pt(4, 'B-pickup'), dropoff: _pt(8, 'B-dropoff')),
      ]);

      _expectPrecedence(route);
      expect(_occupancyNeverExceeds(route, 1), equals(1));
    });

    test('two non-overlapping legs both fit with maxPassenger 1', () {
      final matcher = RouteMatcher(
        driverId: 'driver-1',
        origin: _pt(0, 'origin'),
        destination: _pt(10, 'destination'),
        maxPassenger: 1,
      );
      final route = matcher.build([
        PassengerLeg(passengerId: 'A', pickup: _pt(1, 'A-pickup'), dropoff: _pt(3, 'A-dropoff')),
        PassengerLeg(passengerId: 'B', pickup: _pt(5, 'B-pickup'), dropoff: _pt(7, 'B-dropoff')),
      ]);

      _expectPrecedence(route);
      expect(_occupancyNeverExceeds(route, 1), equals(1));
      expect(route.length, 6); // depart, A pickup, A dropoff, B pickup, B dropoff, arrive
    });

    test('open-ended (no destination) still inserts passengers', () {
      final matcher = RouteMatcher(
        driverId: 'driver-1',
        origin: _pt(0, 'origin'),
        maxPassenger: 3,
      );
      final route = matcher.build([
        PassengerLeg(passengerId: 'p1', pickup: _pt(2, 'pickup'), dropoff: _pt(5, 'dropoff')),
      ]);

      expect(route.first.kind, StopKind.driverDepart);
      expect(route.any((s) => s.kind == StopKind.driverArrive), isFalse);
      _expectPrecedence(route);
    });

    test('no passengers returns just the fixed stops', () {
      final matcher = RouteMatcher(
        driverId: 'driver-1',
        origin: _pt(0, 'origin'),
        destination: _pt(10, 'destination'),
        maxPassenger: 2,
      );
      final route = matcher.build([]);
      expect(route.length, 2);
      expect(route[0].kind, StopKind.driverDepart);
      expect(route[1].kind, StopKind.driverArrive);
    });
  });
}
