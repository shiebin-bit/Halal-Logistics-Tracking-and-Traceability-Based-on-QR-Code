class RoleAssistantContextBuilder {
  static Map<String, dynamic> processorDashboard({
    required int selectedIndex,
    required Map<String, dynamic> userData,
    required List<dynamic> batches,
    required String searchQuery,
    required String filterType,
    required String? productType,
    required String batchId,
    required String weight,
    required String originFarm,
    required String processingFactory,
    required String location,
    required String certificateAuthority,
    required String certificateNo,
    required DateTime slaughterDate,
    required DateTime certificateValidUntil,
  }) {
    final roleProfile =
        (userData['processor_profile'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dashboardOverview = {
      'role': 'processor',
      'total_batches': batches.length,
      'ready_batches': batches.where((item) => item['status'] == 'Ready').length,
      'qr_generated_batches':
          batches.where((item) => item['status'] == 'QR Generated').length,
      'in_transit_batches':
          batches.where((item) => item['status'] == 'In Transit').length,
      'filter_type': filterType,
      'search_query': searchQuery,
    };

    return switch (selectedIndex) {
      1 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'create_batch',
          'processor': {
            'name': userData['name'],
            'factory_address': roleProfile['factory_address'],
            'halal_cert_no': roleProfile['halal_cert_no'],
          },
          'draft_batch': {
            'batch_id': batchId,
            'product_type': productType,
            'weight': weight,
            'origin_farm': originFarm,
            'processing_factory': processingFactory,
            'current_location': location,
            'certificate_authority': certificateAuthority,
            'certificate_no': certificateNo,
            'slaughter_date': slaughterDate.toIso8601String(),
            'certificate_valid_until': certificateValidUntil.toIso8601String(),
          },
        },
      2 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'reports',
          'processor': {
            'name': userData['name'],
            'company_reg_no': roleProfile['company_reg_no'],
          },
          'summary': dashboardOverview,
        },
      _ => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'inventory',
          'processor': {
            'name': userData['name'],
            'company_reg_no': roleProfile['company_reg_no'],
          },
          'inventory_summary': {
            'batch_count': batches.length,
            'search_query': searchQuery,
            'filter_type': filterType,
          },
          'visible_batches': _compactItems(
            batches,
            (item) => {
              'batch_id': item['batch_id'],
              'product_type': item['product_type'],
              'status': item['status'],
              'current_location': item['current_location'],
              'freshness_score': item['freshness_score'],
            },
          ),
        },
    };
  }

  static Map<String, dynamic> processorBatchDetail({
    required Map<String, dynamic> batchData,
    required String status,
  }) {
    return {
      'screen_state': 'batch_detail',
      'batch': {
        'batch_id': batchData['batch_id'],
        'product_type': batchData['product_type'],
        'weight': batchData['weight'],
        'status': status,
        'freshness_score': batchData['freshness_score'],
        'origin_farm': batchData['origin_farm'],
        'processing_factory': batchData['processing_factory'],
      },
    };
  }

  static Map<String, dynamic> logisticsDashboard({
    required int selectedIndex,
    required Map<String, dynamic> userData,
    required List<dynamic> shipments,
    required String? scannedBatchId,
    required String temperature,
    required String location,
    required String notes,
    required bool hasCurrentLocation,
  }) {
    final roleProfile =
        (userData['logistics_profile'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dashboardOverview = {
      'role': 'logistics',
      'assigned_route_count': shipments.length,
      'in_transit_routes':
          shipments.where((item) => item['status'] == 'In Transit').length,
      'delayed_routes':
          shipments.where((item) => item['status'] == 'Delayed').length,
      'linked_detail_routes': shipments.where((item) => item['id'] != null).length,
    };

    return switch (selectedIndex) {
      1 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'checkpoint_scanner',
          'logistics_partner': {
            'name': userData['name'],
            'vehicle_plate_no': roleProfile['vehicle_plate_no'],
          },
          'checkpoint_form': {
            'scanned_batch_id': scannedBatchId,
            'temperature_input': temperature,
            'location_input': location,
            'notes_input': notes,
            'has_live_location': hasCurrentLocation,
          },
        },
      2 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'incidents',
          'logistics_partner': {
            'name': userData['name'],
            'vehicle_plate_no': roleProfile['vehicle_plate_no'],
          },
          'incident_workspace': {
            'scanned_batch_id': scannedBatchId,
            'location_input': location,
            'notes_input': notes,
            'assigned_route_count': shipments.length,
          },
        },
      _ => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'routes',
          'logistics_partner': {
            'name': userData['name'],
            'vehicle_plate_no': roleProfile['vehicle_plate_no'],
          },
          'assigned_routes': _compactItems(
            shipments,
            (item) => {
              'batch_id': item['batch_id_raw'],
              'truck_id': item['truckId'],
              'destination': item['destination'],
              'eta': item['eta'],
              'temperature': item['temp'],
              'status': item['status'],
              'progress': item['progress'],
            },
          ),
        },
    };
  }

  static Map<String, dynamic> logisticsBatchDetail({
    required Map<String, dynamic> routeSummary,
    required Map<String, dynamic>? batchData,
  }) {
    final checkpoints = (batchData?['checkpoints'] as List?) ?? const [];

    return {
      'screen_state': 'route_detail',
      'route_summary': {
        'batch_id': routeSummary['batch_id_raw'],
        'truck_id': routeSummary['truckId'],
        'destination': routeSummary['destination'],
        'eta': routeSummary['eta'],
        'status': routeSummary['status'],
      },
      'batch': batchData == null
          ? null
          : {
              'product_type': batchData['product_type'],
              'origin_farm': batchData['origin_farm'],
              'current_location': batchData['current_location'],
              'destination_address': batchData['destination_address'],
              'status': batchData['status'],
              'checkpoint_count': checkpoints.length,
            },
      'recent_checkpoints': _compactItems(
        checkpoints,
        (item) => {
          'location_name': item['location_name'],
          'action_type': item['action_type'],
          'temperature': item['temperature'],
          'notes': item['notes'],
          'timestamp': item['created_at'],
        },
      ),
    };
  }

  static Map<String, dynamic> retailerDashboard({
    required int selectedIndex,
    required Map<String, dynamic> userData,
    required List<dynamic> incomingShipments,
    required List<dynamic> inventory,
    required String? scannedBatchId,
    required String arrivalTemperature,
    required String rejectionReason,
    required Map<String, bool> qualityChecks,
  }) {
    final roleProfile =
        (userData['retailer_profile'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final completedChecks = qualityChecks.values.where((value) => value).length;
    final dashboardOverview = {
      'role': 'retailer',
      'incoming_count': incomingShipments.length,
      'inventory_count': inventory.length,
      'scanned_batch_id': scannedBatchId,
      'completed_quality_checks': completedChecks,
    };

    return switch (selectedIndex) {
      1 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'receive_inspect',
          'retailer': {
            'name': userData['name'],
            'store_name': roleProfile['store_name'],
            'outlet_address': roleProfile['outlet_address'],
          },
          'inspection': {
            'scanned_batch_id': scannedBatchId,
            'arrival_temperature': arrivalTemperature,
            'rejection_reason': rejectionReason,
            'quality_checks': qualityChecks,
          },
        },
      2 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'inventory',
          'retailer': {
            'name': userData['name'],
            'store_name': roleProfile['store_name'],
          },
          'inventory': _compactItems(
            inventory,
            (item) => {
              'batch_id': item['batch_id'],
              'product_type': item['product_type'],
              'status': item['status'],
              'received_at': item['received_at'],
            },
          ),
        },
      3 => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'reports',
          'retailer': {
            'name': userData['name'],
            'store_name': roleProfile['store_name'],
          },
          'summary': dashboardOverview,
        },
      _ => {
          'dashboard_overview': dashboardOverview,
          'screen_state': 'incoming',
          'retailer': {
            'name': userData['name'],
            'store_name': roleProfile['store_name'],
          },
          'incoming_shipments': _compactItems(
            incomingShipments,
            (item) => {
              'batch_id': item['batch_id'],
              'product_type': item['product_type'],
              'status': item['status'],
              'driver': item['driver'],
              'eta': item['eta'],
            },
          ),
        },
    };
  }

  static List<Map<String, dynamic>> _compactItems(
    List<dynamic> items,
    Map<String, dynamic> Function(Map<String, dynamic>) mapper,
  ) {
    return items
        .take(4)
        .map((item) => mapper((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}
