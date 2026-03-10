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
            return s == 'assigned' || s == 'en_route' || s == 'arrived';
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
}
