// GEORGE: barra fina de avisos no topo da janela (permissões, atualização,
// serviço). Substitui os cartões grandes do upstream que ficavam no fim do
// painel esquerdo (era preciso rolar para ver). Um aviso por linha, discreto,
// com ação principal à direita.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/george/george_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum GeorgeNoticeKind { info, warning, update }

class GeorgeNoticeBar extends StatelessWidget {
  const GeorgeNoticeBar({
    Key? key,
    required this.text,
    this.title,
    this.kind = GeorgeNoticeKind.info,
    this.actionLabel,
    this.onAction,
    this.helpLabel,
    this.helpUrl,
    this.onClose,
  }) : super(key: key);

  final String text;
  final String? title;
  final GeorgeNoticeKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? helpLabel;
  final String? helpUrl;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData icon;
    switch (kind) {
      case GeorgeNoticeKind.warning:
        accent = GeorgeTheme.warning(context);
        icon = Icons.shield_outlined;
        break;
      case GeorgeNoticeKind.update:
        accent = GeorgeTheme.primary(context);
        icon = Icons.system_update_alt;
        break;
      case GeorgeNoticeKind.info:
        accent = GeorgeTheme.primary(context);
        icon = Icons.info_outline;
        break;
    }
    final muted = GeorgeTheme.mutedForeground(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        border: Border(bottom: BorderSide(color: accent.withOpacity(0.28))),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Tooltip(
            message: text,
            waitDuration: const Duration(milliseconds: 600),
            child: Text.rich(
              TextSpan(children: [
                if (title != null && title!.isNotEmpty)
                  TextSpan(
                      text: '$title  ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: text),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: GeorgeTheme.foreground(context)),
            ),
          ),
        ),
        if (helpUrl != null && helpLabel != null)
          TextButton(
            onPressed: () => launchUrlString(helpUrl!),
            style: TextButton.styleFrom(
                foregroundColor: muted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30)),
            child: Text(helpLabel!, style: const TextStyle(fontSize: 12)),
          ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 4),
          SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 30),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: Text(actionLabel!),
            ),
          ),
        ],
        if (onClose != null)
          IconButton(
            tooltip: translate('Close'),
            onPressed: onClose,
            iconSize: 16,
            splashRadius: 16,
            color: muted,
            icon: const Icon(Icons.close),
          )
        else
          const SizedBox(width: 8),
      ]),
    );
  }
}

/// Aviso de nova versão: "Atualizar agora" baixa, confere a assinatura e
/// instala em silêncio (Windows/macOS instalados); senão abre a página.
class GeorgeUpdateNotice extends StatefulWidget {
  const GeorgeUpdateNotice({Key? key}) : super(key: key);

  @override
  State<GeorgeUpdateNotice> createState() => _GeorgeUpdateNoticeState();
}

class _GeorgeUpdateNoticeState extends State<GeorgeUpdateNotice> {
  String _dismissedUrl = '';

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final url = stateGlobal.updateUrl.value;
      if (url.isEmpty || url == _dismissedUrl) return const SizedBox.shrink();
      final inApp = (isWindows || isMacOS) && bind.mainIsInstalled();
      return GeorgeNoticeBar(
        kind: GeorgeNoticeKind.update,
        title: translate('george_update_available'),
        text: bind.mainGetNewVersion(),
        actionLabel:
            translate(inApp ? 'george_update_now' : 'george_update_download'),
        onAction: () => inApp ? handleUpdate(url) : launchUrlString(url),
        onClose: () => setState(() => _dismissedUrl = url),
      );
    });
  }
}
