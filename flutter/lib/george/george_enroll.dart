// GEORGE: "Este computador" — acesso não-assistido, vínculo à organização
// (enrollment) e login automático do Windows (avançado, desligado por padrão).
// Para o técnico logado: "Dispositivos da organização" com conexão em 1 clique.
// O vínculo em si roda no serviço (src/george/agent.rs); aqui a UI só entrega
// o código e lê o estado publicado em options (sem segredos).
// Contrato: docs/specs/06-enrollment.md (monorepo george).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/george/george_api.dart';
import 'package:flutter_hbb/george/george_host_mode.dart';
import 'package:flutter_hbb/george/george_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

const String kGeorgeOptEnrollCode = 'george-enroll-code';
const String kGeorgeOptEnrollStatus = 'george-enroll-status';
const String kGeorgeOptEnrolled = 'george-enrolled';
const String kGeorgeOptOrgName = 'george-org-name';
const String kGeorgeOptDeviceName = 'george-device-name';
const String kGeorgeOptGroupName = 'george-group-name';
const String kGeorgeLocalSetupSeen = 'george-setup-seen';

/// Código de vínculo: 12 caracteres base32 sem ambíguos, com ou sem hífens.
final RegExp _enrollCodeRe = RegExp(r'^[A-Z2-9]{4}-?[A-Z2-9]{4}-?[A-Z2-9]{4}$');

String georgeNormalizeEnrollCode(String s) {
  final t = s.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (t.length != 12) return s.trim().toUpperCase();
  return '${t.substring(0, 4)}-${t.substring(4, 8)}-${t.substring(8, 12)}';
}

bool georgeLooksLikeEnrollCode(String s) =>
    _enrollCodeRe.hasMatch(s.trim().toUpperCase());

class GeorgeEnrollController extends GetxController {
  static GeorgeEnrollController get to {
    if (!Get.isRegistered<GeorgeEnrollController>()) {
      Get.put(GeorgeEnrollController(), permanent: true);
    }
    return Get.find<GeorgeEnrollController>();
  }

  final enrolled = false.obs;
  final orgName = ''.obs;
  final deviceName = ''.obs;
  final groupName = ''.obs;
  final busy = false.obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _timer = periodic_immediate(const Duration(seconds: 3), refresh);
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> refresh() async {
    enrolled.value = (await bind.mainGetOption(key: kGeorgeOptEnrolled)) == 'Y';
    orgName.value = await bind.mainGetOption(key: kGeorgeOptOrgName);
    deviceName.value = await bind.mainGetOption(key: kGeorgeOptDeviceName);
    groupName.value = await bind.mainGetOption(key: kGeorgeOptGroupName);
  }

  /// Entrega o código ao serviço e espera o resultado (até 30 s).
  /// Devolve "ok", "error:<código>:<mensagem>" ou "timeout".
  Future<String> enroll(String code) async {
    if (busy.value) return 'busy';
    busy.value = true;
    try {
      await bind.mainSetOption(key: kGeorgeOptEnrollStatus, value: '');
      await bind.mainSetOption(
          key: kGeorgeOptEnrollCode, value: georgeNormalizeEnrollCode(code));
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 700));
        final s = await bind.mainGetOption(key: kGeorgeOptEnrollStatus);
        if (s == 'ok' || s.startsWith('error:')) {
          await refresh();
          return s;
        }
      }
      return 'timeout';
    } finally {
      busy.value = false;
    }
  }

  static String errorText(String status) {
    final parts = status.split(':');
    final code = parts.length > 1 ? parts[1] : status;
    switch (code) {
      case 'enrollment_key_invalid':
      case 'not_found':
        return translate('george_enroll_err_invalid');
      case 'device_other_org':
        return translate('george_enroll_err_other_org');
      case 'plan_limit_reached':
        return translate('george_enroll_err_plan');
      case 'device_revoked':
        return translate('george_enroll_err_revoked');
      case 'timeout':
        return translate('george_enroll_err_timeout');
      default:
        return translate('george_enroll_err_network');
    }
  }
}

