import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../utils/official_device_identity.dart';
import '../utils/storage_util.dart';
import '../utils/szlm_duid_client.dart';

/// Registers only on explicit user action. Limits belong to this installation.
class SzlmIdentityService extends ChangeNotifier {
  SzlmIdentityService(
      {Box<dynamic>? settings,
      DateTime Function()? clock,
      Future<String> Function()? fetch,
      Future<String> Function(String seed)? register,
      String Function()? readId,
      String Function()? readDevice,
      Future<void> Function(String)? apply})
      : _settings = settings,
        _clock = clock ?? DateTime.now,
        _fetch = fetch,
        _register = register,
        _readId = readId ?? (() => GStorage.szlmId),
        _readDevice = readDevice ?? (() => GStorage.xAppDevice),
        _apply = apply ?? GStorage.applySzlmId;

  static final instance = SzlmIdentityService();
  static const cooldown = Duration(minutes: 5);
  static const successInterval = Duration(days: 7);
  static const attemptWindow = Duration(days: 1);
  static const maxAttempts = 3;
  static const _successKey = 'szlmLastAcquiredAt';
  static const _attemptsKey = 'szlmAcquisitionAttempts';
  final Box<dynamic>? _settings;
  Box<dynamic> get _box => _settings ?? GStorage.settings;
  final DateTime Function() _clock;
  final Future<String> Function()? _fetch;
  final Future<String> Function(String seed)? _register;
  final String Function() _readId, _readDevice;
  final Future<void> Function(String) _apply;
  Future<String>? _running;
  int? _successInMemory;
  List<int>? _attemptsInMemory;
  bool get isFetching => _running != null;

  List<int> _recentAttempts(DateTime now) {
    final stored = _box.get(_attemptsKey);
    final values = _attemptsInMemory ??
        (stored is List ? stored.whereType<int>().toList() : <int>[]);
    final threshold = now.subtract(attemptWindow).millisecondsSinceEpoch;
    return values.where((value) => value > threshold).toList()..sort();
  }

  DateTime? get nextAllowedAt {
    final now = _clock();
    DateTime? next;
    void include(int milliseconds, Duration interval) {
      final candidate =
          DateTime.fromMillisecondsSinceEpoch(milliseconds).add(interval);
      if (candidate.isAfter(now) &&
          (next == null || candidate.isAfter(next!))) {
        next = candidate;
      }
    }

    final success = _successInMemory ?? _box.get(_successKey);
    if (success is int) include(success, successInterval);
    final attempts = _recentAttempts(now);
    if (attempts.isNotEmpty) include(attempts.last, cooldown);
    if (attempts.length >= maxAttempts) {
      include(attempts[attempts.length - maxAttempts], attemptWindow);
    }
    return next;
  }

  String? get unavailableReason {
    final next = nextAllowedAt;
    if (next == null) return null;
    final local = next.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '可再次获取时间：${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // Passive compatibility hooks never register or rotate an identity.
  Future<void> ensure() async {}
  Future<void> beforeRequest() async {}
  void noteChallenge() {}
  void noteAccepted(String device) {}

  Future<String> renewNow() {
    final running = _running;
    if (running != null) return running;
    late final Future<String> attempt;
    attempt = _run().whenComplete(() {
      if (identical(_running, attempt)) _running = null;
      notifyListeners();
    });
    _running = attempt;
    notifyListeners();
    return attempt;
  }

  Future<String> _run() async {
    final reason = unavailableReason;
    if (reason != null) throw SzlmDuidException(reason);
    final previousId = _readId();
    final previousDevice = _readDevice();
    final now = _clock();
    _attemptsInMemory = [..._recentAttempts(now), now.millisecondsSinceEpoch];
    // Persist before contacting the service. A failed save must not register.
    await _box.put(_attemptsKey, _attemptsInMemory!);
    await _box.flush();
    final id = OfficialDeviceIdentity.parse('ShuzlmID: ${await _acquire()}');
    // A result superseded by a manual import still consumed a registration.
    _successInMemory = _clock().millisecondsSinceEpoch;
    await _box.put(_successKey, _successInMemory);
    await _box.flush();
    if (_readId() != previousId || _readDevice() != previousDevice) {
      throw const SzlmDuidException('设备标识已被更新，已保留当前值；本次获取已计入间隔');
    }
    await _apply(id);
    return id;
  }

  Future<String> _acquire() async {
    final fetch = _fetch;
    if (fetch != null) return fetch();
    const seedKey = 'szlmReportSeed';
    final stored = _box.get(seedKey);
    if (stored != null &&
        (stored is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(stored))) {
      throw const SzlmDuidException('本机设备报文配置无法读取，请使用手动导入');
    }
    final seed = stored as String? ?? SzlmDuidClient.createSeed();
    if (stored == null) {
      await _box.put(seedKey, seed);
      await _box.flush();
    }
    final register = _register;
    if (register != null) return register(seed);
    return SzlmDuidClient.fetch(
        seed: seed,
        manufacturer: GStorage.manufacturer,
        model: GStorage.model,
        androidVersion: GStorage.androidVersion,
        sdkInt: int.tryParse(GStorage.sdkInt) ?? 33);
  }
}
