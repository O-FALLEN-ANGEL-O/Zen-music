// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.

part of 'settings_system_cubit.dart';

@immutable
sealed class SettingsSystemState {
  const SettingsSystemState();
}

class SettingsSystemInitial extends SettingsSystemState {
  const SettingsSystemInitial();
}

class SettingsSystemLoaded extends SettingsSystemState {
  final bool? isBatteryOptimizationDisabled;

  const SettingsSystemLoaded({
    required this.isBatteryOptimizationDisabled,
  });
}