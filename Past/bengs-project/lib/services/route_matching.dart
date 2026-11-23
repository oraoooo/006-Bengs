import 'dart:math' as math;

/// v1 route-matching per CLAUDE.md's roadmap: cheapest-insertion heuristic
/// + a feasibility-constrained 2-opt local search. Pure, DB-free — kept
/// separate from RouteRepository so the algorithm itself is unit-testable
/// without a Supabase session (mirrors utils/age.dart).

class GeoPoint {
  const GeoPoint({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;
}

/// One passenger's requested pickup + drop-off points.
class PassengerLeg {
  const PassengerLeg({required this.passengerId, required this.pickup, required this.dropoff});

  final String passengerId;
  final GeoPoint pickup;
  final GeoPoint dropoff;
}

enum StopKind { driverDepart, driverArrive, pickup, dropoff }

/// Thrown when a passenger genuinely cannot be inserted anywhere in the
/// route without exceeding [RouteMatcher.maxPassenger] at some point along
/// it (BR-09) — e.g. the driver accepts one request too many for a leg the
/// whole route already runs at capacity through.
class RouteCapacityExceededException implements Exception {
  const RouteCapacityExceededException(this.passengerId);

  final String passengerId;

  @override
  String toString() => 'RouteCapacityExceededException: no feasible stop position for passenger $passengerId within maxPassenger';
}

class RouteStopPlan {
  const RouteStopPlan({required this.location, required this.passengerId, required this.kind});

  final GeoPoint location;

  /// The driver's own id for [StopKind.driverDepart]/[StopKind.driverArrive]
  /// stops — beng_route.passenger_id is NOT NULL, so a driver-only stop is
  /// recorded as belonging to the driver.
  final String passengerId;
  final StopKind kind;

  int get passengerState => switch (kind) {
        StopKind.pickup => 1,
        StopKind.dropoff => -1,
        StopKind.driverDepart || StopKind.driverArrive => 0,
      };
}

/// Great-circle distance in km — exposed for RouteRepository's ETA
/// calculation, which needs the same metric the matcher optimized for.
double haversineKm(GeoPoint a, GeoPoint b) => _haversineKm(a, b);

double _haversineKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _degToRad(double deg) => deg * math.pi / 180;

class _Waypoint {
  _Waypoint({required this.location, required this.passengerId, required this.kind});

  final GeoPoint location;
  final String passengerId;
  final StopKind kind;
}

/// BR-09: [maxPassenger] is a concurrent-seat cap, not a per-trip headcount
/// cap — this is exactly why occupancy has to be tracked stop-by-stop
/// rather than just counting total passengers.
///
/// [destination] is null for an open-ended spontaneous offer (FR-SPN-12);
/// when present, it's always the last stop.
class RouteMatcher {
  RouteMatcher({
    required this.driverId,
    required this.origin,
    this.destination,
    required this.maxPassenger,
  });

  final String driverId;
  final GeoPoint origin;
  final GeoPoint? destination;
  final int maxPassenger;

  List<_Waypoint> _route = [];

  List<RouteStopPlan> build(List<PassengerLeg> passengers) {
    _route = [_Waypoint(location: origin, passengerId: driverId, kind: StopKind.driverDepart)];
    if (destination != null) {
      _route.add(_Waypoint(location: destination!, passengerId: driverId, kind: StopKind.driverArrive));
    }

    for (final leg in passengers) {
      _insertCheapest(leg);
    }

    _twoOptImprove();

    return _route
        .map((w) => RouteStopPlan(location: w.location, passengerId: w.passengerId, kind: w.kind))
        .toList();
  }

  /// The index range insertion may target — anywhere from right after the
  /// depart stop up to (and including, for the dropoff) right before a
  /// fixed final arrival stop.
  int get _insertableEnd => destination != null ? _route.length - 1 : _route.length;

  void _insertCheapest(PassengerLeg leg) {
    double bestCost = double.infinity;
    var bestPickupIndex = -1;
    var bestDropoffIndex = -1;

    for (var i = 1; i <= _insertableEnd; i++) {
      for (var j = i; j <= _insertableEnd; j++) {
        final candidate = List<_Waypoint>.from(_route);
        candidate.insert(i, _Waypoint(location: leg.pickup, passengerId: leg.passengerId, kind: StopKind.pickup));
        candidate.insert(j + 1, _Waypoint(location: leg.dropoff, passengerId: leg.passengerId, kind: StopKind.dropoff));

        if (!_isCapacityFeasible(candidate)) continue;

        final cost = _totalDistance(candidate);
        if (cost < bestCost) {
          bestCost = cost;
          bestPickupIndex = i;
          bestDropoffIndex = j + 1;
        }
      }
    }

    // No (i, j) pair stayed within maxPassenger anywhere — the vehicle is
    // already at capacity through every reachable span of the route, so
    // this passenger cannot be added, full stop. Silently falling back to
    // some default position (as this used to) would overbook past BR-09's
    // concurrent-seat cap.
    if (bestPickupIndex == -1) {
      throw RouteCapacityExceededException(leg.passengerId);
    }

    _route.insert(bestPickupIndex, _Waypoint(location: leg.pickup, passengerId: leg.passengerId, kind: StopKind.pickup));
    _route.insert(bestDropoffIndex, _Waypoint(location: leg.dropoff, passengerId: leg.passengerId, kind: StopKind.dropoff));
  }

  bool _isCapacityFeasible(List<_Waypoint> route) {
    var occupancy = 0;
    for (final stop in route) {
      if (stop.kind == StopKind.pickup) {
        occupancy++;
        if (occupancy > maxPassenger) return false;
      } else if (stop.kind == StopKind.dropoff) {
        occupancy--;
      }
    }
    return true;
  }

  double _totalDistance(List<_Waypoint> route) {
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      total += _haversineKm(route[i].location, route[i + 1].location);
    }
    return total;
  }

  /// Constrained 2-opt: try reversing each interior segment, keep the swap
  /// only if it stays feasible (each passenger's pickup still precedes
  /// their dropoff, capacity respected throughout) and shortens the route.
  void _twoOptImprove() {
    const start = 1; // never move the fixed depart stop
    final end = destination != null ? _route.length - 2 : _route.length - 1; // never move a fixed arrival stop
    var improved = true;

    while (improved) {
      improved = false;
      for (var i = start; i < end; i++) {
        for (var j = i + 1; j <= end; j++) {
          final candidate = List<_Waypoint>.from(_route);
          final segment = candidate.sublist(i, j + 1).reversed.toList();
          candidate.replaceRange(i, j + 1, segment);

          if (!_respectsPrecedence(candidate) || !_isCapacityFeasible(candidate)) continue;
          if (_totalDistance(candidate) < _totalDistance(_route) - 1e-9) {
            _route = candidate;
            improved = true;
          }
        }
      }
    }
  }

  bool _respectsPrecedence(List<_Waypoint> route) {
    final pickupIndex = <String, int>{};
    for (var i = 0; i < route.length; i++) {
      final stop = route[i];
      if (stop.kind == StopKind.pickup) {
        pickupIndex[stop.passengerId] = i;
      } else if (stop.kind == StopKind.dropoff) {
        final pIndex = pickupIndex[stop.passengerId];
        if (pIndex == null || pIndex >= i) return false;
      }
    }
    return true;
  }
}
