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
      final results = await Future.wait([
        _service.getGuardJobs(),
        _service.getGuardJobs(status: 'completed'),
      ]);
      _currentJobs = results[0];
      _completedJobs = results[1];
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
}
