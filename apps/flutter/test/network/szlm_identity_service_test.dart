import 'dart:async';
import 'dart:io';

import 'package:c001apk_flutter/logic/szlm_identity_service.dart';
import 'package:c001apk_flutter/utils/szlm_duid_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FailingIdentityBox implements Box<dynamic> {
  _FailingIdentityBox(this.base, this.failKey);
  final Box<dynamic> base;
  final String failKey;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      base.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) {
    if (key == failKey) throw StateError('synthetic storage failure');
    return base.put(key, value);
  }

  @override
  Future<void> flush() => base.flush();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late DateTime now;
  late String id;
  late int calls;
  late Future<String> Function() fetch;
  SzlmIdentityService service({Box<dynamic>? storage}) => SzlmIdentityService(
      settings: storage ?? box,
      clock: () => now,
      fetch: () {
        calls++;
        return fetch();
      },
      readId: () => id,
      readDevice: () => 'synthetic-device-$id',
      apply: (value) async {
        id = value;
      });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('onboarding-identity-');
    Hive.init(directory.path);
    box = await Hive.openBox('settings');
    now = DateTime.utc(2026, 10, 27);
    id = 'DUsyntheticEXISTING123456789';
    calls = 0;
    fetch = () async => 'DUsyntheticNEW1234567890123';
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('startup and verification paths never register', () async {
    final current = service();
    await current.ensure();
    current.noteChallenge();
    await current.beforeRequest();
    expect(calls, 0);
  });
  test('protocol seed is durable across failed attempts and restart', () async {
    final seeds = <String>[];
    SzlmIdentityService seeded({Box<dynamic>? storage}) => SzlmIdentityService(
        settings: storage ?? box,
        clock: () => now,
        register: (seed) async {
          seeds.add(seed);
          throw const SzlmDuidException('合成断网');
        },
        readId: () => id,
        readDevice: () => 'synthetic-device-$id',
        apply: (value) async {
          id = value;
        });
    await expectLater(seeded().renewNow(), throwsA(isA<SzlmDuidException>()));
    now = now.add(const Duration(minutes: 5));
    await expectLater(seeded().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(seeds, hasLength(2));
    expect(seeds[0], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(seeds[0], seeds[1]);
    expect(id, 'DUsyntheticEXISTING123456789');
  });
  test('seed persistence failure prevents registration', () async {
    var registrations = 0;
    final current = SzlmIdentityService(
        settings: _FailingIdentityBox(box, 'szlmReportSeed'),
        clock: () => now,
        register: (_) async {
          registrations++;
          return 'DUsyntheticNEW1234567890123';
        },
        readId: () => id,
        readDevice: () => 'synthetic-device-$id',
        apply: (value) async {
          id = value;
        });
    await expectLater(current.renewNow(), throwsStateError);
    expect(registrations, 0);
    expect(id, 'DUsyntheticEXISTING123456789');
  });
  test('successful acquisition persists a seven day boundary across restart',
      () async {
    await service().renewNow();
    now = now
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));
    await expectLater(service().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 1);
    now = now.add(const Duration(milliseconds: 1));
    await service().renewNow();
    expect(calls, 2);
  });
  test('failures retain five minute cooldown and three attempts in rolling day',
      () async {
    fetch = () async => throw const SzlmDuidException('合成断网');
    for (var i = 0; i < 3; i++) {
      await expectLater(
          service().renewNow(), throwsA(isA<SzlmDuidException>()));
      await expectLater(
          service().renewNow(), throwsA(isA<SzlmDuidException>()));
      expect(calls, i + 1);
      now = now.add(const Duration(minutes: 5));
    }
    await expectLater(service().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 3);
    now = DateTime.utc(2026, 10, 28);
    await expectLater(service().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 4);
  });
  test('concurrent clicks share one request and manual import wins the race',
      () async {
    final started = Completer<void>();
    final result = Completer<String>();
    fetch = () {
      started.complete();
      return result.future;
    };
    final current = service();
    final first = current.renewNow();
    final second = current.renewNow();
    final firstCheck = expectLater(first, throwsA(isA<SzlmDuidException>()));
    final secondCheck = expectLater(second, throwsA(isA<SzlmDuidException>()));
    await started.future;
    id = 'DUsyntheticMANUAL123456789';
    result.complete('DUsyntheticNEW1234567890123');
    await Future.wait([firstCheck, secondCheck]);
    expect(id, 'DUsyntheticMANUAL123456789');
    expect(calls, 1);
    await expectLater(service().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 1);
  });
  test('clock rollback does not bypass an existing cooldown', () async {
    await service().renewNow();
    now = now.subtract(const Duration(days: 30));
    await expectLater(service().renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 1);
  });
  test('attempt record save failure prevents any registration', () async {
    final current =
        service(storage: _FailingIdentityBox(box, 'szlmAcquisitionAttempts'));
    await expectLater(current.renewNow(), throwsStateError);
    expect(calls, 0);
    expect(id, 'DUsyntheticEXISTING123456789');
  });
  test(
      'success record save failure preserves the old ID and blocks repeat in memory',
      () async {
    final current =
        service(storage: _FailingIdentityBox(box, 'szlmLastAcquiredAt'));
    await expectLater(current.renewNow(), throwsStateError);
    expect(calls, 1);
    expect(id, 'DUsyntheticEXISTING123456789');
    await expectLater(current.renewNow(), throwsA(isA<SzlmDuidException>()));
    expect(calls, 1);
  });
}
