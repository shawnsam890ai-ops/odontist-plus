import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as gcal;

/// Lightweight Google Calendar integration focused on creating/updating
/// salary reminder events. This keeps auth state in-memory. For persistence,
/// call [signInSilently] on app start and handle nulls gracefully.
class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  // Request Calendar scope so we can create events
  static const List<String> _scopes = <String>[
    gcal.CalendarApi.calendarScope,
  ];

  GoogleSignIn? _gsi;
  GoogleSignInAccount? _account;
  http.Client? _authedClient;
  gcal.CalendarApi? _api;

  GoogleSignIn get _signIn => _gsi ??= GoogleSignIn(scopes: _scopes);

  bool get isSignedIn => _account != null;

  Future<GoogleSignInAccount?> signIn() async {
    _account = await _signIn.signIn();
    if (_account != null) {
      final authHeaders = await _account!.authHeaders;
      _authedClient = _GoogleAuthClient(authHeaders);
      _api = gcal.CalendarApi(_authedClient!);
    }
    return _account;
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    _account = await _signIn.signInSilently();
    if (_account != null) {
      final authHeaders = await _account!.authHeaders;
      _authedClient = _GoogleAuthClient(authHeaders);
      _api = gcal.CalendarApi(_authedClient!);
    }
    return _account;
  }

  Future<void> signOut() async {
    try { await _signIn.disconnect(); } catch (_) {}
    _account = null;
    _api = null;
    _authedClient = null;
  }

  /// Ensures we have an authenticated API client; triggers sign-in if needed.
  Future<bool> ensureSignedIn() async {
    if (_api != null) return true;
    await signInSilently();
    if (_api != null) return true;
    await signIn();
    return _api != null;
  }

  /// Creates a calendar event and returns its eventId.
  Future<String?> createSalaryEvent({
    required String staffName,
    required DateTime start,
    required double salary,
    double deduction = 0,
    String calendarId = 'primary',
  }) async {
    if (!await ensureSignedIn()) return null;
    final summary = 'Salary payment — $staffName';
    final details = 'Salary: ₹${salary.toStringAsFixed(0)}\nDeduction: ₹${deduction.toStringAsFixed(0)}';
    final end = start.add(const Duration(hours: 1));
    final event = gcal.Event(
      summary: summary,
      description: details,
      start: gcal.EventDateTime(dateTime: start, timeZone: start.timeZoneName),
      end: gcal.EventDateTime(dateTime: end, timeZone: end.timeZoneName),
    );
    final created = await _api!.events.insert(event, calendarId);
    return created.id;
  }

  /// Updates an existing event; returns true if successful.
  Future<bool> updateSalaryEvent({
    required String eventId,
    required DateTime start,
    required double salary,
    double deduction = 0,
    String calendarId = 'primary',
  }) async {
    if (!await ensureSignedIn()) return false;
    final end = start.add(const Duration(hours: 1));
    final updated = gcal.Event(
      summary: null, // keep existing
      description: 'Salary: ₹${salary.toStringAsFixed(0)}\nDeduction: ₹${deduction.toStringAsFixed(0)}',
      start: gcal.EventDateTime(dateTime: start, timeZone: start.timeZoneName),
      end: gcal.EventDateTime(dateTime: end, timeZone: end.timeZoneName),
    );
    final res = await _api!.events.patch(updated, calendarId, eventId);
    return res.id != null;
  }

  Future<bool> deleteEvent(String eventId, {String calendarId = 'primary'}) async {
    if (!await ensureSignedIn()) return false;
    await _api!.events.delete(calendarId, eventId);
    return true;
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
