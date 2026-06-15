import 'dart:async';
import 'dart:ui' as ui;

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

class _AddAlarmPageState extends State<AddAlarmPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final NominatimService _nominatimService = NominatimService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LatLng _currentCenter = const LatLng(41.0082, 28.9784);
  LatLng? _myLocation;
  LatLng? _selectedLocation;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  double _radius = 500.0;
  Timer? _debounce;
  bool _isPanelExpanded = true;

  // Animation controller for the bottom sheet
  late AnimationController _panelAnimController;
  late Animation<double> _panelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlideAnimation = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _selectedLocation != null) {
        _collapsePanel();
      }
    });

    _tryGetInitialPosition();
  }

  @override
  void dispose() {
    _panelAnimController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _expandPanel() {
    if (!_isPanelExpanded) {
      setState(() => _isPanelExpanded = true);
      _panelAnimController.forward();
    }
  }

  void _collapsePanel() {
    if (_isPanelExpanded) {
      setState(() => _isPanelExpanded = false);
      _panelAnimController.reverse();
    }
  }

  void _togglePanel() {
    if (_isPanelExpanded) {
      _collapsePanel();
    } else {
      _expandPanel();
    }
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

    _expandPanel();
    _panelAnimController.forward();
    _mapController.move(location, 16.0);

    FocusScope.of(context).unfocus();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

    _panelAnimController.reverse();

    MainPage.globalKey.currentState?.switchTab(0);
  }

  // ─── Build Helpers ──────────────────────────────────────────────

  Widget _buildMap(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: 14.0,
        onTap: (tapPosition, point) {
          setState(() {
            _selectedLocation = point;
          });
          _expandPanel();
          _panelAnimController.forward();
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
                color: Colors.blue.withValues(alpha: 0.15),
                borderColor: Colors.blue.withValues(alpha: 0.5),
                borderStrokeWidth: 2,
                useRadiusInMeter: true,
                radius: _radius,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // User location — Google Maps style blue dot with pulse ring
            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 60,
                height: 60,
                child: const _GoogleMapsLocationDot(),
              ),
            // Selected destination pin
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
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Material(
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            color: isDark ? theme.cardTheme.color : Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (val) {
                            setState(() {});
                            if (_debounce?.isActive ?? false) {
                              _debounce!.cancel();
                            }
                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              if (val.trim().length >= 3) {
                                _searchLocation(val);
                              } else if (val.isEmpty) {
                                setState(() => _searchResults = []);
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "add_alarm.search_hint".tr(),
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 15),
                          onSubmitted: _searchLocation,
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        )
                      else
                        const SizedBox(width: 16),
                    ],
                  ),
                ),
                // Search results dropdown
                if (_searchResults.isNotEmpty) ...[
                  Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 52,
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final displayName = result['display_name'] ?? "";
                        final parts = displayName.split(',');
                        final title = parts.isNotEmpty ? parts[0].trim() : displayName;
                        final subtitle = parts.length > 1 ? parts.sublist(1).join(',').trim() : "";

                        return ListTile(
                          leading: Icon(
                            Icons.place_outlined,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle.isNotEmpty
                              ? Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          onTap: () => _onSearchResultSelected(result),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapHint(BuildContext context) {
    if (_selectedLocation != null) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "add_alarm.tap_map_hint".tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls(BuildContext context, double panelVisibleHeight) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: panelVisibleHeight + 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compass — Google Maps style
          StreamBuilder<MapEvent>(
            stream: _mapController.mapEventStream,
            builder: (context, snapshot) {
              final rotation = _mapController.camera.rotation;
              return _GoogleMapsCompass(rotation: rotation, onTap: () => _mapController.rotate(0));
            },
          ),
          const SizedBox(height: 8),
          // My Location — Google Maps style
          _MapControlButton(
            onTap: () {
              if (_myLocation != null) {
                _mapController.move(_myLocation!, 15.0);
                _mapController.rotate(0);
              } else {
                _determinePosition();
              }
            },
            child: const Icon(
              Icons.my_location,
              color: ui.Color.fromARGB(255, 0, 153, 255),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    if (_selectedLocation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final panelColor = theme.scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: _panelSlideAnimation,
      builder: (context, child) {
        // panel total height = 380; collapsed shows 44px (handle)
        const panelHeight = 380.0;
        final slideOffset = (1 - _panelSlideAnimation.value) * (panelHeight - 44);

        return Positioned(bottom: -slideOffset, left: 0, right: 0, child: child!);
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 6) {
            _collapsePanel();
          } else if (details.primaryDelta! < -6) {
            _expandPanel();
          }
        },
        child: Container(
          height: 380,
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              GestureDetector(
                onTap: _togglePanel,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isPanelExpanded ? 36 : 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Panel content ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coordinates + close
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.place, color: theme.colorScheme.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "add_alarm.selected_location".tr(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}",
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                            ),
                            onPressed: () {
                              _collapsePanel();
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  setState(() {
                                    _selectedLocation = null;
                                    _nameController.clear();
                                    _radius = 500.0;
                                  });
                                }
                              });
                            },
                            tooltip: "add_alarm.remove_selection_tooltip".tr(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Alarm Name
                      TextField(
                        controller: _nameController,
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: "add_alarm.name_label".tr(),
                          counterText: "",
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.edit_outlined),
                          suffixIcon: _nameController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => setState(() => _nameController.clear()),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        maxLength: 30,
                      ),
                      const SizedBox(height: 12),

                      // Distance Slider
                      Row(
                        children: [
                          Text(
                            "add_alarm.distance_label".tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_radius.toInt()}m",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: _radius,
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          label: "${_radius.toInt()}m",
                          onChanged: (val) => setState(() => _radius = val),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Save Button
                      SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _nameController.text.trim().isNotEmpty ? _saveAlarm : null,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.alarm_add_rounded, size: 22),
                                const SizedBox(width: 10),
                                Text("add_alarm.save_alarm".tr()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate how much of the panel is visible for button positioning
    final panelVisibleHeight = _selectedLocation != null ? (_isPanelExpanded ? 380.0 : 44.0) : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(context),
          _buildSearchBar(context),
          _buildMapHint(context),
          _buildMapControls(context, panelVisibleHeight),
          _buildBottomPanel(context),
        ],
      ),
    );
  }
}

/// Google Maps-style circular map control button.
class _MapControlButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _MapControlButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      color: isDark ? Theme.of(context).cardTheme.color : Colors.white,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }
}

