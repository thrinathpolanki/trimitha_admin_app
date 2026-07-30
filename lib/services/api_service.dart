import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ============================================================================
/// ApiService — the ONLY place in the app that knows about your backend URL.
/// Every screen calls through here instead of using `http` directly, so if
/// your Web App URL ever changes, you only edit it in ONE place: below.
/// ============================================================================
class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  // ---------------------------------------------------------------------
  // EDIT THIS — same Web App URL used by your website's HTML pages.
  // ---------------------------------------------------------------------
  static const String webAppUrl =
      ''; // e.g. https://script.google.com/macros/s/AKfycb.../exec

  // Dart's http client sends a very distinctive, non-browser User-Agent by
  // default (e.g. "Dart/3.4 (dart:io)"), which some networks/edge systems
  // treat with more suspicion than an ordinary mobile browser request.
  // This makes requests look like they're coming from a real browser.
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  };

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'admin_session_token';

  // -------------------------------------------------------------------------
  // TOKEN STORAGE — the session token from login is kept in secure,
  // encrypted device storage (not plain SharedPreferences), and sent with
  // every admin-only request afterward.
  // -------------------------------------------------------------------------
  Future<void> _saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // -------------------------------------------------------------------------
  // LOW-LEVEL HELPERS
  // -------------------------------------------------------------------------

  /// Turns Dart's low-level network exceptions into a message that
  /// actually tells the person what to check, instead of raw exception text.
  String _describeNetworkError(Object e) {
    final msg = e.toString();
    if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
      return 'Your device could not resolve script.google.com at all — this is a network/DNS '
          'problem on the phone or emulator, not the app. Check: (1) the device actually has '
          'working internet — try opening a website in its browser, (2) if you\'re on an '
          'emulator, try a cold boot or switch to a real device, (3) if on WiFi, try switching '
          'to mobile data (or vice versa) to rule out a network that blocks Google domains, '
          '(4) confirm android/app/src/main/AndroidManifest.xml has '
          '<uses-permission android:name="android.permission.INTERNET" /> (flutter create . adds '
          'this automatically, but it\'s worth checking).';
    }
    return 'Could not reach the server: $e';
  }

  /// Apps Script Web Apps return an HTML sign-in/permission page instead of
  /// JSON when the deployment isn't actually reachable without a Google
  /// login — almost always because "Who has access" isn't set to "Anyone",
  /// or the URL used is the /dev testing URL instead of the real /exec one.
  /// This turns that cryptic HTML body into an actionable message instead
  /// of a raw FormatException.
  Map<String, dynamic> _parseResponse(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('<')) {
      return {
        'success': false,
        'error': 'Your backend returned a webpage instead of data. This almost always means: '
            '(1) the Apps Script deployment\'s "Who has access" isn\'t set to "Anyone" — '
            'go to Deploy > Manage deployments > edit > Who has access: Anyone, then Deploy again, or '
            '(2) you copied the /dev URL instead of the real /exec URL. '
            'Check webAppUrl in api_service.dart.',
      };
    }
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': 'Server response was not valid data: $e'
      };
    }
  }

  /// Apps Script /exec URLs respond with an HTTP redirect to the actual
  /// content on googleusercontent.com — real browsers always follow this
  /// invisibly, but that can't be assumed to just work by default in every
  /// HTTP client. This follows redirects explicitly and manually, so the
  /// app never silently ends up reading the redirect response itself
  /// (which is what produces the "webpage instead of data" error).
  Future<http.Response> _sendFollowingRedirects(
    Uri uri, {
    required String method,
    Map<String, String>? headers,
    Object? body,
  }) async {
    var currentUri = uri;
    var currentMethod = method;
    var currentBody = body;

    for (var i = 0; i < 5; i++) {
      final http.Response res;
      if (currentMethod == 'GET') {
        res = await http
            .get(currentUri, headers: headers)
            .timeout(const Duration(seconds: 20));
      } else {
        res = await http
            .post(currentUri, headers: headers, body: currentBody)
            .timeout(const Duration(seconds: 20));
      }

      final isRedirect = {301, 302, 303, 307, 308}.contains(res.statusCode);
      final location = res.headers['location'];
      if (!isRedirect || location == null) return res;

      currentUri = Uri.parse(location);
      // Standard behavior: 301/302/303 convert the next request to GET and
      // drop the body; 307/308 are meant to preserve method+body.
      if ({301, 302, 303}.contains(res.statusCode)) {
        currentMethod = 'GET';
        currentBody = null;
      }
    }
    throw Exception('Too many redirects');
  }

  /// GET request — used for read actions (dashboard, forms, blogs, etc).
  /// `requiresAuth` automatically attaches the saved token as ?token=...
  Future<Map<String, dynamic>> _get(String action,
      {Map<String, String>? params, bool requiresAuth = false}) async {
    final query = <String, String>{'action': action, ...?params};
    if (requiresAuth) {
      final token = await getToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};
      query['token'] = token;
    }
    final uri = Uri.parse(webAppUrl).replace(queryParameters: query);
    try {
      final res = await _sendFollowingRedirects(uri,
          method: 'GET', headers: _browserHeaders);
      return _parseResponse(res.body);
    } catch (e) {
      return {'success': false, 'error': _describeNetworkError(e)};
    }
  }

  /// POST request — used for write actions (login, create/update/delete).
  /// Uses text/plain content-type deliberately: Apps Script Web Apps don't
  /// support CORS preflight (OPTIONS) requests, and text/plain avoids
  /// triggering one from Flutter's http client / a WebView context.
  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> body,
      {bool requiresAuth = false}) async {
    final payload = {'action': action, ...body};
    if (requiresAuth) {
      final token = await getToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};
      payload['token'] = token;
    }
    try {
      final res = await _sendFollowingRedirects(
        Uri.parse(webAppUrl),
        method: 'POST',
        headers: {
          ..._browserHeaders,
          'Content-Type': 'text/plain;charset=utf-8'
        },
        body: jsonEncode(payload),
      );
      return _parseResponse(res.body);
    } catch (e) {
      return {'success': false, 'error': _describeNetworkError(e)};
    }
  }

  // -------------------------------------------------------------------------
  // AUTH
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> login(String username, String password) async {
    final result =
        await _post('login', {'username': username, 'password': password});
    if (result['success'] == true && result['token'] != null) {
      await _saveToken(result['token'] as String);
    }
    return result;
  }

  Future<void> logout() => clearToken();

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<Map<String, dynamic>> whoAmI() => _get('whoami', requiresAuth: true);

  Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) {
    return _post('changePassword',
        {'oldPassword': oldPassword, 'newPassword': newPassword},
        requiresAuth: true);
  }

  // -------------------------------------------------------------------------
  // DASHBOARD
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getDashboard() =>
      _get('dashboard', requiresAuth: true);

  // -------------------------------------------------------------------------
  // FORMS (Trimitha / Thrinath / Thripura contacts)
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getForms(String sheet,
      {String? search, String? status}) {
    return _get('forms', requiresAuth: true, params: {
      'sheet': sheet,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
  }

  Future<Map<String, dynamic>> updateContact(String sheet, int row,
      {String? status, bool? starred, String? notes}) {
    return _post(
        'updateContact',
        {
          'sheet': sheet,
          'row': row,
          if (status != null) 'status': status,
          if (starred != null) 'starred': starred,
          if (notes != null) 'notes': notes,
        },
        requiresAuth: true);
  }

  Future<Map<String, dynamic>> deleteContact(String sheet, int row) {
    return _post('deleteContact', {'sheet': sheet, 'row': row},
        requiresAuth: true);
  }

  // -------------------------------------------------------------------------
  // NOTIFICATIONS
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getNotifications({bool all = false}) {
    return _get('notifications',
        requiresAuth: true, params: {if (all) 'all': 'true'});
  }

  Future<Map<String, dynamic>> markNotificationRead(String sheet, int row) {
    return _post('markNotificationRead', {'sheet': sheet, 'row': row},
        requiresAuth: true);
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() {
    return _post('markAllRead', {}, requiresAuth: true);
  }

  // -------------------------------------------------------------------------
  // BLOGS (admin management — public reading is handled by the website)
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getBlogsAdmin({String? search, String? status}) {
    return _get('adminBlogs', requiresAuth: true, params: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
  }

  Future<Map<String, dynamic>> createBlog(Map<String, dynamic> data) {
    return _post('createBlog', data, requiresAuth: true);
  }

  Future<Map<String, dynamic>> updateBlog(Map<String, dynamic> data) {
    return _post('updateBlog', data, requiresAuth: true);
  }

  Future<Map<String, dynamic>> deleteBlog(int row) {
    return _post('deleteBlog', {'row': row}, requiresAuth: true);
  }

  Future<Map<String, dynamic>> uploadImage(
      String base64Data, String filename, String mimeType) {
    return _post(
        'uploadImage',
        {
          'imageBase64': base64Data,
          'filename': filename,
          'mimeType': mimeType,
        },
        requiresAuth: true);
  }

  // -------------------------------------------------------------------------
  // SEARCH / STATISTICS / EXPORT
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> searchAll(String query) =>
      _get('search', requiresAuth: true, params: {'q': query});

  Future<Map<String, dynamic>> getStatistics() =>
      _get('statistics', requiresAuth: true);

  Future<Map<String, dynamic>> exportData(String type) =>
      _get('export', requiresAuth: true, params: {'type': type});
}
