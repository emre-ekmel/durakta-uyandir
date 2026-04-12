import 'package:durakta_uyandir/core/utils/location_utils.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/presentation/bloc/alarm_bloc.dart';
import 'package:durakta_uyandir/presentation/pages/alarm_detail_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmBloc, AlarmState>(
      builder: (context, state) {
        if (state is AlarmLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is AlarmLoaded) {
          if (state.alarms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_off, size: 80, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text("home.no_alarms".tr(), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text("home.add_hint".tr()),
                ],
              ),
            );
          }

          return StreamBuilder<Position>(
            stream: Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 0,
              ),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint("Location stream error: ${snapshot.error}");
              }

              final currentPosition = snapshot.data;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.alarms.length,
                itemBuilder: (context, index) {
                  final alarm = state.alarms[index];
                  String subtitleText = "home.location_waiting".tr();
                  String? etaText;
                  Color statusColor = Colors.grey;

                  if (!alarm.isActive) {
                    subtitleText = "home.alarm_off".tr();
                  } else if (currentPosition != null) {
                    final distance = LocationUtils.calculateDistance(
                      currentPosition.latitude,
                      currentPosition.longitude,
                      alarm.targetLat,
                      alarm.targetLng,
                    );
                    subtitleText = "home.distance_away".tr(args: [distance.toInt().toString()]);
                    statusColor = Theme.of(context).primaryColor;

                    if (currentPosition.speed > 1.0) {
                      final timeInSeconds = distance / currentPosition.speed;
                      if (timeInSeconds < 60) {
                        etaText = "< 1 ${'common.time_min'.tr()}";
                      } else {
                        final minutes = (timeInSeconds / 60).round();
                        if (minutes >= 60) {
                          final hours = minutes ~/ 60;
                          final mins = minutes % 60;
                          etaText =
                              "$hours${'common.time_hour'.tr()} $mins${'common.time_min'.tr()}";
                        } else {
                          etaText = "$minutes ${'common.time_min'.tr()}";
                        }
                      }
                    }
                  } else {
                    subtitleText = "home.location_unknown".tr();
                  }

                  return _buildAlarmCard(context, alarm, subtitleText, etaText, statusColor);
                },
              );
            },
          );
        } else if (state is AlarmError) {
          return Center(child: Text(state.message));
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildAlarmCard(
    BuildContext context,
    DestinationAlarm alarm,
    String subtitle,
    String? etaText,
    Color statusColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AlarmDetailPage(alarm: alarm)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: alarm.isActive
                          ? statusColor.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm,
                      color: alarm.isActive ? statusColor : Colors.grey,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        if (etaText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  etaText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alarm.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        alarm.isActive ? "home.active".tr() : "home.passive".tr(),
                        style: TextStyle(
                          color: alarm.isActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: alarm.isActive,
                onChanged: (val) {
                  final updated = DestinationAlarm(
                    id: alarm.id,
                    name: alarm.name,
                    targetLat: alarm.targetLat,
                    targetLng: alarm.targetLng,
                    isActive: val,
                    triggerRadiusInMeters: alarm.triggerRadiusInMeters,
                  );
                  context.read<AlarmBloc>().add(UpdateAlarm(updated));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
