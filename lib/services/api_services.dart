// lib/services/api_services.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.76.246.230:5001";

  static Map<String, String> get _headers => {"Content-Type": "application/json"};

  // ===================== PING =====================

  static Future<String> pingBackend() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/ping"));
      if (res.statusCode == 200) return jsonDecode(res.body)["message"];
      return "Backend error";
    } catch (e) {
      return "Connection failed";
    }
  }

  // ===================== AUTH =====================

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/auth/login"),
          headers: _headers,
          body: jsonEncode({"email": email, "password": password}));
      final body = jsonDecode(res.body);
      return {
        "success":      body["success"] == true,
        "message":      body["message"]              ?? "Unknown error",
        "role":         body["data"]?["role"]         ?? "",
        "id":           body["data"]?["id"]           ?? 0,
        "full_name":    body["data"]?["full_name"]    ?? "",
        "email":        body["data"]?["email"]        ?? "",
        "avatar_index": body["data"]?["avatar_index"] ?? 0,
      };
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> signupClient({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String password2,
    required String address,
  }) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/auth/signup/client"),
          headers: _headers,
          body: jsonEncode({
            "full_name": fullName, "email": email, "phone": phone,
            "password": password, "password2": password2, "address": address,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> signupProviderStep1({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String password2,
  }) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/auth/signup/provider/step1"),
          headers: _headers,
          body: jsonEncode({
            "full_name": fullName, "email": email, "phone": phone,
            "password": password, "password2": password2,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> signupProviderStep2({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String category,
    required String city,
    required String address,
    required String bio,
  }) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/auth/signup/provider/step2"),
          headers: _headers,
          body: jsonEncode({
            "full_name": fullName, "email": email, "phone": phone,
            "password": password, "category": category, "city": city,
            "address": address, "bio": bio,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== PROVIDERS =====================

  static Future<List<Map<String, dynamic>>> getProviders() async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/providers"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Search providers with optional GPS radius filtering.
  /// Pass [lat] + [lng] + [radius] (km, default 15) for location-based results.
  /// Pass [limit] > 0 to cap the number of results (e.g. 6 for "top picks").
  static Future<List<Map<String, dynamic>>> searchProviders({
    String? q,
    String? category,
    String? city,
    double? lat,
    double? lng,
    double  radius = 15.0,
    int     limit  = 0,
  }) async {
    try {
      final params = <String, String>{};
      if (q        != null && q.isNotEmpty)        params['q']        = q;
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (city     != null && city.isNotEmpty)     params['city']     = city;
      if (lat      != null)                        params['lat']      = lat.toString();
      if (lng      != null)                        params['lng']      = lng.toString();
      if (radius   != 15.0)                        params['radius']   = radius.toString();
      if (limit    > 0)                            params['limit']    = limit.toString();

      final uri  = Uri.parse('$baseUrl/providers/search')
          .replace(queryParameters: params);
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      if (body['success'] == true)
        return List<Map<String, dynamic>>.from(body['data']);
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProviderProfile(int providerId) async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/providers/$providerId"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return body["data"];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateProviderProfile(
      int providerId, Map<String, dynamic> fields) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/providers/$providerId"),
          headers: _headers, body: jsonEncode(fields));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== MESSAGING =====================

  static Future<Map<String, dynamic>> sendMessage({
    required int    senderId,
    required String senderType,
    required int    receiverId,
    required String receiverType,
    required String content,
  }) async {
    try {
      final res  = await http.post(Uri.parse("$baseUrl/messages/send"),
          headers: _headers,
          body: jsonEncode({
            "sender_id":     senderId,
            "sender_type":   senderType,
            "receiver_id":   receiverId,
            "receiver_type": receiverType,
            "content":       content,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<List<Map<String, dynamic>>> getConversation({
    required int clientId,
    required int providerId,
  }) async {
    try {
      final uri  = Uri.parse("$baseUrl/messages/conversation")
          .replace(queryParameters: {
            "client_id":   clientId.toString(),
            "provider_id": providerId.toString(),
          });
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getConversations({
    required int    userId,
    required String userType,
  }) async {
    try {
      final uri  = Uri.parse("$baseUrl/messages/conversations/$userId")
          .replace(queryParameters: {"user_type": userType});
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> markMessagesRead({
    required int    clientId,
    required int    providerId,
    required String readerType,
  }) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/messages/read"),
          headers: _headers,
          body: jsonEncode({
            "client_id":   clientId,
            "provider_id": providerId,
            "reader_type": readerType,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== FAVORITES =====================

  static Future<Map<String, dynamic>> addFavorite({
    required int clientId,
    required int providerId,
  }) async {
    try {
      final res  = await http.post(Uri.parse("$baseUrl/favorites"),
          headers: _headers,
          body: jsonEncode({"client_id": clientId, "provider_id": providerId}));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> removeFavorite({
    required int clientId,
    required int providerId,
  }) async {
    try {
      final res  = await http.delete(Uri.parse("$baseUrl/favorites"),
          headers: _headers,
          body: jsonEncode({"client_id": clientId, "provider_id": providerId}));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<List<Map<String, dynamic>>> getFavorites(int clientId) async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/favorites/$clientId"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> checkFavorite({
    required int clientId,
    required int providerId,
  }) async {
    try {
      final uri  = Uri.parse("$baseUrl/favorites/check").replace(queryParameters: {
        "client_id":   clientId.toString(),
        "provider_id": providerId.toString(),
      });
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      return body["data"]?["is_favorite"] == true;
    } catch (e) {
      return false;
    }
  }

  // ===================== REVIEWS =====================

  static Future<Map<String, dynamic>> addReview({
    required int    providerId,
    required int    clientId,
    required double rating,
    String comment = "",
  }) async {
    try {
      final res  = await http.post(Uri.parse("$baseUrl/reviews"),
          headers: _headers,
          body: jsonEncode({
            "provider_id": providerId,
            "client_id":   clientId,
            "rating":      rating,
            "comment":     comment,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<List<Map<String, dynamic>>> getReviews(int providerId) async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/reviews/$providerId"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===================== CLIENT ACCOUNT =====================

  static Future<Map<String, dynamic>?> getClient(int clientId) async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/client/$clientId"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return body["data"];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateClient(
      int clientId, Map<String, dynamic> fields) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/client/$clientId"),
          headers: _headers, body: jsonEncode(fields));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> changeClientPassword({
    required int    clientId,
    required String currentPassword,
    required String newPassword,
    required String newPassword2,
  }) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/client/$clientId/password"),
          headers: _headers,
          body: jsonEncode({
            "current_password": currentPassword,
            "new_password":     newPassword,
            "new_password2":    newPassword2,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> deleteClient({
    required int    clientId,
    required String password,
  }) async {
    try {
      final res  = await http.delete(Uri.parse("$baseUrl/client/$clientId"),
          headers: _headers, body: jsonEncode({"password": password}));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== PROVIDER ACCOUNT =====================

  static Future<Map<String, dynamic>?> getProviderSettings(int providerId) async {
    try {
      final res  = await http.get(Uri.parse("$baseUrl/provider/$providerId"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return body["data"];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProviderStats(int providerId) async {
    try {
      final res  = await http.get(
          Uri.parse("$baseUrl/provider/$providerId/stats"), headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return body["data"];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> changeProviderPassword({
    required int    providerId,
    required String currentPassword,
    required String newPassword,
    required String newPassword2,
  }) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/provider/$providerId/password"),
          headers: _headers,
          body: jsonEncode({
            "current_password": currentPassword,
            "new_password":     newPassword,
            "new_password2":    newPassword2,
          }));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> deleteProvider({
    required int    providerId,
    required String password,
  }) async {
    try {
      final res  = await http.delete(Uri.parse("$baseUrl/provider/$providerId"),
          headers: _headers, body: jsonEncode({"password": password}));
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== NOTIFICATIONS =====================

  static Future<List<Map<String, dynamic>>> getNotifications({
    required int    userId,
    required String userType,
  }) async {
    try {
      final uri  = Uri.parse("$baseUrl/notifications/$userId")
          .replace(queryParameters: {"user_type": userType});
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true) return List<Map<String, dynamic>>.from(body["data"]);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(int notifId) async {
    try {
      final res  = await http.put(Uri.parse("$baseUrl/notifications/$notifId/read"),
          headers: _headers);
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead({
    required int    userId,
    required String userType,
  }) async {
    try {
      final uri  = Uri.parse("$baseUrl/notifications/readall/$userId")
          .replace(queryParameters: {"user_type": userType});
      final res  = await http.put(uri, headers: _headers);
      final body = jsonDecode(res.body);
      return {"success": body["success"] == true, "message": body["message"] ?? "Unknown error"};
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(int notifId) async {
    try {
      final res  = await http.delete(
          Uri.parse('$baseUrl/notifications/$notifId'),
          headers: _headers);
      final body = jsonDecode(res.body);
      return {'success': body['success'] == true, 'message': body['message'] ?? ''};
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> deleteAllNotifications({
    required int    userId,
    required String userType,
  }) async {
    try {
      final uri  = Uri.parse('$baseUrl/notifications/deleteall/$userId')
          .replace(queryParameters: {'user_type': userType});
      final res  = await http.delete(uri, headers: _headers);
      final body = jsonDecode(res.body);
      return {'success': body['success'] == true, 'message': body['message'] ?? ''};
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ===================== REMINDERS =====================

  static Future<bool> reminderAlreadySent({
    required int    userId,
    required String userType,
    required String reminderKey,
  }) async {
    try {
      final notifs = await getNotifications(userId: userId, userType: userType);
      for (final n in notifs) {
        if (n['type'] != 'reminder') continue;
        try {
          final payload = jsonDecode(n['message'] as String? ?? '{}')
              as Map<String, dynamic>;
          if (payload['reminder_key'] == reminderKey) return true;
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> createReminderNotification({
    required int    userId,
    required String userType,
    required String message,
    required String reminderKey,
    required int    clientId,
    required int    providerId,
    required String partnerName,
    required String date,
    required String time,
    required String description,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/reminder'),
        headers: _headers,
        body: jsonEncode({
          'user_id':      userId,
          'user_type':    userType,
          'message':      message,
          'reminder_key': reminderKey,
          'client_id':    clientId,
          'provider_id':  providerId,
          'partner_name': partnerName,
          'date':         date,
          'time':         time,
          'description':  description,
        }),
      );
    } catch (_) {}
  }

  // ===================== REPORTS =====================

  static Future<Map<String, dynamic>> reportNoShow({
    required int    clientId,
    required int    providerId,
    required String reservationKey,
    required String description,
    required String date,
    required String time,
    String          reason = '',
  }) async {
    try {
      final res  = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
        body: jsonEncode({
          'client_id':       clientId,
          'provider_id':     providerId,
          'reservation_key': reservationKey,
          'reason':          reason,
          'description':     description,
          'date':            date,
          'time':            time,
        }),
      );
      final body = jsonDecode(res.body);
      return {
        'success':         body['success'] == true,
        'message':         body['message']                  ?? '',
        'points_deducted': body['data']?['points_deducted'] ?? 15,
        'new_score':       body['data']?['new_score']       ?? 0,
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  static Future<bool> checkAlreadyReported({
    required int    clientId,
    required int    providerId,
    required String reservationKey,
  }) async {
    try {
      final uri  = Uri.parse('$baseUrl/reports/check').replace(
          queryParameters: {
            'client_id':       clientId.toString(),
            'provider_id':     providerId.toString(),
            'reservation_key': reservationKey,
          });
      final res  = await http.get(uri, headers: _headers);
      final body = jsonDecode(res.body);
      return body['data']?['already_reported'] == true;
    } catch (_) {
      return false;
    }
  }

  // ===================== PHOTO UPLOAD =====================

  static Future<Map<String, dynamic>> uploadProfilePhoto({
    required int    userId,
    required String role,
    required String filePath,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/upload/profile-photo');
      final request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = userId.toString();
      request.fields['role']    = role;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final res      = await http.Response.fromStream(streamed);
      final body     = jsonDecode(res.body);

      return {
        'success':   body['success'] == true,
        'message':   body['message']            ?? '',
        'photo_url': body['data']?['photo_url'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Upload failed', 'photo_url': ''};
    }
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto({
    required int    userId,
    required String role,
  }) async {
    try {
      final res  = await http.delete(
        Uri.parse('$baseUrl/upload/profile-photo'),
        headers: _headers,
        body:    jsonEncode({'user_id': userId, 'role': role}),
      );
      final body = jsonDecode(res.body);
      return {'success': body['success'] == true, 'message': body['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete photo'};
    }
  }

  // ===================== PORTFOLIO =====================

  static Future<Map<String, dynamic>> uploadPortfolioPhoto({
    required int    providerId,
    required String filePath,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/upload/portfolio-photo');
      final request = http.MultipartRequest('POST', uri);
      request.fields['provider_id'] = providerId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send();
      final res      = await http.Response.fromStream(streamed);
      final body     = jsonDecode(res.body);
      return {
        'success':   body['success'] == true,
        'photo_url': body['data']?['photo_url'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'photo_url': ''};
    }
  }

  static Future<Map<String, dynamic>> deletePortfolioPhoto(String filename) async {
    try {
      final res  = await http.delete(
        Uri.parse('$baseUrl/upload/portfolio-photo'),
        headers: _headers,
        body:    jsonEncode({'filename': filename}),
      );
      final body = jsonDecode(res.body);
      return {'success': body['success'] == true};
    } catch (e) {
      return {'success': false};
    }
  }

  // ===================== CHAT MEDIA UPLOAD =====================

  static Future<Map<String, dynamic>> uploadChatMedia({
    required int    userId,
    required String role,
    required String filePath,
  }) async {
    try {
      final uri     = Uri.parse('$baseUrl/upload/chat-media');
      final request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = userId.toString();
      request.fields['role']    = role;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final res      = await http.Response.fromStream(streamed);
      final body     = jsonDecode(res.body);

      return {
        'success':   body['success'] == true,
        'message':   body['message']            ?? '',
        'photo_url': body['data']?['photo_url'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Upload failed', 'photo_url': ''};
    }
  }

  // ===================== RESERVATIONS MAP =====================

  static Future<List<Map<String, dynamic>>> getProviderReservationPins(int providerId) async {
    try {
      final res  = await http.get(
          Uri.parse("$baseUrl/providers/$providerId/reservations/map"),
          headers: _headers);
      final body = jsonDecode(res.body);
      if (body["success"] == true && body["data"] is List) {
        return List<Map<String, dynamic>>.from(body["data"]);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ===================== LOCATION =====================

  /// Get the saved location for a user (client or provider).
  static Future<Map<String, dynamic>?> getLocation({
    required int    userId,
    required String userType,
  }) async {
    try {
      final res  = await http.get(
          Uri.parse('$baseUrl/location/$userType/$userId'),
          headers: _headers);
      final body = jsonDecode(res.body);
      if (body['success'] == true) return body['data'];
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Save confirmed pin location (lat/lng/city) to the backend.
  static Future<Map<String, dynamic>> updateLocation({
    required int    userId,
    required String userType,
    required double lat,
    required double lng,
    String          city = '',
  }) async {
    try {
      final res  = await http.post(
        Uri.parse('$baseUrl/location/update'),
        headers: _headers,
        body: jsonEncode({
          'user_id':   userId,
          'user_type': userType,
          'lat':       lat,
          'lng':       lng,
          'city':      city,
        }),
      );
      final body = jsonDecode(res.body);
      return {
        'success': body['success'] == true,
        'message': body['message'] ?? '',
      };
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }
}