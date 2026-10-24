import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:c001apk_flutter/utils/token_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

String decode(String value) => utf8
    .decode(base64Decode(base64.normalize(value.split('').reversed.join())));

void main() {
  late Directory directory;
  const original =
      'synthetic-install-identity; ; ; 02:11:22:33:44:55; TestMaker; TestBrand; TestModel; TestBuild; null';
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('device-identity-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox('settings');
  });
  setUp(() async {
    await GStorage.settings.clear();
    await GStorage.settings.putAll({
      SettingsBoxKey.xAppDevice: await TokenUtils.encodeDevice(original),
      SettingsBoxKey.manufacturer: 'TestMaker',
      SettingsBoxKey.brand: 'TestBrand',
      SettingsBoxKey.model: 'TestModel',
      SettingsBoxKey.buildNumber: 'TestBuild',
      SettingsBoxKey.uid: 'synthetic-user',
      SettingsBoxKey.token: 'synthetic-account-token',
      'unrelated-setting': 'keep',
    });
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('saving a protocol field preserves installation identity and MAC',
      () async {
    await GStorage.fullSetXAppDevice();
    expect(decode(GStorage.xAppDevice), original);
    GStorage.setModel('NewModel');
    await GStorage.fullSetXAppDevice();
    expect(decode(GStorage.xAppDevice),
        'synthetic-install-identity; ; ; 02:11:22:33:44:55; TestMaker; TestBrand; NewModel; TestBuild; null');
  });
  test('import changes only the first slot', () async {
    final before = GStorage.settings.toMap();
    await GStorage.importOfficialDeviceIdentity(
        '设备ID: unused\nShuzlmID: synthetic_official_identity_0123456789\nAndroidID: unused\nUUID: unused');
    expect(decode(GStorage.xAppDevice),
        'synthetic_official_identity_0123456789; ; ; 02:11:22:33:44:55; TestMaker; TestBrand; TestModel; TestBuild; null');
    for (final entry in before.entries) {
      if (entry.key != SettingsBoxKey.xAppDevice) {
        expect(GStorage.settings.get(entry.key), entry.value);
      }
    }
    final encoded = GStorage.xAppDevice;
    expect(GStorage.szlmId, 'synthetic_official_identity_0123456789');
    expect(GStorage.xAppDevice, encoded);
    await GStorage.fullSetXAppDevice();
    expect(GStorage.xAppDevice, encoded);
  });
  test('import persists across independent storage lifetimes', () async {
    final path = '${directory.path}/restart';
    await Isolate.run(() async {
      Hive.init(path);
      GStorage.settings = await Hive.openBox('settings');
      await GStorage.settings.put(
          SettingsBoxKey.xAppDevice, await TokenUtils.encodeDevice(original));
      await GStorage.importOfficialDeviceIdentity(
          'ShuzlmID: synthetic_official_identity_0123456789');
      await Hive.close();
    });
    final result = await Isolate.run(() async {
      Hive.init(path);
      final box = await Hive.openBox('settings');
      final values = [
        box.get(SettingsBoxKey.szlmId),
        decode(box.get(SettingsBoxKey.xAppDevice) as String)
      ];
      await Hive.close();
      return values;
    });
    expect(result, [
      'synthetic_official_identity_0123456789',
      'synthetic_official_identity_0123456789; ; ; 02:11:22:33:44:55; TestMaker; TestBrand; TestModel; TestBuild; null'
    ]);
  });
  test('invalid clipboard or corrupt header leaves all settings untouched',
      () async {
    final before = GStorage.settings.toMap();
    await expectLater(GStorage.importOfficialDeviceIdentity('AndroidID: no'),
        throwsFormatException);
    expect(GStorage.settings.toMap(), before);
    await GStorage.settings.put(SettingsBoxKey.xAppDevice, 'broken');
    final corrupt = GStorage.settings.toMap();
    await expectLater(
        GStorage.importOfficialDeviceIdentity(
            'ShuzlmID: synthetic_official_identity_0123456789'),
        throwsFormatException);
    expect(GStorage.settings.toMap(), corrupt);
  });
  test('automatic identity reuses the single-slot save path', () async {
    final before = GStorage.settings.toMap();
    await GStorage.applySzlmId('DUautoIdent0000000000000000000000001');
    expect(GStorage.szlmId, 'DUautoIdent0000000000000000000000001');
    expect(decode(GStorage.xAppDevice),
        'DUautoIdent0000000000000000000000001; ; ; 02:11:22:33:44:55; TestMaker; TestBrand; TestModel; TestBuild; null');
    for (final entry in before.entries) {
      if (entry.key != SettingsBoxKey.xAppDevice &&
          entry.key != SettingsBoxKey.szlmId) {
        expect(GStorage.settings.get(entry.key), entry.value);
      }
    }
    await expectLater(
        GStorage.applySzlmId('0000000000000000000000000000000000'),
        throwsFormatException);
    expect(GStorage.szlmId, 'DUautoIdent0000000000000000000000001');
  });
  test('reset keeps imported identity and uses a consistent desktop profile',
      () async {
    await GStorage.importOfficialDeviceIdentity(
        'ShuzlmID: synthetic_official_identity_0123456789');
    await GStorage.regenerateParams();
    expect(GStorage.szlmId, 'synthetic_official_identity_0123456789');
    expect(decode(GStorage.xAppDevice).split(';').first, GStorage.szlmId);
    expect(GStorage.sdkInt, '33');
    expect(GStorage.androidVersion, '13');
    final first = GStorage.xAppDevice;
    await GStorage.regenerateParams();
    expect(GStorage.xAppDevice, first);
    expect(GStorage.token, 'synthetic-account-token');
  });
}
