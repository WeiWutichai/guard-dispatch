import '../services/api_client.dart';

class BookingService {
  final ApiClient _apiClient;

  BookingService(this._apiClient);

  /// GET /booking/guard/dashboard
  Future<Map<String, dynamic>> getGuardDashboard() async {
    final response = await _apiClient.dio.get('/booking/guard/dashboard');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /booking/guard/jobs?status=...&limit=...&offset=...
  Future<List<Map<String, dynamic>>> getGuardJobs({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get(
      '/booking/guard/jobs',
      queryParameters: params,
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /booking/guard/earnings
  Future<Map<String, dynamic>> getGuardEarnings() async {
    final response = await _apiClient.dio.get('/booking/guard/earnings');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// PUT /booking/assignments/{id}/status
  Future<Map<String, dynamic>> updateAssignmentStatus(
    String assignmentId,
    String status,
  ) async {
    final response = await _apiClient.dio.put(
      '/booking/assignments/$assignmentId/status',
      data: {'status': status},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /booking/guard/work-history?status=...&limit=...&offset=...
  Future<Map<String, dynamic>> getGuardWorkHistory({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get(
      '/booking/guard/work-history',
      queryParameters: params,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /booking/guard/ratings
  Future<Map<String, dynamic>> getGuardRatings() async {
    final response = await _apiClient.dio.get('/booking/guard/ratings');
    return response.data['data'] as Map<String, dynamic>;
  }

  // =========================================================================
  // Customer (Hirer) endpoints
  // =========================================================================

  /// POST /booking/requests — create a new guard request.
  Future<Map<String, dynamic>> createRequest({
    required double locationLat,
    required double locationLng,
    required String address,
    String? description,
    double? offeredPrice,
    String? specialInstructions,
    String urgency = 'medium',
    int? bookedHours,
  }) async {
    final response = await _apiClient.dio.post(
      '/booking/requests',
      data: <String, dynamic>{
        'location_lat': locationLat,
        'location_lng': locationLng,
        'address': address,
        if (description != null && description.isNotEmpty)
          'description': description,
        'offered_price': ?offeredPrice,
        if (specialInstructions != null && specialInstructions.isNotEmpty)
          'special_instructions': specialInstructions,
        'urgency': urgency,
        'booked_hours': ?bookedHours,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /booking/requests — list customer's own requests.
  Future<List<Map<String, dynamic>>> listMyRequests({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get(
      '/booking/requests',
      queryParameters: params,
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /booking/requests/{id} — get a single request detail.
  Future<Map<String, dynamic>> getRequest(String requestId) async {
    final response = await _apiClient.dio.get('/booking/requests/$requestId');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// PUT /booking/requests/{id}/cancel — cancel a pending request.
  Future<void> cancelRequest(String requestId) async {
    await _apiClient.dio.put('/booking/requests/$requestId/cancel');
  }

  // =========================================================================
  // Pricing (public — no JWT required)
  // =========================================================================

  /// GET /booking/pricing/services — list active service rates.
  Future<List<Map<String, dynamic>>> listServiceRates() async {
    final response = await _apiClient.dio.get('/booking/pricing/services');
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /booking/requests/{id}/assignments — get assignments for a request.
  Future<List<Map<String, dynamic>>> getAssignments(String requestId) async {
    final response = await _apiClient.dio.get(
      '/booking/requests/$requestId/assignments',
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // =========================================================================
  // Available Guards (customer discovery)
  // =========================================================================

  /// GET /booking/available-guards — list nearby online guards.
  Future<List<Map<String, dynamic>>> listAvailableGuards({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/booking/available-guards',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /booking/requests/{id}/assign — assign a guard to a request.
  Future<Map<String, dynamic>> assignGuardToRequest(
    String requestId,
    String guardId,
  ) async {
    final response = await _apiClient.dio.post(
      '/booking/requests/$requestId/assign',
      data: {'guard_id': guardId},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  // =========================================================================
  // Accept / Decline Assignment (guard response)
  // =========================================================================

  /// PUT /booking/assignments/{id}/accept — guard accepts or declines.
  Future<Map<String, dynamic>> acceptDeclineAssignment(
    String assignmentId,
    bool accept,
  ) async {
    final response = await _apiClient.dio.put(
      '/booking/assignments/$assignmentId/accept',
      data: {'accept': accept},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  // =========================================================================
  // Payments (simulated)
  // =========================================================================

  /// POST /booking/payments — create simulated payment.
  Future<Map<String, dynamic>> createPayment({
    required String requestId,
    required double amount,
    required String paymentMethod,
  }) async {
    final response = await _apiClient.dio.post(
      '/booking/payments',
      data: {
        'request_id': requestId,
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  // =========================================================================
  // Active Job (guard countdown)
  // =========================================================================

  /// PUT /booking/assignments/{id}/start — guard starts the job.
  Future<Map<String, dynamic>> startJob(String assignmentId) async {
    final response = await _apiClient.dio.put(
      '/booking/assignments/$assignmentId/start',
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /booking/guard/active-job — get guard's current active job.
  Future<Map<String, dynamic>?> getActiveJob() async {
    final response = await _apiClient.dio.get('/booking/guard/active-job');
    return response.data['data'] as Map<String, dynamic>?;
  }
}