/// Cartão compacto "Este computador" no painel esquerdo da tela inicial.
class GeorgeThisPcCard extends StatelessWidget {
  const GeorgeThisPcCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GeorgeEnrollController.to;
    return Obx(() {
      if (!c.enrolled.value) {
        return SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => showGeorgeSetupDialog(context),
            icon: const Icon(Icons.settings_suggest_outlined, size: 18),
            label: Text(translate('george_setup_this_pc')),
          ),
        );
      }
      final sub = [c.deviceName.value, c.groupName.value]
          .where((s) => s.isNotEmpty)
          .join(' · ');
      return InkWell(
        borderRadius: BorderRadius.circular(GeorgeTokens.radius),
        onTap: () => showGeorgeSetupDialog(context),
        child: Container(
          decoration: GeorgeTheme.glass(context),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Icon(Icons.verified_user_outlined,
                size: 20, color: GeorgeTheme.success(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${translate('george_enrolled_to')} ${c.orgName.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: GeorgeTheme.mutedForeground(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: GeorgeTheme.mutedForeground(context)),
          ]),
        ),
      );
    });
  }
}

/// Primeiro uso: abre a configuração uma vez em PCs instalados e não vinculados.
Future<void> georgeMaybeShowFirstRunSetup(BuildContext context) async {
  if (!isDesktop) return;
  if (bind.mainGetLocalOption(key: kGeorgeLocalSetupSeen) == 'Y') return;
  if (!bind.mainIsInstalled()) return;
  final c = GeorgeEnrollController.to;
  await c.refresh();
  await bind.mainSetLocalOption(key: kGeorgeLocalSetupSeen, value: 'Y');
  if (c.enrolled.value) return;
  if (!context.mounted) return;
  await showGeorgeSetupDialog(context);
}

Future<void> showGeorgeSetupDialog(BuildContext context, {String? code}) {
  return showDialog(
    context: context,
    builder: (_) => _GeorgeSetupDialog(initialCode: code),
  );
}

class _GeorgeSetupDialog extends StatefulWidget {
  const _GeorgeSetupDialog({Key? key, this.initialCode}) : super(key: key);
  final String? initialCode;

  @override
  State<_GeorgeSetupDialog> createState() => _GeorgeSetupDialogState();
}

