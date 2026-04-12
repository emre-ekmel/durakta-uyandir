import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/presentation/bloc/alarm_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class AlarmDetailPage extends StatefulWidget {
  final DestinationAlarm alarm;

  const AlarmDetailPage({super.key, required this.alarm});

  @override
  State<AlarmDetailPage> createState() => _AlarmDetailPageState();
}

class _AlarmDetailPageState extends State<AlarmDetailPage> {
  late final MapController _mapController;
  late final TextEditingController _nameController;

  bool _isEditing = false;
  LatLng? _selectedLocation;
  LatLng? _myLocation;

  late LatLng _initialLocation;
  late double _radius;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _nameController = TextEditingController(text: widget.alarm.name);
    _initialLocation = LatLng(widget.alarm.targetLat, widget.alarm.targetLng);
    _selectedLocation = _initialLocation;
    _radius = widget.alarm.triggerRadiusInMeters;

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _myLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      } catch (e) {
        debugPrint("Error getting location: $e");
      }
    }
  }

  void _enableEditMode() {
    setState(() {
      _isEditing = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("detail.edit_hint".tr())));
  }

  void _saveChanges() {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("detail.name_required".tr()), backgroundColor: Colors.red),
      );
      return;
    }

    final updatedAlarm = DestinationAlarm(
      id: widget.alarm.id,
      name: newName,
      targetLat: _selectedLocation!.latitude,
      targetLng: _selectedLocation!.longitude,
      isActive: widget.alarm.isActive,
      triggerRadiusInMeters: _radius,
    );

    context.read<AlarmBloc>().add(UpdateAlarm(updatedAlarm));

    setState(() {
      _isEditing = false;
      _initialLocation = _selectedLocation!;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("detail.updated".tr()), backgroundColor: Colors.green));
  }

  void _deleteAlarm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("detail.delete_title".tr()),
        content: Text("detail.delete_confirm".tr(args: [widget.alarm.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("common.cancel".tr())),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AlarmBloc>().add(DeleteAlarm(widget.alarm.id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("common.delete".tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String distanceText = "home.location_waiting".tr();
    if (_myLocation != null && _selectedLocation != null) {
      final dist = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      distanceText = "home.distance_away".tr(args: [dist.toInt().toString()]);
    }

    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "add_alarm.name_label".tr(),
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
              )
            : Text(widget.alarm.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialLocation,
                initialZoom: 15.0,
                onTap: (pos, point) {
                  if (_isEditing) {
                    setState(() {
                      _selectedLocation = point;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.durakta_uyandir',
                ),

                if (_selectedLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _selectedLocation!,
                        color: Colors.red.withOpacity(0.15),
                        borderColor: Colors.red.withOpacity(0.5),
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                        radius: _radius,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),

                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        width: 60,
                        height: 60,
                        child: Icon(
                          Icons.location_on,
                          color: _isEditing ? Colors.red : Colors.red.shade800,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (!_isEditing) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        "detail.alarm_radius".tr(args: [_radius.toInt().toString()]),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    distanceText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _enableEditMode,
                      icon: const Icon(Icons.edit_location_alt),
                      label: Text("detail.edit_location_name".tr()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleteAlarm,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline),
                      label: Text("detail.delete_title".tr()),
                    ),
                  ),
                ] else ...[
                  Text(
                    "detail.edit_map_hint".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "add_alarm.wake_distance".tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${_radius.toInt()}m",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radius,
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    label: "${_radius.toInt()}m",
                    onChanged: (val) {
                      setState(() {
                        _radius = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _selectedLocation = _initialLocation;
                              _nameController.text = widget.alarm.name;
                              _radius = widget.alarm.triggerRadiusInMeters;
                            });
                          },
                          child: Text("common.cancel".tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveChanges,
                          child: Text("common.save".tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
