// GEORGE: convite por link/código. Logado → gera via API (uso único, expira);
// deslogado → abre o portal /app/invite.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/george/george_api.dart';
import 'package:flutter_hbb/george/george_config.dart';
import 'package:flutter_hbb/george/george_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> showGeorgeInviteDialog(BuildContext context) async {
  if (!GeorgeApi.isLoggedIn) {
    await _showNotLoggedDialog();
    return;
  }
  GeorgeInvite? invite;
  String error = '';
  try {
    final id = await bind.mainGetMyId();
    final temp = isWeb ? '' : await bind.mainGetTemporaryPassword();
    invite = await GeorgeApi.createInvite(deviceId: id, sessionPassword: temp);
    if (invite.code.isEmpty) error = translate('george_invite_failed');
  } catch (e) {
    GeorgeApi.logError('createInvite', e);
    error = translate('george_invite_failed');
  }
  if (error.isNotEmpty || invite == null) {
    showToast(error.isEmpty ? translate('george_invite_failed') : error);
    return;
  }
  final inv = invite;
  gFFI.dialogManager.show((setState, close, context) {
    copy(String s) {
      Clipboard.setData(ClipboardData(text: s));
      showToast(translate('george_invite_copied'));
    }

    final muted = TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        color: GeorgeTheme.mutedForeground(context));
    return CustomAlertDialog(
      title: Row(children: [
        const Icon(Icons.person_add_alt_1_outlined, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Text(translate('george_invite_title'))),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translate('george_invite_desc'),
                style: TextStyle(color: GeorgeTheme.mutedForeground(context))),
            const SizedBox(height: 16),
            Text(translate('george_invite_code').toUpperCase(), style: muted),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(GeorgeTokens.radius),
              onTap: () => copy(inv.code),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration:
                    GeorgeTheme.glass(context, radius: GeorgeTokens.radius),
                child: Row(children: [
                  Expanded(
                    child: SelectableText(
                      inv.code,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                          color: GeorgeTheme.primary(context)),
                    ),
                  ),
                  const Icon(Icons.copy_rounded, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text(translate('george_invite_link').toUpperCase(), style: muted),
            const SizedBox(height: 6),
            SelectableText(inv.webLink, style: const TextStyle(fontSize: 13)),
            if (inv.expiresAt != null && inv.expiresAt!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('${translate('Expires')}: ${inv.expiresAt}',
                    style: TextStyle(
                        fontSize: 12,
                        color: GeorgeTheme.mutedForeground(context))),
              ),
          ],
        ),
      ),
      actions: [
        dialogButton('george_invite_copy_link',
            icon: const Icon(Icons.link, size: 18),
            isOutline: true,
            onPressed: () => copy(inv.webLink)),
        dialogButton('Close', onPressed: close),
      ],
      onCancel: close,
    );
  });
}

Future<void> _showNotLoggedDialog() async {
  gFFI.dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('george_invite')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(translate('george_invite_login_hint')),
      ),
      actions: [
        dialogButton('george_invite_open_portal', isOutline: true,
            onPressed: () {
          close();
          launchUrlString(GeorgeConfig.invitePortalUrl);
        }),
        dialogButton('george_sign_in', onPressed: () async {
          close();
          final ok = await loginDialog();
          if (ok == true && Get.context != null) {
            showGeorgeInviteDialog(Get.context!);
          }
        }),
      ],
      onCancel: close,
    );
  });
}
