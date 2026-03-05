import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:5000";

  // ===================== PING =====================

  static Future<String> pingBackend() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/ping"));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)["message"];
      } else {
        return "Backend error";
      }
    } catch (e) {
      return "Connection failed";
    }
  }

  // ===================== LOGIN =====================

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      final data = jsonDecode(res.body);
      return {
        "success": data["success"] == true,
        "message": data["message"] ?? "Unknown error",
        "role":     data["role"] ?? "",
        "fullName": data["full_name"] ?? "",
      };
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== CLIENT SIGNUP =====================

  static Future<Map<String, dynamic>> signupClient({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String password2,
    required String address,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/signup/client"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "full_name": fullName,
          "email":     email,
          "phone":     phone,
          "password":  password,
          "password2": password2,
          "address":   address,
        }),
      );
      final data = jsonDecode(res.body);
      return {
        "success": data["success"] == true,
        "message": data["message"] ?? "Unknown error",
      };
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== PROVIDER SIGNUP STEP 1 =====================

  static Future<Map<String, dynamic>> signupProviderStep1({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String password2,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/signup/provider/step1"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "full_name": fullName,
          "email":     email,
          "phone":     phone,
          "password":  password,
          "password2": password2,
        }),
      );
      final data = jsonDecode(res.body);
      return {
        "success": data["success"] == true,
        "message": data["message"] ?? "Unknown error",
      };
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  // ===================== PROVIDER SIGNUP STEP 2 =====================

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
      final res = await http.post(
        Uri.parse("$baseUrl/auth/signup/provider/step2"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "full_name": fullName,
          "email":     email,
          "phone":     phone,
          "password":  password,
          "category":  category,
          "city":      city,
          "address":   address,
          "bio":       bio,
        }),
      );
      final data = jsonDecode(res.body);
      return {
        "success": data["success"] == true,
        "message": data["message"] ?? "Unknown error",
      };
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }
}