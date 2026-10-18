// GEORGE: cabeçalho da tela inicial (painel esquerdo do desktop):
// logo + conta, ID grande e copiável, card Modo Host ON/OFF com status,
// campo "Conectar a um ID / código de convite", botão Convidar e aviso de
// atualização. A lista de computadores (recentes/favoritos/catálogo = "Meus
// computadores") continua sendo a ConnectionPage upstream à direita.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/george/george_config.dart';
import 'package:flutter_hbb/george/george_deep_link.dart';
import 'package:flutter_hbb/george/george_enroll.dart';
import 'package:flutter_hbb/george/george_host_mode.dart';
import 'package:flutter_hbb/george/george_invite.dart';
import 'package:flutter_hbb/george/george_theme.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Largura do painel esquerdo da home (upstream: 200).
const double kGeorgeLeftPaneWidth = 320.0;

class GeorgeHomeHero extends StatefulWidget {
  const GeorgeHomeHero({Key? key, this.isOutgoingOnly = false})
      : super(key: key);

  final bool isOutgoingOnly;

  @override
  State<GeorgeHomeHero> createState() => _GeorgeHomeHeroState();
}

class _GeorgeHomeHeroState extends State<GeorgeHomeHero> {
  final _connectCtrl = TextEditingController();
  final _connectFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    GeorgeHostController.to; // garante o controller (poll + heartbeat)
    if (!widget.isOutgoingOnly) {
      GeorgeEnrollController.to;
      // primeiro uso: "Configurar este computador" (uma vez, só instalado e não vinculado)
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => georgeMaybeShowFirstRunSetup(context));
    }
  }

  @override
  void dispose() {
    _connectCtrl.dispose();
    _connectFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 14),
          if (!widget.isOutgoingOnly) _idCard(context),
          if (!widget.isOutgoingOnly) const SizedBox(height: 10),
          if (!widget.isOutgoingOnly) _hostCard(context),
          if (!widget.isOutgoingOnly) const SizedBox(height: 10),
          if (!widget.isOutgoingOnly) const GeorgeThisPcCard(),
          if (!widget.isOutgoingOnly) const SizedBox(height: 14),
          _connectRow(context),
          const SizedBox(height: 8),
          _inviteButton(context),
          const GeorgeOrgDevicesButton(),
          _updateBanner(context),
        ],
      ),
    );
  }

  // ---------- cabeçalho ----------
  Widget _header(BuildContext context) {
    final dark = GeorgeTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                dark
                    ? 'assets/george/george-logo-white.png'
                    : 'assets/george/george-logo.png',
                height: 34,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Text(GeorgeConfig.appName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text(translate('george_tagline'),
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .3,
                      color: GeorgeTheme.mutedForeground(context))),
            ],
          ),
        ),
        const GeorgeThemeToggle(),
        const SizedBox(width: 2),
        const GeorgeAccountButton(),
      ],
    );
  }

  // ---------- ID ----------
  Widget _idCard(BuildContext context) {
    return Consumer<ServerModel>(builder: (context, model, _) {
      final id = model.serverId.text;
      copyId() {
        Clipboard.setData(ClipboardData(text: id.replaceAll(' ', '')));
        showToast(translate('george_id_copied'));
      }

      return Container(
        decoration: GeorgeTheme.glass(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate('george_your_id').toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: GeorgeTheme.mutedForeground(context))),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onDoubleTap: copyId,
                    child: SelectableText(
                      id.isEmpty ? '—' : id,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: GeorgeTheme.foreground(context)),
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: translate('george_copy_id'),
              child: InkWell(
                borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
                onTap: copyId,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.copy_rounded,
                      size: 20, color: GeorgeTheme.primary(context)),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ---------- Modo Host ----------
  Widget _hostCard(BuildContext context) {
    final c = GeorgeHostController.to;
    return Obx(() {
      // observa também o status do serviço e o login
      stateGlobal.svcStatus.value;
      gFFI.userModel.userName.value;
      final on = c.enabled.value;
      final st = c.status;
      Color dot;
      switch (st) {
        case GeorgeHostStatus.online:
        case GeorgeHostStatus.accepting:
          dot = GeorgeTheme.success(context);
          break;
        case GeorgeHostStatus.starting:
          dot = GeorgeTheme.warning(context);
          break;
        case GeorgeHostStatus.stopped:
          dot = GeorgeTheme.mutedForeground(context);
          break;
      }
      return Container(
        decoration: GeorgeTheme.glass(context),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(translate('george_host_mode').toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: GeorgeTheme.mutedForeground(context))),
                ),
                Text(on ? 'ON' : 'OFF',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: on
                            ? GeorgeTheme.primary(context)
                            : GeorgeTheme.mutedForeground(context))),
                SizedBox(
                  height: 44,
                  child: Switch(
                    value: on,
                    onChanged: c.busy.value ? null : (v) => c.setEnabled(v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: dot, borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.statusLabel(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              translate(on ? 'george_host_desc_on' : 'george_host_desc_off'),
              style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: GeorgeTheme.mutedForeground(context)),
            ),
          ],
        ),
      );
    });
  }

  // ---------- Conectar ----------
  void _submitConnect() {
    final text = _connectCtrl.text.trim();
    if (text.isEmpty) return;
    if (GeorgeConfig.looksLikeInviteCode(text)) {
      georgeConnectWithInvite(text);
    } else {
      connect(context, text.replaceAll(' ', ''));
    }
  }

  Widget _connectRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(translate('george_connect_to_id'),
            style: TextStyle(
                fontSize: 12, color: GeorgeTheme.mutedForeground(context))),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _connectCtrl,
                  focusNode: _connectFocus,
                  onSubmitted: (_) => _submitConnect(),
                  textInputAction: TextInputAction.go,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'ID / ${translate('george_invite_code')}',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _submitConnect,
                child: Text(translate('george_connect')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inviteButton(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => showGeorgeInviteDialog(context),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
        label: Text(translate('george_invite')),
      ),
    );
  }

  // ---------- atualização ----------
  Widget _updateBanner(BuildContext context) {
    return Obx(() {
      final url = stateGlobal.updateUrl.value;
      if (url.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: GeorgeTheme.primary(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(GeorgeTokens.radius),
          border: Border.all(
              color: GeorgeTheme.primary(context).withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${translate('george_update_available')} (${bind.mainGetNewVersion()})',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: TextButton.icon(
                onPressed: () => launchUrlString(url),
                icon: const Icon(Icons.system_update_alt, size: 16),
                label: Text(translate('george_update_download')),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Avatar/botão de conta no canto (login, "Meus computadores", sair).
class GeorgeAccountButton extends StatelessWidget {
  const GeorgeAccountButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (bind.isDisableAccount()) return const SizedBox.shrink();
    return Obx(() {
      final name = gFFI.userModel.userName.value;
      if (name.isEmpty) {
        return SizedBox(
          height: 44,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await loginDialog();
              if (ok == true) GeorgeHostController.to.onAccountChanged();
            },
            icon: const Icon(Icons.account_circle_outlined, size: 20),
            label: Text(translate('george_sign_in')),
          ),
        );
      }
      final label = gFFI.userModel.displayNameOrUserName;
      final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
      return PopupMenuButton<String>(
        tooltip: label,
        offset: const Offset(0, 46),
        onSelected: (v) async {
          if (v == 'computers') {
            gFFI.peerTabModel.setCurrentTab(PeerTabIndex.ab.index);
            showToast(translate('george_my_computers_hint'));
          } else if (v == 'logout') {
            await gFFI.userModel.logOut();
            GeorgeHostController.to.onAccountChanged();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: false,
            child: Text(gFFI.userModel.accountLabelWithHandle,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'computers',
            child: Row(children: [
              const Icon(Icons.devices_other_outlined, size: 18),
              const SizedBox(width: 8),
              Text(translate('george_my_computers')),
            ]),
          ),
          PopupMenuItem(
            value: 'logout',
            child: Row(children: [
              const Icon(Icons.logout, size: 18),
              const SizedBox(width: 8),
              Text(translate('george_sign_out')),
            ]),
          ),
        ],
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: CircleAvatar(
              radius: 17,
              backgroundColor: GeorgeTheme.primary(context),
              child: Text(initial,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GeorgeTheme.isDark(context)
                          ? GeorgeTokens.darkOnPrimary
                          : Colors.white)),
            ),
          ),
        ),
      );
    });
  }
}

/// GEORGE: alterna o tema (sistema → claro → escuro) no cabeçalho. Persiste a
/// escolha (kCommConfKeyTheme) e aplica ao vivo via MyTheme.changeDarkMode.
class GeorgeThemeToggle extends StatefulWidget {
  const GeorgeThemeToggle({Key? key}) : super(key: key);

  @override
  State<GeorgeThemeToggle> createState() => _GeorgeThemeToggleState();
}

class _GeorgeThemeToggleState extends State<GeorgeThemeToggle> {
  @override
  Widget build(BuildContext context) {
    final mode = MyTheme.getThemeModePreference();
    IconData icon;
    String label;
    switch (mode) {
      case ThemeMode.light:
        icon = Icons.light_mode_outlined;
        label = translate('george_theme_light');
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode_outlined;
        label = translate('george_theme_dark');
        break;
      case ThemeMode.system:
      default:
        icon = Icons.brightness_auto_outlined;
        label = translate('george_theme_system');
        break;
    }
    return Tooltip(
      message: '${translate('george_theme')}: $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
        onTap: () async {
          final next = mode == ThemeMode.system
              ? ThemeMode.light
              : mode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.system;
          await MyTheme.changeDarkMode(next);
          if (mounted) setState(() {});
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: GeorgeTheme.foreground(context)),
        ),
      ),
    );
  }
}
