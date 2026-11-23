from app.spatial import cell_for, is_nearby

# Jakarta (Monas, roughly) and a point ~150m away vs. a point ~15km away
MONAS = (-6.1754, 106.8272)
NEARBY = (-6.1760, 106.8278)  # a couple hundred meters off
FAR_AWAY = (-6.3000, 106.7000)  # a different part of Jakarta entirely


def test_cell_for_is_deterministic() -> None:
    assert cell_for(*MONAS) == cell_for(*MONAS)


def test_is_nearby_true_for_close_points() -> None:
    assert is_nearby(*MONAS, *NEARBY, k=2) is True


def test_is_nearby_false_for_distant_points() -> None:
    assert is_nearby(*MONAS, *FAR_AWAY, k=2) is False
