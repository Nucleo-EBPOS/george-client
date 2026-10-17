// GEORGE: Modo Host ON/OFF. ON = serviço aceita conexões de entrada e o
// dispositivo reporta presença à conta; OFF = `stop-service` nativo (recusa
// entrada, continua podendo acessar outros). Persistido pelo próprio core
// (opção `stop-service`), refletido na bandeja (src/tray.rs) e na API.
import 'dart:async';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/george/george_api.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

enum GeorgeHostStatus { stopped, starting, accepting, online }

class GeorgeHostController extends GetxController {
  static GeorgeHostController get to {
    if (!Get.isRegistered<GeorgeHostController>()) {
      Get.put(GeorgeHostController(), permanent: true);
    }
    return Get.find<GeorgeHostController>();
  }

  /// Estado desejado/persistido (true = Modo Host ligado).
  final enabled = true.obs;
  final busy = false.obs;
  final lastApiError = ''.obs;

  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  bool? _lastSentEnabled;

  @override
  void onInit() {
    super.onInit();
    _pollTimer = periodic_immediate(const Duration(seconds: 1), _refresh);
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _heartbeat());
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.onClose();
  }

  Future<void> _refresh() async {
    bool v;
    if (isDesktop || isWeb) {
      v = !(await mainGetBoolOption(kOptionStopService));
    } else {
      v = gFFI.serverModel.isStart;
    }
    if (v != enabled.value) {
      enabled.value = v;
      _heartbeat();
    }
  }

  GeorgeHostStatus get status {
    if (!enabled.value) return GeorgeHostStatus.stopped;
    switch (stateGlobal.svcStatus.value) {
      case SvcStatus.ready:
        return gFFI.userModel.isLogin
            ? GeorgeHostStatus.online
            : GeorgeHostStatus.accepting;
      case SvcStatus.connecting:
        return GeorgeHostStatus.starting;
      case SvcStatus.notReady:
        return GeorgeHostStatus.starting;
    }
  }

  String statusLabel() {
    switch (status) {
      case GeorgeHostStatus.stopped:
        return translate('george_host_status_stopped');
      case GeorgeHostStatus.starting:
        return translate('george_host_starting');
      case GeorgeHostStatus.accepting:
        return translate('george_host_status_accepting');
      case GeorgeHostStatus.online:
        return translate('george_host_status_online');
    }
  }

  /// Liga/desliga o Modo Host, persiste localmente e sincroniza com a conta.
  Future<void> setEnabled(bool on) async {
    if (busy.value) return;
    busy.value = true;
    try {
      if (isDesktop) {
        await start_service(on);
      } else if (!isWeb) {
        if (on != gFFI.serverModel.isStart) {
          await gFFI.serverModel.toggleService();
        }
      }
      await _refresh();
      enabled.value = on;
      await _sync(on);
    } finally {
      busy.value = false;
    }
  }

  Future<void> _sync(bool on) async {
    if (!GeorgeApi.isLoggedIn) return;
    try {
      await GeorgeApi.setHostEnabled(on);
      await GeorgeApi.heartbeat(hostEnabled: on);
      _lastSentEnabled = on;
      lastApiError.value = '';
    } catch (e) {
      lastApiError.value = e.toString();
      GeorgeApi.logError('setHostEnabled', e);
    }
  }

  Future<void> _heartbeat() async {
    if (!GeorgeApi.isLoggedIn) return;
    try {
      await GeorgeApi.heartbeat(hostEnabled: enabled.value);
      if (_lastSentEnabled != enabled.value) {
        await GeorgeApi.setHostEnabled(enabled.value);
        _lastSentEnabled = enabled.value;
      }
      lastApiError.value = '';
    } catch (e) {
      lastApiError.value = e.toString();
      GeorgeApi.logError('heartbeat', e);
    }
  }

  /// Chamado após login/logout para sincronizar imediatamente.
  void onAccountChanged() => _heartbeat();
}
