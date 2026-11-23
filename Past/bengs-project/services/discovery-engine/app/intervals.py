"""Thin interval-tree wrapper — given many (start, end) time windows (e.g.
beng_daily departure/arrival times), efficiently find which ones overlap a
given window, instead of comparing every pair by hand. This is the time-axis
counterpart to spatial.py's H3 pre-filter: EXP-07 (merge detection) needs
both a spatial AND a temporal overlap check before it's worth running
anything expensive on a candidate pair.
"""

from datetime import datetime

from intervaltree import IntervalTree


def build_tree(windows: list[tuple[datetime, datetime, str]]) -> IntervalTree:
    """windows: list of (start, end, id) — id is any identifier you want
    back on a match (e.g. a beng_daily_id), not interpreted here."""
    tree = IntervalTree()
    for start, end, window_id in windows:
        tree.addi(start.timestamp(), end.timestamp(), window_id)
    return tree


def overlapping(tree: IntervalTree, start: datetime, end: datetime) -> list[str]:
    """ids of every stored window that overlaps [start, end)."""
    return [interval.data for interval in tree.overlap(start.timestamp(), end.timestamp())]
