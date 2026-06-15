import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:durakta_uyandir/core/services/background_service.dart';
import 'package:durakta_uyandir/data/repositories/settings_repository.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/domain/repositories/alarm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AlarmEvent extends Equatable {
  const AlarmEvent();
  @override
  List<Object> get props => [];
}

class LoadAlarms extends AlarmEvent {}

class AddAlarm extends AlarmEvent {
  final DestinationAlarm alarm;
  const AddAlarm(this.alarm);
  @override
  List<Object> get props => [alarm];
}

class UpdateAlarm extends AlarmEvent {
  final DestinationAlarm alarm;
  const UpdateAlarm(this.alarm);
  @override
  List<Object> get props => [alarm];
}

class DeleteAlarm extends AlarmEvent {
  final String id;
  const DeleteAlarm(this.id);
  @override
  List<Object> get props => [id];
}

class ToggleAlarmStatus extends AlarmEvent {
  final String id;
  final bool isActive;
  const ToggleAlarmStatus(this.id, this.isActive);
  @override
  List<Object> get props => [id, isActive];
}

abstract class AlarmState extends Equatable {
  const AlarmState();
  @override
  List<Object> get props => [];
}

class AlarmInitial extends AlarmState {}

class AlarmLoading extends AlarmState {}

class AlarmLoaded extends AlarmState {
  final List<DestinationAlarm> alarms;
  const AlarmLoaded(this.alarms);
  @override
  List<Object> get props => [alarms];
}

class AlarmError extends AlarmState {
  final String message;
  const AlarmError(this.message);
  @override
  List<Object> get props => [message];
}

class AlarmBloc extends Bloc<AlarmEvent, AlarmState> {
  final AlarmRepository repository;
  final SettingsRepository settingsRepository;

  AlarmBloc({required this.repository, required this.settingsRepository}) : super(AlarmInitial()) {
    on<LoadAlarms>(_onLoadAlarms);
    on<AddAlarm>(_onAddAlarm);
    on<UpdateAlarm>(_onUpdateAlarm);
    on<DeleteAlarm>(_onDeleteAlarm);
    on<ToggleAlarmStatus>(_onToggleAlarmStatus);

    FlutterBackgroundService().on('disableAlarmInDb').listen((event) {
      if (event != null && event['id'] != null) {
        add(ToggleAlarmStatus(event['id'], false));
      }
    });
  }

  Future<void> _onLoadAlarms(LoadAlarms event, Emitter<AlarmState> emit) async {
    emit(AlarmLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final stoppedAlarms = prefs.getStringList('stopped_alarms') ?? [];
      if (stoppedAlarms.isNotEmpty) {
        debugPrint("Found stopped alarms from background: $stoppedAlarms");
        for (final id in stoppedAlarms) {
          await repository.updateAlarmStatus(id, false);
        }
        await prefs.setStringList('stopped_alarms', []);
      }

      final alarms = await repository.getAlarms();
      _syncWithService(alarms);
      emit(AlarmLoaded(alarms));
    } catch (e) {
      debugPrint("Error loading alarms: $e");
      emit(const AlarmError("Alarmlar yüklenirken hata oluştu."));
    }
  }

  Future<void> _syncWithService(List<DestinationAlarm> alarms) async {
    final activeAlarms = alarms.where((element) => element.isActive).toList();

    if (activeAlarms.isNotEmpty) {
      await BackgroundLocationService.startService();

      BackgroundLocationService.updateSettings({
        'sound': settingsRepository.isSoundEnabled(),
        'vibration': settingsRepository.isVibrationEnabled(),
        'notification': settingsRepository.isNotificationEnabled(),
      });

      BackgroundLocationService.updateAlarms(activeAlarms);
    } else {
      await BackgroundLocationService.stopService();
    }
  }

  Future<void> _onAddAlarm(AddAlarm event, Emitter<AlarmState> emit) async {
    try {
      await repository.saveAlarm(event.alarm);
      add(LoadAlarms());
    } catch (e) {
      debugPrint("Error adding alarm: $e");
      emit(const AlarmError("Alarm eklenemedi."));
    }
  }

  Future<void> _onUpdateAlarm(UpdateAlarm event, Emitter<AlarmState> emit) async {
    try {
      await repository.saveAlarm(event.alarm);
      add(LoadAlarms());
    } catch (e) {
      debugPrint("Error updating alarm: $e");
      emit(const AlarmError("Alarm güncellenemedi."));
    }
  }

  Future<void> _onDeleteAlarm(DeleteAlarm event, Emitter<AlarmState> emit) async {
    try {
      await repository.deleteAlarm(event.id);
      add(LoadAlarms());
    } catch (e) {
      debugPrint("Error deleting alarm: $e");
      emit(const AlarmError("Alarm silinemedi."));
    }
  }

  Future<void> _onToggleAlarmStatus(ToggleAlarmStatus event, Emitter<AlarmState> emit) async {
    try {
      await repository.updateAlarmStatus(event.id, event.isActive);
      add(LoadAlarms());
    } catch (e) {
      debugPrint("Error toggling alarm: $e");
      emit(const AlarmError("Durum güncellenemedi."));
    }
  }
}