class _GeorgeSetupDialogState extends State<_GeorgeSetupDialog> {
  final _codeCtrl = TextEditingController();
  String _msg = '';
  bool _msgError = false;
  String _autologon = 'off';

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = georgeNormalizeEnrollCode(widget.initialCode!);
    }
    GeorgeHostController.to;
    GeorgeEnrollController.to.refresh();
    if (isWindows) _autologon = bind.mainGeorgeAutologonStatus();
    if (widget.initialCode != null &&
        georgeLooksLikeEnrollCode(widget.initialCode!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enroll());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    final code = _codeCtrl.text.trim();
    if (!georgeLooksLikeEnrollCode(code)) {
      setState(() {
        _msg = translate('george_enroll_err_format');
        _msgError = true;
      });
      return;
    }
    setState(() {
      _msg = translate('george_enroll_working');
      _msgError = false;
    });
    final r = await GeorgeEnrollController.to.enroll(code);
    if (!mounted) return;
    final c = GeorgeEnrollController.to;
    setState(() {
      if (r == 'ok') {
        _msg =
            '${translate('george_enrolled_to')} ${c.orgName.value} — ${c.deviceName.value}';
        _msgError = false;
        _codeCtrl.clear();
      } else {
        _msg = GeorgeEnrollController.errorText(r);
        _msgError = true;
      }
    });
    // Vincular já liga o acesso não-assistido (é o que a org espera do PC).
    if (r == 'ok' && !GeorgeHostController.to.enabled.value) {
      await GeorgeHostController.to.setEnabled(true);
    }
  }

  Widget _section(BuildContext context,
      {required IconData icon,
      required String title,
      required String desc,
      Widget? trailing,
      Widget? body}) {
    return Container(
      decoration: GeorgeTheme.glass(context),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: GeorgeTheme.primary(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: GeorgeTheme.mutedForeground(context))),
                ]),
          ),
          if (trailing != null) trailing,
        ]),
        if (body != null) ...[const SizedBox(height: 10), body],
      ]),
    );
  }

  Widget _unattended(BuildContext context) {
    final h = GeorgeHostController.to;
    final installed = !isDesktop || bind.mainIsInstalled();
    return Obx(() => _section(
          context,
          icon: Icons.power_settings_new,
          title: translate('george_unattended_title'),
          desc: installed
              ? translate('george_unattended_desc')
              : translate('george_unattended_need_install'),
          trailing: Switch(
            value: h.enabled.value,
            onChanged: (h.busy.value || !installed)
                ? null
                : (v) => h.setEnabled(v),
          ),
        ));
  }

  Widget _enrollSection(BuildContext context) {
    final c = GeorgeEnrollController.to;
    return Obx(() {
      final enrolled = c.enrolled.value;
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (enrolled)
            Text(
                '${translate('george_enrolled_to')} ${c.orgName.value}\n'
                '${c.deviceName.value}${c.groupName.value.isEmpty ? '' : ' · ${c.groupName.value}'}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          if (!enrolled)
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _codeCtrl,
                    enabled: !c.busy.value,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _enroll(),
                    style: const TextStyle(fontSize: 15, letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
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
                  onPressed: c.busy.value ? null : _enroll,
                  child: c.busy.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(translate('george_enroll_button')),
                ),
              ),
            ]),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_msg,
                style: TextStyle(
                    fontSize: 12,
                    color: _msgError
                        ? GeorgeTheme.destructive(context)
                        : GeorgeTheme.success(context))),
          ],
        ],
      );
      return _section(
        context,
        icon: Icons.apartment_outlined,
        title: translate('george_enroll_title'),
        desc: translate(
            enrolled ? 'george_enroll_desc_done' : 'george_enroll_desc'),
        body: body,
      );
    });
  }

  Widget _advanced(BuildContext context) {
    if (!isWindows) return const SizedBox.shrink();
    final on = _autologon.startsWith('on');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(translate('george_advanced'),
            style: TextStyle(
                fontSize: 13, color: GeorgeTheme.mutedForeground(context))),
        children: [
          _section(
            context,
            icon: Icons.login,
            title: translate('george_autologon_title'),
            desc: on
                ? '${translate('george_autologon_on')} ${_autologon.substring(3)}'
                : translate('george_autologon_desc'),
            trailing: Switch(
              value: on,
              onChanged: (v) async {
                if (v) {
                  final ok = await _showAutologonDialog(context);
                  if (!ok) return;
                } else {
                  final r = await bind.mainGeorgeSetAutologon(
                      user: '', domain: '', password: '');
                  if (r != 'Y') {
                    showToast('${translate('george_autologon_failed')} $r');
                  }
                }
                if (mounted) {
                  setState(
                      () => _autologon = bind.mainGeorgeAutologonStatus());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(translate('george_setup_title')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(translate('george_setup_desc'),
                  style: TextStyle(
                      fontSize: 13,
                      color: GeorgeTheme.mutedForeground(context))),
              const SizedBox(height: 14),
              _unattended(context),
              const SizedBox(height: 10),
              _enrollSection(context),
              const SizedBox(height: 4),
              _advanced(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translate('Close')),
        ),
      ],
    );
  }
}

/// Pede usuário/senha do Windows para o login automático, com aviso de risco.
Future<bool> _showAutologonDialog(BuildContext context) async {
  final userCtrl = TextEditingController();
  final domainCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  var accepted = false;
  var error = '';
  var working = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      Future<void> submit() async {
        if (!accepted || userCtrl.text.trim().isEmpty) return;
        setState(() => working = true);
        final r = await bind.mainGeorgeSetAutologon(
            user: userCtrl.text.trim(),
            domain: domainCtrl.text.trim(),
            password: pwCtrl.text);
        if (r == 'Y') {
          if (ctx.mounted) Navigator.of(ctx).pop(true);
        } else {
          setState(() {
            working = false;
            error = '${translate('george_autologon_failed')} $r';
          });
        }
      }

      return AlertDialog(
        title: Text(translate('george_autologon_title')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GeorgeTheme.destructive(ctx).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(GeorgeTokens.radiusSm),
                  border: Border.all(
                      color: GeorgeTheme.destructive(ctx).withOpacity(0.4)),
                ),
                child: Text(translate('george_autologon_risk'),
                    style: const TextStyle(fontSize: 12, height: 1.4)),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                      labelText: translate('george_autologon_user'))),
              const SizedBox(height: 8),
              TextField(
                  controller: domainCtrl,
                  decoration: InputDecoration(
                      labelText: translate('george_autologon_domain'))),
              const SizedBox(height: 8),
              TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: translate('george_autologon_password'))),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (v) => setState(() => accepted = v == true),
                title: Text(translate('george_autologon_accept'),
                    style: const TextStyle(fontSize: 12)),
              ),
              if (error.isNotEmpty)
                Text(error,
                    style: TextStyle(
                        fontSize: 12, color: GeorgeTheme.destructive(ctx))),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(translate('Cancel'))),
          ElevatedButton(
              onPressed: (accepted && !working) ? submit : null,
              child: Text(translate('george_autologon_enable'))),
        ],
      );
    }),
  );
  pwCtrl.clear();
  userCtrl.dispose();
  domainCtrl.dispose();
  pwCtrl.dispose();
  return ok == true;
}

