import 'dart:async';

import 'package:durakta_uyandir/core/services/nominatim_service.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:durakta_uyandir/presentation/bloc/alarm_bloc.dart';
import 'package:durakta_uyandir/presentation/pages/main_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class AddAlarmPage extends StatefulWidget {
  const AddAlarmPage({super.key});

  @override
  State<AddAlarmPage> createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  final MapController _mapController = MapController();
  final NominatimService _nominatimService = NominatimService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentCenter = const LatLng(41.0082, 28.9784);
  LatLng? _myLocation;
  LatLng? _selectedLocation;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  double _radius = 500.0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _tryGetInitialPosition();
  }

  Future<void> _tryGetInitialPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showErrorSnackBar("add_alarm.loc_service_off".tr());
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        _showErrorSnackBar("add_alarm.loc_denied".tr());
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showSettingsDialog();
      return;
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        if (!mounted) return;
        final lat = position.latitude;
        final lng = position.longitude;
        setState(() {
          _myLocation = LatLng(lat, lng);
          _currentCenter = _myLocation!;
        });
        _mapController.move(_currentCenter, 15.0);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("${'common.error'.tr()}: $e");
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    final results = await _nominatimService.searchPlaces(
      query,
      lat: _currentCenter.latitude,
      lon: _currentCenter.longitude,
    );

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });

    if (results.isEmpty) {
      _showErrorSnackBar("add_alarm.no_result".tr());
    }
  }

  void _onSearchResultSelected(Map<String, dynamic> result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final location = LatLng(lat, lon);
    /*
      Updating the selected pin on the map.
      It's also a nice touch to auto-fill the alarm name with the search result.
    */
    setState(() {
      _selectedLocation = location;
      _searchResults = [];
      _searchController.clear();
      _currentCenter = location;

      String name = result['name'] ?? result['display_name']?.split(',').first ?? "";
      if (_nameController.text.isEmpty) {
        _nameController.text = name;
      }
    });

    _mapController.move(location, 16.0);

    FocusScope.of(context).unfocus();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("add_alarm.loc_permission_title".tr()),
        content: Text("add_alarm.loc_permission_desc".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("common.cancel".tr())),
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(ctx);
            },
            child: Text("add_alarm.open_settings".tr()),
          ),
        ],
      ),
    );
  }

  void _saveAlarm() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedLocation == null) {
      _showErrorSnackBar("add_alarm.error_no_name_loc".tr());
      return;
    }

    final newAlarm = DestinationAlarm(
      id: const Uuid().v4(),
      name: name,
      targetLat: _selectedLocation!.latitude,
      targetLng: _selectedLocation!.longitude,
      isActive: true,
      triggerRadiusInMeters: _radius,
    );

    context.read<AlarmBloc>().add(AddAlarm(newAlarm));

    setState(() {
      _nameController.clear();
      _searchController.clear();
      _selectedLocation = null;
      _searchResults = [];
      _radius = 500.0;

      if (_myLocation != null) {
        _currentCenter = _myLocation!;
        _mapController.move(_currentCenter, 15.0);
      }
    });

    MainPage.globalKey.currentState?.switchTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("add_alarm.title".tr()),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _saveAlarm)],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _nameController,
                  onChanged: (val) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: "add_alarm.name_label".tr(),
                    counterText: "",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.bookmark_border),
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _nameController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  maxLength: 30,
                ),
              ),

              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
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
                            color: Colors.blue.withOpacity(0.15),
                            borderColor: Colors.blue.withOpacity(0.5),
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
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                              child: const Center(
                                child: Icon(Icons.circle, color: Colors.blue, size: 15),
                              ),
                            ),
                          ),

                        if (_selectedLocation != null)
                          Marker(
                            point: _selectedLocation!,
                            width: 80,
                            height: 80,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_selectedLocation != null)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "add_alarm.wake_distance".tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Text(
                                "${_radius.toInt()}m",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedLocation = null;
                                    _nameController.clear();
                                    _radius = 500.0;
                                  });
                                },
                                tooltip: "add_alarm.remove_selection_tooltip".tr(),
                              ),
                            ],
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

                      const Divider(),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "add_alarm.selected_location".tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            "${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),

          Positioned(
            top: 70,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {});

                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              if (val.trim().length >= 3) {
                                _searchLocation(val);
                              } else if (val.isEmpty) {
                                setState(() {
                                  _searchResults = [];
                                });
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "add_alarm.search_hint".tr(),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _searchLocation,
                        ),
                        trailing: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchResults = [];
                                  });
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () => _searchLocation(_searchController.text),
                              ),
                      ),

                      if (_searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                title: Text(result['display_name'] ?? ""),
                                dense: true,
                                onTap: () => _onSearchResultSelected(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: _selectedLocation != null ? 250 : 100,
            right: 16,
            child: StreamBuilder<MapEvent>(
              stream: _mapController.mapEventStream,
              builder: (context, snapshot) {
                final rotation = _mapController.camera.rotation;

                if (rotation == 0) return const SizedBox.shrink();

                return Card(
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      _mapController.rotate(0);
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Transform.rotate(
                        angle: -rotation * (3.14159 / 180),
                        child: const Icon(Icons.navigation, color: Colors.blue, size: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: _selectedLocation != null ? 180 : 30,
            right: 16,
            child: FloatingActionButton(
              heroTag: "my_location_btn",
              backgroundColor: Theme.of(context).cardColor,
              foregroundColor: Colors.blue,
              onPressed: () {
                if (_myLocation != null) {
                  _mapController.move(_myLocation!, 15.0);
                  _mapController.rotate(0);
                } else {
                  _determinePosition();
                }
              },
              child: const Icon(Icons.gps_fixed),
            ),
          ),
        ],
      ),
    );
  }
}
