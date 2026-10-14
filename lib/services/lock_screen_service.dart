import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../screens/lock_screen_player.dart';

/// Dart side of the lock-screen player (native: LockScreenPlugin.kt).
class LockScreenService {
  LockScreenService._();
  static final instance = LockScreenService._();

  static const _ch = MethodChannel('zen/lockscreen');

  /// User setting.
  final enabled = ValueNotifier<bool>(false);

  /// Visual style of the lock screen: blur | art | minimal.
  final style = ValueNotifier<String>('blur');

  bool _showing = false;
  StreamSubscription<bool>? _playingSub;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    enabled.value = p.getBool('ls_enabled') ?? false;
    style.value = p.getString('ls_style') ?? 'blur';
    _ch.setMethodCallHandler(_onNative);
    try {
      await _ch.invokeMethod('setEnabled', enabled.value);
      _playingSub = audioHandler.playingStream.listen((on) {
        _ch.invokeMethod('setPlaying', on).catchError((_) {});
      });
      final pending = await _ch.invokeMethod<bool>('consumePending');
      if (pending == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _show());
      }
    } on MissingPluginException {
      // Desktop — no lock screen.
    }
  }

  Future<dynamic> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'show':
        _show();
      case 'unlocked':
        _hide();
    }
    return null;
  }

  Route<void>? _route;

  void _show() {
    if (_showing) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _showing = true;
    final route = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const LockScreenPlayer(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
    _route = route;
    nav.push(route).whenComplete(() {
      _showing = false;
      _route = null;
    });
  }

  void _hide() {
    final nav = navigatorKey.currentState;
    final route = _route;
    if (nav != null && route != null && route.isActive) {
      nav.removeRoute(route);
    }
    _showing = false;
    _route = null;
  }

  /// Ask Android to dismiss the keyguard (PIN/biometric if set).
  Future<void> unlock() async {
    try {
      await _ch.invokeMethod('unlock');
    } on MissingPluginException {
      _hide();
    }
  }

  Future<bool> canDrawOverlays() async {
    try {
      return await _ch.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestOverlay() async {
    try {
      await _ch.invokeMethod('requestOverlay');
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    enabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('ls_enabled', v);
    try {
      await _ch.invokeMethod('setEnabled', v);
    } catch (_) {}
  }

  Future<void> setStyle(String v) async {
    style.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setString('ls_style', v);
  }

  void dispose() => _playingSub?.cancel();
}
