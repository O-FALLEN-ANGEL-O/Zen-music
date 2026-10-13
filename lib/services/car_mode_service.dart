import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

/// Why we think the phone is in a car.
enum CarSignal { androidAuto, automotive, carMode, bluetooth }

/// Listens to the native `zen/car` stream (Android Auto, system car
/// mode, Bluetooth) and decides when to switch the app into Car Mode.
class CarModeService {
  CarModeService._();
  static final instance = CarModeService._();

  static const _channel = EventChannel('zen/car');

  /// True while any car signal is active.
  final inCar = ValueNotifier<bool>(false);

  /// What triggered [inCar] (null when not in a car).
  final signal = ValueNotifier<CarSignal?>(null);

  /// Settings.
  final autoOpenOnBluetooth = ValueNotifier<bool>(true);
  final autoPlayOnConnect = ValueNotifier<bool>(false);

  /// Bluetooth device names the user confirmed are their car.
  final carDevices = ValueNotifier<Set<String>>(<String>{});

  /// Devices we've already asked about (don't nag).
  final Set<String> _askedDevices = {};

  /// Fires when Car Mode should open on screen.
  final _openRequests = StreamController<CarSignal>.broadcast();
  Stream<CarSignal> get openRequests => _openRequests.stream;

  /// Fires with a device name when we should ask "is this your car?".
  final _askRequests = StreamController<String>.broadcast();
  Stream<String> get askRequests => _askRequests.stream;

  StreamSubscription<dynamic>? _sub;
  String? _activeCarDevice;
  final Set<CarSignal> _active = {};

  Future<void> init() async {
    if (_sub != null) return;
    final p = await SharedPreferences.getInstance();
    autoOpenOnBluetooth.value = p.getBool('car_auto_open') ?? true;
    autoPlayOnConnect.value = p.getBool('car_auto_play') ?? false;
    carDevices.value = (p.getStringList('car_devices') ?? const []).toSet();
    _askedDevices.addAll(p.getStringList('car_asked') ?? const []);
    try {
      _sub = _channel.receiveBroadcastStream().listen(
        _onEvent,
        onError: (_) {},
      );
    } on MissingPluginException {
      // Desktop build — no car integration.
    }
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final kind = raw['kind'] as String?;
    final connected = raw['connected'] == true;
    switch (kind) {
      case 'android_auto':
        _set(CarSignal.androidAuto, connected);
      case 'automotive':
        _set(CarSignal.automotive, connected);
      case 'car_mode':
        _set(CarSignal.carMode, connected);
      case 'bluetooth':
        final name = (raw['name'] as String?)?.trim();
        final isCarClass = raw['isCarClass'] == true;
        if (name == null || name.isEmpty) return;
        if (connected) {
          final known = carDevices.value.contains(name);
          if (known || isCarClass) {
            _activeCarDevice = name;
            _set(CarSignal.bluetooth, true);
          } else if (autoOpenOnBluetooth.value &&
              !_askedDevices.contains(name) &&
              _looksLikeCar(name)) {
            _askRequests.add(name);
          }
        } else if (name == _activeCarDevice) {
          _activeCarDevice = null;
          _set(CarSignal.bluetooth, false);
        }
    }
  }

  /// Head units often have names like "MY CAR", "SYNC", "Uconnect",
  /// "CAR MULTIMEDIA" — only those earn a prompt.
  static bool _looksLikeCar(String name) {
    final n = name.toLowerCase();
    const hints = [
      'car', 'auto', 'sync', 'uconnect', 'carplay', 'mylink', 'entune',
      'mbux', 'idrive', 'mzd', 'kia', 'hyundai', 'toyota', 'honda',
      'maruti', 'suzuki', 'tata', 'mahindra', 'vw', 'skoda', 'ford',
      'bmw', 'audi', 'mercedes', 'nissan', 'renault', 'mg ', 'jeep',
      'pioneer', 'kenwood', 'sony xav', 'alpine', 'jvc', 'stereo',
    ];
    return hints.any(n.contains);
  }

  void _set(CarSignal s, bool on) {
    final wasInCar = _active.isNotEmpty;
    if (on) {
      _active.add(s);
    } else {
      _active.remove(s);
    }
    final nowInCar = _active.isNotEmpty;
    inCar.value = nowInCar;
    signal.value = nowInCar ? (on ? s : _active.first) : null;
    if (!wasInCar && nowInCar) _onEnteredCar(s);
  }

  void _onEnteredCar(CarSignal s) {
    // Android Auto draws its own UI on the car screen; the phone
    // screen is usually locked, so only open our screen for the others.
    final openOnPhone = s != CarSignal.androidAuto && s != CarSignal.automotive;
    if (openOnPhone && autoOpenOnBluetooth.value) _openRequests.add(s);
    if (autoPlayOnConnect.value) {
      // Resume whatever was last playing (the handler restores the
      // previous session at startup).
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!audioHandler.playbackState.value.playing &&
            audioHandler.queueSongs.isNotEmpty) {
          audioHandler.play();
        }
      });
    }
  }

  Future<void> markAsCar(String name, bool isCar) async {
    _askedDevices.add(name);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('car_asked', _askedDevices.toList());
    if (!isCar) return;
    carDevices.value = {...carDevices.value, name};
    await p.setStringList('car_devices', carDevices.value.toList());
    _activeCarDevice = name;
    _set(CarSignal.bluetooth, true);
  }

  Future<void> forgetCar(String name) async {
    carDevices.value = {...carDevices.value}..remove(name);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('car_devices', carDevices.value.toList());
  }

  Future<void> setAutoOpenOnBluetooth(bool v) async {
    autoOpenOnBluetooth.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('car_auto_open', v);
  }

  Future<void> setAutoPlayOnConnect(bool v) async {
    autoPlayOnConnect.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('car_auto_play', v);
  }
}
