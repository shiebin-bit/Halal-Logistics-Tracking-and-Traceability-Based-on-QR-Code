import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/checkpoint_map_point.dart';

class RouteMapCard extends StatefulWidget {
  const RouteMapCard({
    super.key,
    required this.points,
    required this.totalCheckpoints,
    this.title = 'Transit Route',
  });

  final List<CheckpointMapPoint> points;
  final int totalCheckpoints;
  final String title;

  @override
  State<RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends State<RouteMapCard> {
  static const Distance _distance = Distance();

  final MapController _mapController = MapController();
  int _selectedIndex = 0;
  bool _mapReady = false;

  @override
  void didUpdateWidget(covariant RouteMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_selectedIndex >= widget.points.length) {
      _selectedIndex = 0;
    }

    if (_mapReady && oldWidget.points != widget.points) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitCameraToPoints();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.points;
    final selected = points.isEmpty ? null : points[_selectedIndex];
    final missingCount = widget.totalCheckpoints - points.length;
    final alertCount = points.where((point) => point.isAlert).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D2E), Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _coverageLabel(missingCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: points.length >= 2
                    ? 'Live Map'
                    : points.length == 1
                        ? 'Single Stop'
                        : 'No GPS',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStats(points, alertCount),
          const SizedBox(height: 18),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            clipBehavior: Clip.antiAlias,
            child: points.isEmpty ? _buildEmptyState(missingCount) : _buildMap(),
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _buildSelectedPoint(selected),
          ],
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: points.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final point = points[index];
                  final isSelected = index == _selectedIndex;
                  return ChoiceChip(
                    label: Text(point.markerLabel),
                    selected: isSelected,
                    onSelected: (_) => _selectPoint(index, focusMap: true),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF103323) : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    side: BorderSide(
                      color: point.isAlert
                          ? Colors.redAccent.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                    avatar: point.isAlert
                        ? const Icon(
                            Icons.priority_high_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(List<CheckpointMapPoint> points, int alertCount) {
    final totalDistanceKm = _routeDistanceKm(points);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatTile(
          width: 108,
          label: 'Mapped stops',
          value: '${points.length}/${widget.totalCheckpoints}',
        ),
        _StatTile(
          width: 124,
          label: 'Route length',
          value: totalDistanceKm == 0 ? 'Pending' : '${totalDistanceKm.toStringAsFixed(1)} km',
        ),
        _StatTile(
          width: 110,
          label: 'Alert points',
          value: '$alertCount',
          highlighted: alertCount > 0,
        ),
      ],
    );
  }

  Widget _buildMap() {
    final latLngPoints = widget.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final initialCenter = latLngPoints.first;
    final initialFit = latLngPoints.length > 1
        ? CameraFit.coordinates(
            coordinates: latLngPoints,
            padding: const EdgeInsets.all(28),
            maxZoom: 15.5,
          )
        : null;

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(_mapKey()),
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: latLngPoints.length > 1 ? 10.5 : 14.5,
            initialCameraFit: initialFit,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
            onMapReady: () {
              _mapReady = true;
              _fitCameraToPoints();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.halal_traceability_app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngPoints,
                  strokeWidth: 5,
                  color: const Color(0xFF00E5FF),
                  borderStrokeWidth: 2,
                  borderColor: const Color(0xFF0B2E1F),
                ),
              ],
            ),
            MarkerLayer(
              markers: widget.points.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                final isSelected = index == _selectedIndex;
                return Marker(
                  point: LatLng(point.latitude, point.longitude),
                  width: 56,
                  height: 56,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _selectPoint(index, focusMap: false),
                    child: _MapMarker(
                      label: point.markerLabel,
                      highlighted: isSelected,
                      isAlert: point.isAlert,
                      isFirst: index == 0,
                      isLast: index == widget.points.length - 1,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: const [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Drag and zoom',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(int missingCount) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Colors.white70,
              size: 34,
            ),
            const SizedBox(height: 12),
            const Text(
              'Map unavailable for this batch yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              missingCount > 0
                  ? 'Checkpoint history exists, but no valid coordinates were shared for route drawing yet.'
                  : 'This batch does not have any checkpoint coordinates yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPoint(CheckpointMapPoint point) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  point.locationName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (point.isAlert)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Alert',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            point.summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.schedule_rounded, label: point.timestampLabel),
              _InfoPill(
                icon: Icons.pin_drop_outlined,
                label:
                    '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
              ),
              _InfoPill(
                icon: Icons.local_shipping_outlined,
                label: point.actionType.replaceAll('_', ' '),
              ),
              if (point.temperature != null && point.temperature!.isNotEmpty)
                _InfoPill(
                  icon: Icons.thermostat_outlined,
                  label: '${point.temperature}°C',
                  highlighted: point.isAlert,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _fitCameraToPoints() {
    if (!_mapReady || widget.points.isEmpty) {
      return;
    }

    final latLngPoints = widget.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    if (latLngPoints.length == 1) {
      _mapController.move(latLngPoints.first, 14.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: latLngPoints,
        padding: const EdgeInsets.all(28),
        maxZoom: 15.5,
      ),
    );
  }

  void _selectPoint(int index, {required bool focusMap}) {
    setState(() => _selectedIndex = index);

    if (!focusMap || !_mapReady || widget.points.isEmpty) {
      return;
    }

    final point = widget.points[index];
    final target = LatLng(point.latitude, point.longitude);
    final nextZoom = _mapController.camera.zoom < 14.5
        ? 14.5
        : _mapController.camera.zoom;
    _mapController.move(target, nextZoom);
  }

  double _routeDistanceKm(List<CheckpointMapPoint> points) {
    if (points.length < 2) {
      return 0;
    }

    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += _distance(
        LatLng(points[i - 1].latitude, points[i - 1].longitude),
        LatLng(points[i].latitude, points[i].longitude),
      );
    }

    return meters / 1000;
  }

  String _coverageLabel(int missingCount) {
    if (widget.totalCheckpoints == 0) {
      return 'No checkpoints available yet.';
    }

    if (missingCount <= 0) {
      return 'All checkpoints include valid coordinates.';
    }

    return '$missingCount checkpoint${missingCount == 1 ? '' : 's'} without coordinates were skipped.';
  }

  String _mapKey() {
    final points = widget.points;
    if (points.isEmpty) {
      return 'empty';
    }

    final first = points.first;
    final last = points.last;
    return '${points.length}-${first.latitude}-${first.longitude}-${last.latitude}-${last.longitude}';
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.highlighted,
    required this.isAlert,
    required this.isFirst,
    required this.isLast,
  });

  final String label;
  final bool highlighted;
  final bool isAlert;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final markerColor = isAlert
        ? Colors.redAccent
        : isFirst
            ? const Color(0xFF7CFFB2)
            : isLast
                ? const Color(0xFFFFF59D)
                : const Color(0xFF00E5FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: highlighted ? 32 : 28,
          height: highlighted ? 32 : 28,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: highlighted ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isAlert
                ? Icons.warning_amber_rounded
                : isLast
                    ? Icons.flag_rounded
                    : Icons.circle,
            color: isAlert ? Colors.white : const Color(0xFF103323),
            size: highlighted ? 18 : 15,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.width,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final double? width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.redAccent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.redAccent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
