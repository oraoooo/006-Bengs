"""Thin H3 wrapper — turns lat/lng points into coarse spatial buckets so the
future Discovery Engine can cheaply narrow down candidate bengs (same or
neighboring cell) before running any real distance/routing computation.

Resolution 9 (~0.1 km2 per cell) is a reasonable default for city-scale
"is this nearby" checks; tune once EXP-02/EXP-07 have real usage data.
"""

import h3

DEFAULT_RESOLUTION = 9


def cell_for(lat: float, lng: float, resolution: int = DEFAULT_RESOLUTION) -> str:
    """The H3 cell id containing this point."""
    return h3.latlng_to_cell(lat, lng, resolution)


def is_nearby(
    lat_a: float,
    lng_a: float,
    lat_b: float,
    lng_b: float,
    k: int = 1,
    resolution: int = DEFAULT_RESOLUTION,
) -> bool:
    """True if point B falls within k grid-cell "rings" of point A's cell —
    a cheap proxy for "close enough to be worth a real distance check",
    not a substitute for one.
    """
    cell_a = cell_for(lat_a, lng_a, resolution)
    cell_b = cell_for(lat_b, lng_b, resolution)
    return cell_b in h3.grid_disk(cell_a, k)
