import 'package:doorstep_app/model/cross_file.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/state/nearby_devices_state.dart';
import 'package:doorstep_app/provider/doorstep_quick_send_provider.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:test/test.dart';

void main() {
  group('isPairedDeviceOnline', () {
    final devices = <String, Device>{
      '192.168.1.10': _device(fingerprint: 'aaa', ip: '192.168.1.10'),
    };
    final signalingDevices = <String, Set<Device>>{
      'bbb': {_device(fingerprint: 'bbb', ip: '10.0.0.2')},
    };
    final nearby = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: devices,
      signalingDevices: signalingDevices,
    );

    test('true when discovered over LAN', () {
      expect(isPairedDeviceOnline(_paired(fingerprint: 'aaa'), nearby), isTrue);
    });

    test('true when discovered via signaling', () {
      expect(isPairedDeviceOnline(_paired(fingerprint: 'bbb'), nearby), isTrue);
    });

    test('false when not discovered', () {
      expect(isPairedDeviceOnline(_paired(fingerprint: 'ccc'), nearby), isFalse);
    });

    test('false when the discovered ip is "-"', () {
      final dashNearby = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {'192.168.1.10': _device(fingerprint: 'aaa', ip: '-')},
        signalingDevices: const {},
      );
      expect(isPairedDeviceOnline(_paired(fingerprint: 'aaa'), dashNearby), isFalse);
    });
  });

  group('onlineTrustedDevicesOf', () {
    final nearby = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '192.168.1.10': _device(fingerprint: 'aaa', ip: '192.168.1.10'),
        '192.168.1.11': _device(fingerprint: 'bbb', ip: '192.168.1.11'),
      },
      signalingDevices: const {},
    );

    test('keeps only persistent devices that are online', () {
      final paired = [
        _paired(fingerprint: 'aaa'),
        _paired(fingerprint: 'bbb', trustLevel: DeviceTrustLevel.temporary),
        _paired(fingerprint: 'ccc'),
      ];
      final online = onlineTrustedDevicesOf(paired, nearby);
      expect(online.map((d) => d.fingerprint), ['aaa']);
    });

    test('empty when none are online', () {
      expect(onlineTrustedDevicesOf([_paired(fingerprint: 'ccc')], nearby), isEmpty);
    });
  });

  group('mergeQuickSendFiles', () {
    test('dedupes by path and keeps order', () {
      final a = [_file(path: '/x/a.txt')];
      final b = [_file(path: '/x/a.txt'), _file(path: '/x/b.txt')];
      final merged = mergeQuickSendFiles(a, b);
      expect(merged.map((f) => f.path), ['/x/a.txt', '/x/b.txt']);
    });
  });
}

PairedDevice _paired({required String fingerprint, DeviceTrustLevel trustLevel = DeviceTrustLevel.persistent}) {
  return PairedDevice(
    id: fingerprint,
    alias: 'Device $fingerprint',
    fingerprint: fingerprint,
    token: 'token',
    lastKnownIp: '192.168.1.10',
    port: 53317,
    lastSeen: DateTime.now(),
    trustLevel: trustLevel,
  );
}

Device _device({required String fingerprint, required String ip}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: protocolVersion,
    port: 53317,
    https: true,
    fingerprint: fingerprint,
    alias: 'Device $fingerprint',
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: const {},
  );
}

CrossFile _file({required String path}) {
  return CrossFile(
    name: 'file.txt',
    fileType: FileType.text,
    size: 1,
    thumbnail: null,
    asset: null,
    path: path,
    bytes: null,
    lastModified: null,
    lastAccessed: null,
  );
}
