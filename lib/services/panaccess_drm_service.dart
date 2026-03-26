import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class PanDrmService {
  static const MethodChannel _channel = MethodChannel("xeranet_drm");
  static Completer<void>? _loginCompleter;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "onDrmEvent":
          final Map? args = call.arguments as Map?;
          final event = args?["event"];
          debugPrint("PanDrmService: Received event: $event");
          break;
        default:
          debugPrint("PanDrmService: Unknown method ${call.method}");
      }
    });
  }

  /// INIT DRM
  static Future<void> initDrm() async {
    try {
      final result = await _channel.invokeMethod("initDrm", {
        "company": "RCUBE",
        "brand": "Generic",
        "appVersion": "1.0.0r",
        "osVersion": "Android12",
        "hint": 456,
      });

      debugPrint("DRM Init: $result");
    } catch (e) {
      debugPrint("DRM Init Error: $e");
      rethrow;
    }
  }

  /// LOGIN
  static Future<void> login(String username, String password,
      {String license = "", String pin = "", bool useMAC = false}) async {
    try {
      debugPrint("Starting login for $username (useMAC: $useMAC)...");
      final result = await _channel.invokeMethod("login", {
        "username": username,
        "password": password,
        "license": license,
        "pin": pin,
        "useMAC": useMAC,
      });

      debugPrint("Login result: $result");
      if (result != "LOGIN_SUCCESS") {
        throw Exception("Login failed: $result");
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      rethrow;
    }
  }

  /// GET LIVE STREAM URL (HLS)
  static Future<String?> getStreamUrl(dynamic streamUrl) async {
    try {
      final String? url = await _channel.invokeMethod("getStreamUrl", {
        "streamUrl": streamUrl,
      });

      return url;
    } catch (e) {
      debugPrint("Get Stream URL Error: $e");
      rethrow;
    }
  }

  /// GET CATCHUP URL (HLS)
  static Future<String?> getCatchupUrl(dynamic catchupId) async {
    try {
      final String? url = await _channel.invokeMethod("getCatchupUrl", {
        "catchupId": catchupId,
      });

      return url;
    } catch (e) {
      debugPrint("Get Catchup URL Error: $e");
      rethrow;
    }
  }

  /// GET VOD URL (HLS)
  static Future<String?> getVodUrl(dynamic vodId) async {
    try {
      final String? url = await _channel.invokeMethod("getVodUrl", {
        "vodId": vodId,
      });

      return url;
    } catch (e) {
      debugPrint("Get VOD URL Error: $e");
      rethrow;
    }
  }

  /// CALL CAS FUNCTION (CABVIEW)
  /// Returns the JSON response as a String
  static Future<String?> callCasFunction(String functionName, Map<String, String> params) async {
    try {
      final String? response = await _channel.invokeMethod("callCasFunction", {
        "functionName": functionName,
        "params": params,
      });
      
      debugPrint("CAS Response [$functionName]: $response");
      return response;
    } catch (e) {
      debugPrint("Call CAS Function Error: $e");
      rethrow;
    }
  }

  /// GET OTT CATEGORY GROUPS (Helper)
  static Future<List<dynamic>> getOttCategoryGroups() async {
    final response = await callCasFunction("getOttCategoryGroups", {"includeList": "true"});
    if (response == null) return [];
    try {
      final decoded = jsonDecode(response);
      debugPrint("PanDrmService: Decoded Categories: $decoded");
      return decoded["answer"] ?? decoded["return"] ?? [];
    } catch (e) {
      debugPrint("Error parsing Categories JSON: $e");
      return [];
    }
  }

  /// GET OTT STREAMS BY CATEGORY ID (Helper)
  static Future<List<dynamic>> getOttStreamsByCategoryId(dynamic categoryId) async {
    final response = await callCasFunction("getOttStreamsByCategoryId", {
      "categoryId": categoryId.toString()
    });
    if (response == null) return [];
    try {
      final decoded = jsonDecode(response);
      debugPrint("PanDrmService: Decoded Streams for Category $categoryId: $decoded");
      return decoded["answer"] ?? decoded["return"] ?? [];
    } catch (e) {
      debugPrint("Error parsing Streams JSON: $e");
      return [];
    }
  }

  /// SET MANAGEMENT SERVER
  static Future<void> setManagementServer(String serverUrl) async {
    // Note: The current native library version _7 handles server discovery automatically
    // or through the init() parameters. This method is locally managed for logic flow.
    debugPrint("PanDrmService: Management server selection: $serverUrl (Native discovery active)");
  }

  /// GET DRM INFO
  static Future<Map?> getDrmInfo() async {
    try {
      final Map info = await _channel.invokeMethod("getDrmInfo");
      return info;
    } catch (e) {
      debugPrint("DRM Info Error: $e");
      rethrow;
    }
  }

  /// GET STREAMING LICENSES
  static Future<List<dynamic>> getStreamingLicenses() async {
    final response = await callCasFunction("getStreamingLicenses", {});
    if (response == null) return [];
    try {
      final decoded = jsonDecode(response);
      return decoded["answer"] ?? decoded["return"] ?? decoded["licenses"] ?? [];
    } catch (e) {
      debugPrint("Error parsing Streaming Licenses: $e");
      return [];
    }
  }

  /// SET STREAMING LICENSE
  static Future<void> setStreamingLicense(String licenseKey, String pin) async {
    final response = await callCasFunction("setStreamingLicense", {
      "licenseKey": licenseKey,
      "pin": pin,
    });
    debugPrint("Set Streaming License Response: $response");
  }

  /// GET CLIENT CONFIG
  static Future<Map<String, dynamic>> getClientConfig() async {
    final response = await callCasFunction("getClientConfig", {});
    if (response == null) return {};
    try {
      return jsonDecode(response);
    } catch (e) {
      debugPrint("Error parsing Client Config: $e");
      return {};
    }
  }

  /// GET AVAILABLE STREAMS
  static Future<List<dynamic>> getAvailableStreams() async {
    final response = await callCasFunction("getAvailableStreams", {});
    if (response == null) return [];
    try {
      final decoded = jsonDecode(response);
      return decoded["answer"] ?? decoded["return"] ?? decoded["streams"] ?? [];
    } catch (e) {
      debugPrint("Error parsing Available Streams: $e");
      return [];
    }
  }
}
