/// Which side of the Home tab the user is currently on.
///
/// FRD §4.4 — a user can only have one active spontaneous role at a time
/// (FR-SPN-03), so this is a single piece of state rather than two booleans
/// that could both end up true.
enum HomeMode { find, offer }
