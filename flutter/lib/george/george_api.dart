// GEORGE: cliente mínimo da george-api (/api/v1) usado pela UI do cliente.
// Contrato: /srv/george/docs/specs/02-api.md. Campos são lidos de forma
// tolerante (vários nomes) para não quebrar enquanto a API evolui.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/george/george_config.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;

class GeorgeApiException implements Exception {
  GeorgeApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  bool get isNotFound => statusCode == 404 || code == 'not_found';
  bool get isGone =>
      statusCode == 410 ||
      statusCode == 409 ||
      code == 'expired' ||
      code == 'invite_expired' ||
      code == 'invite_used' ||
      code == 'already_used';
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'GeorgeApiException($statusCode, $code, $message)';
}

class GeorgeInvite {
  GeorgeInvite({required this.code, this.link, this.expiresAt});
  final String code;
  final String? link;
  final String? expiresAt;

  String get webLink => link ?? GeorgeConfig.inviteWebLink(code);
  String get deepLink => GeorgeConfig.inviteDeepLink(code);

  static GeorgeInvite fromJson(Map<String, dynamic> j) {
    final inner = j['invite'] is Map ? j['invite'] as Map<String, dynamic> : j;
    final code = (inner['code'] ?? inner['invite_code'] ?? '').toString();
    return GeorgeInvite(
      code: code,
      link: (inner['link'] ?? inner['url'])?.toString(),
      expiresAt: inner['expires_at']?.toString(),
    );
  }
}

class GeorgeInviteTarget {
  GeorgeInviteTarget({required this.id, this.password, this.relay});
  final String id;
  final String? password;
  final bool? relay;

  static GeorgeInviteTarget fromJson(Map<String, dynamic> j) {
    final inner = j['device'] is Map ? j['device'] as Map<String, dynamic> : j;
    final id = (inner['rustdesk_id'] ??
            inner['remote_id'] ??
            inner['device_id'] ??
            inner['peer_id'] ??
            inner['id'] ??
            j['rustdesk_id'] ??
            j['id'] ??
            '')
        .toString();
    final pw = (j['session_password'] ?? j['password'] ?? inner['session_password'])
        ?.toString();
    return GeorgeInviteTarget(
        id: id, password: pw, relay: j['relay'] == true);
  }
}

/// Dispositivo da organização (aba do técnico). Ver docs/specs/06-enrollment.md.
class GeorgeOrgDevice {
  GeorgeOrgDevice(
      {required this.id,
      required this.rustdeskId,
      required this.name,
      this.group = '',
      this.os = '',
      this.online = false});
  final int id;
  final String rustdeskId;
  final String name;
  final String group;
  final String os;
  final bool online;

  static GeorgeOrgDevice fromJson(Map<String, dynamic> j) {
    final alias = (j['alias'] ?? '').toString();
    final rawId = j['id'];
    return GeorgeOrgDevice(
      id: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
      rustdeskId: (j['rustdesk_id'] ?? '').toString(),
      name: alias.isNotEmpty
          ? alias
          : (j['name'] ?? j['hostname'] ?? j['rustdesk_id'] ?? '').toString(),
      group: (j['group_name'] ?? '').toString(),
      os: (j['os'] ?? j['platform'] ?? '').toString(),
      online: j['online'] == true,
    );
  }
}

class GeorgeCredentials {
  GeorgeCredentials({required this.id, this.password});
  final String id;
  final String? password;
}

class GeorgeApi {
  GeorgeApi._();

  static const Duration _timeout = Duration(seconds: 15);

