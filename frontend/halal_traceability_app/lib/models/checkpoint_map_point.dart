class CheckpointMapPoint {
  const CheckpointMapPoint({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.summary,
    required this.actionType,
    required this.timestampLabel,
    required this.rawIndex,
    this.temperature,
    this.isAlert = false,
  });

  final double latitude;
  final double longitude;
  final String locationName;
  final String summary;
  final String actionType;
  final String timestampLabel;
  final int rawIndex;
  final String? temperature;
  final bool isAlert;

  String get markerLabel {
    if (rawIndex == 0) {
      return 'Start';
    }

    return 'Stop ${rawIndex + 1}';
  }
}
