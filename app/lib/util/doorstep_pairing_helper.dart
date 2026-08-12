import 'dart:convert';
import 'dart:math';

class DoorstepPairingPayload {
  final String deviceId;
  final String alias;
  final String ip;
  final int port;
  final String fingerprint;
  final String token;
  final DateTime timestamp;

  DoorstepPairingPayload({
    required this.deviceId,
    required this.alias,
    required this.ip,
    required this.port,
    required this.fingerprint,
    required this.token,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': deviceId,
    'alias': alias,
    'ip': ip,
    'port': port,
    'fp': fingerprint,
    'token': token,
    'ts': timestamp.toIso8601String(),
  };

  factory DoorstepPairingPayload.fromJson(Map<String, dynamic> json) => DoorstepPairingPayload(
    deviceId: json['id'] as String,
    alias: json['alias'] as String,
    ip: json['ip'] as String,
    port: json['port'] as int,
    fingerprint: json['fp'] as String,
    token: json['token'] as String,
    timestamp: DateTime.parse(json['ts'] as String),
  );

  String encode() {
    final str = jsonEncode(toJson());
    return base64Url.encode(utf8.encode(str));
  }

  static DoorstepPairingPayload? decode(String raw) {
    try {
      final decodedStr = utf8.decode(base64Url.decode(raw));
      final map = jsonDecode(decodedStr) as Map<String, dynamic>;
      return DoorstepPairingPayload.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Generates a random device token using secure random bytes encoded as base64.
  static String generateDeviceToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// The two-way pairing handshake.
///
/// LocalSend's `register` endpoint has no field for a pairing token, so the
/// phone smuggles one in the `deviceModel` field using this carrier:
///
/// ```
/// <deviceModel>|doorstep=<laptopToken>.<phoneToken>
/// ```
///
/// The laptop parses it back out, verifies that the laptop token is its own
/// (proving the phone actually scanned its QR code), and stores the phone's
/// token as the trust anchor for the reverse direction. Devices without the
/// carrier are ignored by the pairing layer — they register normally.
class DoorstepPairingHandshake {
  /// The token of the laptop whose QR code was scanned.
  final String laptopToken;

  /// The phone's own persistent token.
  final String phoneToken;

  /// The real device model, with the carrier stripped off.
  final String cleanDeviceModel;

  const DoorstepPairingHandshake({
    required this.laptopToken,
    required this.phoneToken,
    required this.cleanDeviceModel,
  });

  static const _separator = '|doorstep=';

  /// Encodes [deviceModel] plus the handshake tokens into the register payload's
  /// `deviceModel` field.
  static String encode(String deviceModel, {required String laptopToken, required String phoneToken}) {
    return '$deviceModel$_separator$laptopToken.$phoneToken';
  }

  /// Parses the carrier out of a register payload's `deviceModel` field.
  /// Returns `null` when the register is not a Doorstep pairing handshake.
  static DoorstepPairingHandshake? parse(String? deviceModel) {
    if (deviceModel == null) return null;
    final index = deviceModel.indexOf(_separator);
    if (index == -1) return null;

    final cleanDeviceModel = deviceModel.substring(0, index);
    final tokens = deviceModel.substring(index + _separator.length).split('.');
    if (tokens.length != 2 || tokens[0].isEmpty || tokens[1].isEmpty) {
      return null;
    }
    return DoorstepPairingHandshake(
      laptopToken: tokens[0],
      phoneToken: tokens[1],
      cleanDeviceModel: cleanDeviceModel,
    );
  }
}
