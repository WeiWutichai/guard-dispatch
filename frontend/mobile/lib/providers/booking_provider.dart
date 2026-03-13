import 'package:flutter/foundation.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _service;

  BookingProvider(this._service);

  // Dashboard
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? get dashboard => _dashboard;

  // Jobs
  List<Map<String, dynamic>> _currentJobs = [];
  List<Map<String, dynamic>> get currentJobs => _currentJobs;

  List<Map<String, dynamic>> _completedJobs = [];
  List<Map<String, dynamic>> get completedJobs => _completedJobs;

  // Earnings
  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? get earnings => _earnings;

  // Work History
  Map<String, dynamic>? _workHistory;
  Map<String, dynamic>? get workHistory => _workHistory;

  // Ratings
  Map<String, dynamic>? _ratings;
  Map<String, dynamic>? get ratings => _ratings;

  // Service rates (pricing)
  List<Map<String, dynamic>> _serviceRates = [];
  List<Map<String, dynamic>> get serviceRates => _serviceRates;

  bool _isLoadingRates = false;
  bool get isLoadingRates => _isLoadingRates;

  // Customer requests
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> get myRequests => _myRequests;

  bool _isLoadingRequests = false;
  bool get isLoadingRequests => _isLoadingRequests;

  // Loading & error
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _dashboard = await _service.getGuardDashboard();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchJobs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Fetch all jobs and split by assignment_status client-side
      final allJobs = await _service.getGuardJobs(limit: 100);
      _currentJobs = allJobs
          .where((j) {
            final s = j['assignment_status'] as String?;
            return s == 'pending_acceptance' ||
                s == 'accepted' ||
                s == 'awaiting_payment' ||
                s == 'assigned' ||
                s == 'en_route' ||
                s == 'arrived';
          })
          .toList();
      _completedJobs = allJobs
          .where((j) => j['assignment_status'] == 'completed')
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchEarnings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _earnings = await _service.getGuardEarnings();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateAssignmentStatus(
    String assignmentId,
    String status,
  ) async {
    try {
      await _service.updateAssignmentStatus(assignmentId, status);
      // Refresh jobs after status update
      await fetchJobs();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Customer reviews guard's completion request (approve or hold)
  Future<Map<String, dynamic>> reviewCompletion(
    String assignmentId,
    bool approve,
  ) async {
    return await _service.reviewCompletion(assignmentId, approve);
  }

  /// Customer submits star rating review for completed assignment
  Future<Map<String, dynamic>> submitReview(
    String assignmentId, {
    required double overallRating,
    double? punctuality,
    double? professionalism,
    double? communication,
    double? appearance,
    String? reviewText,
  }) async {
    return await _service.submitReview(
      assignmentId,
      overallRating: overallRating,
      punctuality: punctuality,
      professionalism: professionalism,
      communication: communication,
      appearance: appearance,
      reviewText: reviewText,
    );
  }

  Future<void> fetchWorkHistory({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _workHistory = await _service.getGuardWorkHistory(status: status);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchRatings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _ratings = await _service.getGuardRatings();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // =========================================================================
  // Pricing
  // =========================================================================

  Future<void> fetchServiceRates() async {
    _isLoadingRates = true;
    _error = null;
    notifyListeners();
    try {
      _serviceRates = await _service.listServiceRates();
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingRates = false;
    notifyListeners();
  }

  // Customer (Hirer) methods
  // =========================================================================

  Future<void> fetchMyRequests({String? status}) async {
    _isLoadingRequests = true;
    _error = null;
    notifyListeners();
    try {
      _myRequests = await _service.listMyRequests(status: status);
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingRequests = false;
    notifyListeners();
  }

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
    _error = null;
    try {
      final result = await _service.createRequest(
        locationLat: locationLat,
        locationLng: locationLng,
        address: address,
        description: description,
        offeredPrice: offeredPrice,
        specialInstructions: specialInstructions,
        urgency: urgency,
        bookedHours: bookedHours,
      );
      // Refresh list after creating
      await fetchMyRequests();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelRequest(String requestId) async {
    _error = null;
    try {
      await _service.cancelRequest(requestId);
      await fetchMyRequests();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // =========================================================================
  // Available Guards (customer guard discovery)
  // =========================================================================

  List<Map<String, dynamic>> _availableGuards = [];
  List<Map<String, dynamic>> get availableGuards => _availableGuards;

  bool _isLoadingGuards = false;
  bool get isLoadingGuards => _isLoadingGuards;

  Future<void> fetchAvailableGuards(double lat, double lng) async {
    _isLoadingGuards = true;
    _error = null;
    notifyListeners();
    try {
      _availableGuards = await _service.listAvailableGuards(
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingGuards = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> assignGuardToRequest(
    String requestId,
    String guardId,
  ) async {
    _error = null;
    try {
      final result = await _service.assignGuardToRequest(requestId, guardId);
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =========================================================================
  // Guard Accept/Decline Assignment
  // =========================================================================

  Future<void> acceptAssignment(String assignmentId) async {
    _error = null;
    try {
      await _service.acceptDeclineAssignment(assignmentId, true);
      await fetchJobs();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineAssignment(String assignmentId) async {
    _error = null;
    try {
      await _service.acceptDeclineAssignment(assignmentId, false);
      await fetchJobs();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =========================================================================
  // Payment (Customer)
  // =========================================================================

  Future<Map<String, dynamic>> makePayment({
    required String requestId,
    required double amount,
    required String paymentMethod,
  }) async {
    _error = null;
    try {
      final result = await _service.createPayment(
        requestId: requestId,
        amount: amount,
        paymentMethod: paymentMethod,
      );
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =========================================================================
  // Active Job (Guard)
  // =========================================================================

  Map<String, dynamic>? _activeJob;
  Map<String, dynamic>? get activeJob => _activeJob;

  Future<void> fetchActiveJob() async {
    _error = null;
    try {
      _activeJob = await _service.getActiveJob();
      notifyListeners();
    } catch (e) {
      _activeJob = null;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Fetch active job data and return it (for resuming countdown).
  Future<Map<String, dynamic>?> fetchActiveJobData() async {
    _error = null;
    try {
      final result = await _service.getActiveJob();
      _activeJob = result;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>> startActiveJob(String assignmentId) async {
    _error = null;
    try {
      final result = await _service.startJob(assignmentId);
      _activeJob = result;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch active job info for a customer's request. Returns null on error.
  Future<Map<String, dynamic>?> getCustomerActiveJob(String requestId) async {
    return await _service.getCustomerActiveJob(requestId);
  }

  // =========================================================================
  // Get Assignments for a Request (Customer polling)
  // =========================================================================

  Future<List<Map<String, dynamic>>> getAssignments(String requestId) async {
    try {
      return await _service.getAssignments(requestId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =========================================================================
  // Guard Location (Customer tracking)
  // =========================================================================

  /// Fetch guard's latest location. Returns null on error (for polling).
  Future<Map<String, dynamic>?> getGuardLocation(String guardId) async {
    return await _service.getGuardLocation(guardId);
  }
}
