/// PRD v3.1 — 5-minute online ring (MVP heartbeat).
abstract final class PresenceHelper {
  static const onlineWindow = Duration(minutes: 5);

  static bool isOnline(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt) <= onlineWindow;
  }
}