  static String get accessToken => bind.mainGetLocalOption(key: 'access_token');
  static bool get isLoggedIn => accessToken.isNotEmpty;

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = accessToken;
    if (auth && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Map<String, dynamic> _decode(http.Response r) {
    if (r.body.isEmpty) return <String, dynamic>{};
    final v = jsonDecode(r.body);
    return v is Map<String, dynamic> ? v : <String, dynamic>{'data': v};
  }

  static Map<String, dynamic> _check(http.Response r) {
    final body = _decode(r);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final err = body['error'];
    String code = '', msg = '';
    if (err is Map) {
      code = (err['code'] ?? '').toString();
      msg = (err['message'] ?? '').toString();
    } else if (err is String) {
      msg = err;
    } else {
      msg = (body['message'] ?? body['msg'] ?? r.reasonPhrase ?? '').toString();
    }
    throw GeorgeApiException(r.statusCode, code, msg);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final base = await GeorgeConfig.apiBase();
    final r = await http
        .post(Uri.parse('$base$path'),
            headers: _headers(auth: auth), body: jsonEncode(body))
        .timeout(_timeout);
    return _check(r);
  }

  static Future<Map<String, dynamic>> _patch(
      String path, Map<String, dynamic> body) async {
    final base = await GeorgeConfig.apiBase();
    final r = await http
        .patch(Uri.parse('$base$path'),
            headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _check(r);
  }

  static Future<Map<String, dynamic>> _get(String path, {bool auth = true}) async {
    final base = await GeorgeConfig.apiBase();
    final r = await http
        .get(Uri.parse('$base$path'), headers: _headers(auth: auth))
        .timeout(_timeout);
    return _check(r);
  }

  static String platformName() {
    if (isWindows) return 'windows';
    if (isMacOS) return 'macos';
    if (isLinux) return 'linux';
    if (isAndroid) return 'android';
    if (isIOS) return 'ios';
    if (isWeb) return 'web';
    return 'unknown';
  }

  // ---- convites ----

  /// POST /invites — cria convite para este dispositivo. `sessionPassword`
  /// (senha de uso único atual do host) é enviada para a API entregar ao
  /// convidado uma única vez.
  static Future<GeorgeInvite> createInvite(
      {required String deviceId, String? sessionPassword}) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'rustdesk_id': deviceId,
      'max_uses': 1,
      'ttl_minutes': 60,
    };
    if (sessionPassword != null && sessionPassword.isNotEmpty) {
      body['session_password'] = sessionPassword;
    }
    return GeorgeInvite.fromJson(await _post('/invites', body));
  }

  /// POST /invites/{code}/consume — consome o convite e devolve ID + senha.
  static Future<GeorgeInviteTarget> consumeInvite(String code) async {
    final c = Uri.encodeComponent(code.trim().toUpperCase());
    final body = <String, dynamic>{
      'platform': platformName(),
      'client_version': await bind.mainGetVersion(),
    };
    final j = await _post('/invites/$c/consume', body, auth: false);
    final t = GeorgeInviteTarget.fromJson(j);
    if (t.id.isEmpty) {
      // alguns backends devolvem só metadados no consume; tenta o GET público
      final g = GeorgeInviteTarget.fromJson(await _get('/invites/$c', auth: false));
      return GeorgeInviteTarget(id: g.id, password: t.password ?? g.password);
    }
    return t;
  }

  // ---- dispositivos / modo host ----

  /// POST /devices/heartbeat — presença e estado do host.
  static Future<void> heartbeat({required bool hostEnabled}) async {
    if (!isLoggedIn) return;
    final body = <String, dynamic>{
      'id': await bind.mainGetMyId(),
      'uuid': await bind.mainGetUuid(),
      'host_enabled': hostEnabled,
      'platform': platformName(),
      'version': await bind.mainGetVersion(),
    };
    await _post('/devices/heartbeat', body);
  }

  /// PATCH /devices/{id} — persiste host_enabled na conta.
  static Future<void> setHostEnabled(bool enabled) async {
    if (!isLoggedIn) return;
    final id = Uri.encodeComponent(await bind.mainGetMyId());
    await _patch('/devices/$id', {'host_enabled': enabled});
  }

  // ---- organização (técnico) ----

  /// GET /devices?enrolled=true — PCs vinculados à organização.
  static Future<List<GeorgeOrgDevice>> orgDevices() async {
    final j = await _get('/devices?enrolled=true&per_page=500');
    final data = j['data'];
    final List list = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : []);
    return list
        .whereType<Map>()
        .map((m) => GeorgeOrgDevice.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /devices/{id}/credentials — ID + senha permanente (auditado na API).
  static Future<GeorgeCredentials> deviceCredentials(int id) async {
    final j = await _get('/devices/$id/credentials');
    final d = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : j;
    return GeorgeCredentials(
        id: (d['rustdesk_id'] ?? '').toString(),
        password: d['password']?.toString());
  }

  static void logError(String where, Object e) {
    debugPrint('[george-api] $where: $e');
  }
}