// ---------------------------------------------------------------- técnico

/// Botão "Dispositivos da organização" (só para quem está logado).
class GeorgeOrgDevicesButton extends StatelessWidget {
  const GeorgeOrgDevicesButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (gFFI.userModel.userName.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => showDialog(
                context: context, builder: (_) => const _GeorgeOrgDevices()),
            icon: const Icon(Icons.lan_outlined, size: 18),
            label: Text(translate('george_org_devices')),
          ),
        ),
      );
    });
  }
}

class _GeorgeOrgDevices extends StatefulWidget {
  const _GeorgeOrgDevices({Key? key}) : super(key: key);

  @override
  State<_GeorgeOrgDevices> createState() => _GeorgeOrgDevicesState();
}

class _GeorgeOrgDevicesState extends State<_GeorgeOrgDevices> {
  List<GeorgeOrgDevice> _all = [];
  String _q = '';
  bool _loading = true;
  String _error = '';
  int? _connecting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final list = await GeorgeApi.orgDevices();
      list.sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (mounted) setState(() => _all = list);
    } catch (e) {
      GeorgeApi.logError('orgDevices', e);
      if (mounted) setState(() => _error = translate('george_org_load_failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(GeorgeOrgDevice d) async {
    setState(() => _connecting = d.id);
    try {
      final cred = await GeorgeApi.deviceCredentials(d.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      final ctx = Get.context;
      if (ctx != null) {
        await connect(ctx, cred.id.isEmpty ? d.rustdeskId : cred.id,
            password: cred.password);
      }
    } on GeorgeApiException catch (e) {
      GeorgeApi.logError('deviceCredentials', e);
      showToast(e.isUnauthorized
          ? translate('george_org_no_permission')
          : translate('george_org_connect_failed'));
    } catch (e) {
      GeorgeApi.logError('deviceCredentials', e);
      showToast(translate('george_org_connect_failed'));
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? _all
        : _all
            .where((d) =>
                d.name.toLowerCase().contains(q) ||
                d.group.toLowerCase().contains(q) ||
                d.rustdeskId.contains(q))
            .toList();
    return AlertDialog(
      title: Row(children: [
        Expanded(child: Text(translate('george_org_devices'))),
        IconButton(
            tooltip: translate('Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 20)),
      ]),
      content: SizedBox(
        width: 520,
        height: 440,
        child: Column(children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: translate('george_org_search'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : list.isEmpty
                        ? Center(child: Text(translate('george_org_empty')))
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) => _row(context, list[i]),
                          ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('Close'))),
      ],
    );
  }

  Widget _row(BuildContext context, GeorgeOrgDevice d) {
    final sub = [d.group, d.os, d.rustdeskId]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return ListTile(
      dense: true,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: d.online
              ? GeorgeTheme.success(context)
              : GeorgeTheme.mutedForeground(context),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      title: Text(d.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: _connecting == null ? () => _connect(d) : null,
          child: _connecting == d.id
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(translate('george_connect')),
        ),
      ),
      onTap: _connecting == null ? () => _connect(d) : null,
    );
  }
}

/// Copia texto e avisa (usado pelos detalhes).
void georgeCopy(String text) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(translate('george_invite_copied'));
}
