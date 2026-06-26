import 'package:durakta_uyandir/core/services/background_service.dart';
import 'package:durakta_uyandir/data/repositories/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool isSoundEnabled;
  final bool isVibrationEnabled;
  final bool isNotificationEnabled;
  final bool isHeadphoneOnlyModeEnabled;
  final bool? isAnalyticsEnabled;

  const SettingsState({
    required this.themeMode,
    required this.isSoundEnabled,
    required this.isVibrationEnabled,
    required this.isNotificationEnabled,
    required this.isHeadphoneOnlyModeEnabled,
    this.isAnalyticsEnabled,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? isSoundEnabled,
    bool? isVibrationEnabled,
    bool? isNotificationEnabled,
    bool? isHeadphoneOnlyModeEnabled,
    bool? isAnalyticsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isHeadphoneOnlyModeEnabled: isHeadphoneOnlyModeEnabled ?? this.isHeadphoneOnlyModeEnabled,
      isAnalyticsEnabled: isAnalyticsEnabled ?? this.isAnalyticsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    isSoundEnabled,
    isVibrationEnabled,
    isNotificationEnabled,
    isHeadphoneOnlyModeEnabled,
    isAnalyticsEnabled,
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
          isAnalyticsEnabled: repository.isAnalyticsEnabled(),
        ),
      ) {
    _syncWithBackground();
    _initAnalytics();
  }

  Future<void> _initAnalytics() async {
    final enabled = _repository.isAnalyticsEnabled();
    if (enabled != null) {
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      } catch (e) {
        // Ignore
      }
    }
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

  Future<void> setAnalyticsEnabled(bool value) async {
    await _repository.setAnalyticsEnabled(value);
    
    // Toggle Firebase Analytics collection based on user preference
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
    } catch (e) {
      // Ignore if Firebase is not initialized yet
    }

    emit(SettingsState(
      themeMode: state.themeMode,
      isSoundEnabled: state.isSoundEnabled,
      isVibrationEnabled: state.isVibrationEnabled,
      isNotificationEnabled: state.isNotificationEnabled,
      isHeadphoneOnlyModeEnabled: state.isHeadphoneOnlyModeEnabled,
      isAnalyticsEnabled: value,
    ));
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
