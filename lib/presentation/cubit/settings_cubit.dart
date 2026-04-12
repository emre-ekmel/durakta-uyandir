import 'package:durakta_uyandir/core/services/background_service.dart';
import 'package:durakta_uyandir/data/repositories/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool isSoundEnabled;
  final bool isVibrationEnabled;
  final bool isNotificationEnabled;
  final bool isHeadphoneOnlyModeEnabled;

  const SettingsState({
    required this.themeMode,
    required this.isSoundEnabled,
    required this.isVibrationEnabled,
    required this.isNotificationEnabled,
    required this.isHeadphoneOnlyModeEnabled,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? isSoundEnabled,
    bool? isVibrationEnabled,
    bool? isNotificationEnabled,
    bool? isHeadphoneOnlyModeEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isHeadphoneOnlyModeEnabled: isHeadphoneOnlyModeEnabled ?? this.isHeadphoneOnlyModeEnabled,
    );
  }

  @override
  List<Object> get props => [
    themeMode,
    isSoundEnabled,
    isVibrationEnabled,
    isNotificationEnabled,
    isHeadphoneOnlyModeEnabled,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;

  SettingsCubit({required SettingsRepository repository})
    : _repository = repository,
      super(
        SettingsState(
          themeMode: repository.getThemeMode(),
          isSoundEnabled: repository.isSoundEnabled(),
          isVibrationEnabled: repository.isVibrationEnabled(),
          isNotificationEnabled: repository.isNotificationEnabled(),
          isHeadphoneOnlyModeEnabled: repository.isHeadphoneOnlyModeEnabled(),
        ),
      ) {
    _syncWithBackground();
  }

  Future<void> updateTheme(ThemeMode mode) async {
    await _repository.setThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> toggleSound(bool value) async {
    await _repository.setSoundEnabled(value);
    emit(state.copyWith(isSoundEnabled: value));
    _syncWithBackground();
  }

  Future<void> toggleVibration(bool value) async {
    await _repository.setVibrationEnabled(value);
    emit(state.copyWith(isVibrationEnabled: value));
    _syncWithBackground();
  }

  Future<void> toggleNotification(bool value) async {
    await _repository.setNotificationEnabled(value);
    emit(state.copyWith(isNotificationEnabled: value));
    _syncWithBackground();
  }

  Future<void> toggleHeadphoneOnly(bool value) async {
    await _repository.setHeadphoneOnlyModeEnabled(value);
    emit(state.copyWith(isHeadphoneOnlyModeEnabled: value));
    _syncWithBackground();
  }

  void _syncWithBackground() {
    BackgroundLocationService.updateSettings({
      'sound': state.isSoundEnabled,
      'vibration': state.isVibrationEnabled,
      'notification': state.isNotificationEnabled,
      'headphoneOnly': state.isHeadphoneOnlyModeEnabled,
    });
  }
}