/// Google Maps-style compass with red/white needle, smooth rotation, and animated visibility.
class _GoogleMapsCompass extends StatelessWidget {
  final double rotation;
  final VoidCallback onTap;

  const _GoogleMapsCompass({required this.rotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVisible = rotation.abs() > 0.5;

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedScale(
        scale: isVisible ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: Material(
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: const CircleBorder(),
            color: isDark ? Theme.of(context).cardTheme.color : Colors.white,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: AnimatedRotation(
                  turns: rotation / 360,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Center(
                    child: CustomPaint(size: const Size(40, 40), painter: _CompassNeedlePainter()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a Google Maps-style compass needle: red triangle pointing north, grey pointing south.
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // North needle (red)
    final northPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final northPath = ui.Path()
      ..moveTo(center.dx, center.dy - radius) // top
      ..lineTo(center.dx - radius * 0.3, center.dy) // left
      ..lineTo(center.dx + radius * 0.3, center.dy) // right
      ..close();

    canvas.drawPath(northPath, northPaint);

    // South needle (grey)
    final southPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.fill;

    final southPath = ui.Path()
      ..moveTo(center.dx, center.dy + radius) // bottom
      ..lineTo(center.dx - radius * 0.3, center.dy) // left
      ..lineTo(center.dx + radius * 0.3, center.dy) // right
      ..close();

    canvas.drawPath(southPath, southPaint);

    // Center circle
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google Maps-style blue location dot with animated pulsing ring.
class _GoogleMapsLocationDot extends StatefulWidget {
  const _GoogleMapsLocationDot();

  @override
  State<_GoogleMapsLocationDot> createState() => _GoogleMapsLocationDotState();
}

class _GoogleMapsLocationDotState extends State<_GoogleMapsLocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            Container(
              width: 60 * _pulseAnimation.value,
              height: 60 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4285F4).withValues(alpha: _opacityAnimation.value),
              ),
            ),
            // Inner dot
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
