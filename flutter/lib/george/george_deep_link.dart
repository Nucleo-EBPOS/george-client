// GEORGE: protocolo `george://` e `/web?code=`.
//   george://connect?code=AB7K2        → consome convite na API → conecta
//   george://connect?id=123456789&pw=x → conecta direto
// Também aceito no campo "Conectar" da tela inicial (código de convite).
import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/george/george_api.dart';
import 'package:flutter_hbb/george/george_config.dart';
import 'package:flutter_hbb/george/george_enroll.dart';
import 'package:get/get.dart';

/// Hook chamado no início de `handleUriLink` (common.dart).
/// Retorna true quando o link é do George e foi tratado (assíncrono).
bool georgeTryHandleUriLink(
    {List<String>? cmdArgs, Uri? uri, String? uriString}) {
  Uri? u = uri;
  if (u == null && uriString != null) u = Uri.tryParse(uriString.trim());
  if (u == null && cmdArgs != null && cmdArgs.isNotEmpty) {
    u = Uri.tryParse(cmdArgs.first.trim());
  }
  if (u == null) return false;
  if (u.scheme.toLowerCase() != GeorgeConfig.deepLinkScheme) return false;
  final action = (u.host.isNotEmpty ? u.host : u.path).replaceAll('/', '');
  // george://enroll/XXXX-XXXX-XXXX  ou  george://enroll?code=… → configurar este PC
  if (u.host.toLowerCase() == 'enroll' ||
      (u.host.isEmpty && u.pathSegments.isNotEmpty &&
          u.pathSegments.first.toLowerCase() == 'enroll')) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    final fromPath = u.host.isEmpty
        ? (segs.length > 1 ? segs[1] : '')
        : (segs.isNotEmpty ? segs.first : '');
    final code = u.queryParameters['code'] ?? fromPath;
    _openSetupWhenReady(code);
    return true;
  }
  if (action.toLowerCase() != 'connect') return false;
  final q = u.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), v));
  final code = q['code'];
  final id = q['id'];
  final pw = q['pw'] ?? q['password'];
  if (code != null && code.trim().isNotEmpty) {
    georgeConnectWithInvite(code);
    return true;
  }
  if (id != null && id.trim().isNotEmpty) {
    _connectWhenReady(id.trim(), pw);
    return true;
  }
  return false;
}

/// Web client: `/web?code=…` (ou `?id=&pw=`).
bool georgeHandleWebQuery() {
  if (!isWeb) return false;
  try {
    final q =
        Uri.base.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), v));
    final code = q['code'];
    if (code != null && code.trim().isNotEmpty) {
      georgeConnectWithInvite(code);
      return true;
    }
    final id = q['id'];
    if (id != null && id.trim().isNotEmpty) {
      _connectWhenReady(id.trim(), q['pw'] ?? q['password']);
      return true;
    }
  } catch (e) {
    debugPrint('[george] web query: $e');
  }
  return false;
}

/// Consome o convite na API e conecta com a senha de uso único.
Future<void> georgeConnectWithInvite(String code) async {
  final c = code.trim().toUpperCase();
  showToast(translate('george_invite_consuming'));
  try {
    final target = await GeorgeApi.consumeInvite(c);
    if (target.id.isEmpty) {
      showToast(translate('george_invite_invalid'));
      return;
    }
    await _connectWhenReady(target.id, target.password,
        forceRelay: target.relay == true);
  } on GeorgeApiException catch (e) {
    GeorgeApi.logError('consumeInvite', e);
    if (e.isNotFound) {
      showToast(translate('george_invite_invalid'));
    } else if (e.isGone) {
      showToast(translate('george_invite_expired'));
    } else {
      showToast('${translate('george_invite_failed')} (${e.statusCode})');
    }
  } catch (e) {
    GeorgeApi.logError('consumeInvite', e);
    showToast(translate('george_invite_failed'));
  }
}

Future<void> _connectWhenReady(String id, String? password,
    {bool forceRelay = false}) async {
  // Na inicialização por link o contexto pode demorar um instante.
  for (var i = 0; i < 50 && Get.context == null; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  final ctx = Get.context;
  if (ctx == null) return;
  await connect(ctx, id, password: password, forceRelay: forceRelay);
}

Future<void> _openSetupWhenReady(String code) async {
  for (var i = 0; i < 50 && Get.context == null; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  final ctx = Get.context;
  if (ctx == null) return;
  await showGeorgeSetupDialog(ctx, code: code.trim().isEmpty ? null : code);
}
