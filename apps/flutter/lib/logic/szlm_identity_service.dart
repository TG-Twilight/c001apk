import '../utils/storage_util.dart';
import '../utils/szlm_duid_client.dart';

/// Provisions the device identity without user action.
///
/// The identity is the first slot of `X-App-Device`, the `DID` cookie and part
/// of the API session hash, so every new value must go through
/// [GStorage.applySzlmId] to stay consistent with the per-request signature.
class SzlmIdentityService {
  SzlmIdentityService._();

  static final SzlmIdentityService instance = SzlmIdentityService._();

  /// Every attempt registers a new device upstream, and the endpoint is shared
  /// with real clients: a rotation must not repeat immediately after another.
  static const Duration cooldown = Duration(minutes: 5);
  static const int maxRenewalsPerRun = 3;

  Future<String>? _running;
  int _renewals = 0;
  DateTime? _lastRenewal;
  bool _challengePending = false;
  bool _checkedAtStartup = false;

  /// Called once after storage is ready. Fetches only when nothing is stored,
  /// so an identity that was imported or issued earlier is kept as it is.
  Future<void> ensure() async {
    if (_checkedAtStartup) return;
    _checkedAtStartup = true;
    if (GStorage.szlmId.trim().isNotEmpty) return;
    await _attempt();
  }

  /// The API asked for verification, which is how a stale identity looks from
  /// here. The next request rotates first instead of repeating the prompt.
  void noteChallenge() {
    _challengePending = true;
  }

  /// Called before an API request. A no-op unless a challenge was recorded,
  /// the cooldown has passed and the per-run budget is not spent.
  Future<void> beforeRequest() async {
    if (!_challengePending || !_canRenew) return;
    _challengePending = false;
    await _attempt();
  }

  /// Explicit user action; failures reach the caller so the page can report
  /// them instead of silently keeping the old identity.
  Future<String> renewNow() => _acquire();

  bool get _canRenew {
    if (_renewals >= maxRenewalsPerRun) return false;
    final last = _lastRenewal;
    return last == null || DateTime.now().difference(last) >= cooldown;
  }

  /// Silent path: a failure leaves the current identity in place.
  Future<void> _attempt() async {
    try {
      await _acquire();
    } catch (_) {
      // Background work must not raise toasts; the settings page and the
      // verification UI already describe the state to the user.
    }
  }

  Future<String> _acquire() {
    final running = _running;
    if (running != null) return running;
    late final Future<String> attempt;
    attempt = _run().whenComplete(() {
      if (identical(_running, attempt)) _running = null;
    });
    _running = attempt;
    return attempt;
  }

  Future<String> _run() async {
    final id = await SzlmDuidClient.fetch();
    await GStorage.applySzlmId(id);
    _renewals++;
    _lastRenewal = DateTime.now();
    return id;
  }
}
