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
}
