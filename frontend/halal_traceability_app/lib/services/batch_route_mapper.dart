import '../models/checkpoint_map_point.dart';

class BatchRouteMapper {
  const BatchRouteMapper._();

  static List<CheckpointMapPoint> toMapPoints(List<dynamic> checkpoints) {
    final points = <CheckpointMapPoint>[];

    for (var index = 0; index < checkpoints.length; index++) {
      final raw = checkpoints[index];
      if (raw is! Map) {
        continue;
      }

      final checkpoint = raw.cast<String, dynamic>();
      final latitude = _parseCoordinate(checkpoint['latitude']);
      final longitude = _parseCoordinate(checkpoint['longitude']);
      if (latitude == null || longitude == null) {
        continue;
      }

      points.add(
        CheckpointMapPoint(
          latitude: latitude,
          longitude: longitude,
          locationName:
              (checkpoint['location_name'] ?? 'Unknown location').toString(),
          summary: (checkpoint['summary'] ?? 'Checkpoint recorded').toString(),
          actionType: (checkpoint['action_type'] ?? 'transit_update').toString(),
          timestampLabel: _formatTimestamp(checkpoint['created_at']),
          rawIndex: index,
          temperature: checkpoint['temperature']?.toString(),
          isAlert: checkpoint['alert'] == true,
        ),
      );
    }

    return points;
  }

  static double? _parseCoordinate(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is num) {
      return raw.toDouble();
    }

    return double.tryParse(raw.toString());
  }

  static String _formatTimestamp(dynamic raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) {
      return 'Unknown time';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year}, $hour:$minute $period';
  }

  static String _monthName(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}
