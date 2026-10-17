// GEORGE: constantes do produto usadas pela UI. O servidor/chave reais ficam
// embutidos no lado Rust (src/george/mod.rs); aqui só o que a UI precisa.
import 'package:flutter_hbb/models/platform_model.dart';

class GeorgeConfig {
  GeorgeConfig._();

  static const String appName = 'George';
  static const String tagline = 'your remote support';
  static const String siteUrl = 'https://georgedesk.com';
  static const String privacyUrl = 'https://georgedesk.com/privacidade';
  static const String supportUrl = 'https://georgedesk.com/suporte';
  static const String sourceUrl = 'https://github.com/Nucleo-EBPOS/george-client';
  static const String upstreamUrl = 'https://github.com/rustdesk/rustdesk';
  static const String invitePortalUrl = 'https://georgedesk.com/app/invite';
  static const String releasesUrl =
      'https://github.com/Nucleo-EBPOS/george-client/releases/latest';
  static const String copyright =
      'Copyright © 2026 George (georgedesk.com). Baseado no RustDesk, AGPL-3.0.';
  static const String deepLinkScheme = 'george';
  /// Checagem de atualização via manifest da george-api (ver src/george/mod.rs).
  static const bool checksUpdates = true;

  /// Base da API George (`/api/v1`) derivada do api-server embutido.
  static Future<String> apiBase() async {
    var server = (await bind.mainGetApiServer()).trim();
    if (server.isEmpty) server = siteUrl;
    while (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }
    return '$server/api/v1';
  }

  /// Link que o convidado abre no navegador (`/web?code=`): a página web
  /// tenta `george://connect?code=` e oferece download/web client.
  static String inviteWebLink(String code) => '$siteUrl/web?code=$code';

  static String inviteDeepLink(String code) =>
      '$deepLinkScheme://connect?code=$code';

  /// Convite: 5 a 10 caracteres base32 sem ambíguos (sem 0/1/O/I), ao menos
  /// uma letra — para distinguir de um ID numérico do RustDesk.
  static final RegExp inviteCodeRe = RegExp(r'^[A-Z2-9]{5,10}$');

  static bool looksLikeInviteCode(String s) {
    final t = s.trim().toUpperCase();
    return inviteCodeRe.hasMatch(t) && t.contains(RegExp(r'[A-Z]'));
  }
}
