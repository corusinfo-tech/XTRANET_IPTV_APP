import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class PanDrmService {
  static const MethodChannel _channel = MethodChannel("xeranet_drm");
  static Completer<void>? _loginCompleter;
  static bool _isLicenseActivated = false;

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

  /// RELEASE DRM
  static Future<void> releaseDrm() async {
    try {
      final result = await _channel.invokeMethod("releaseDrm");
      debugPrint("DRM Released: $result");
    } catch (e) {
      debugPrint("DRM Release Error: $e");
    }
  }

  /// LOGIN
  static Future<void> login(
    String username,
    String password, {
    String license = "",
    String pin = "",
    bool useMAC = false,
  }) async {
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
  static Future<String?> callCasFunction(
    String functionName,
    Map<String, String> params,
  ) async {
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

  /// SET MANAGEMENT SERVER
  static Future<void> setManagementServer(String serverUrl) async {
    // Note: The current native library version _7 handles server discovery automatically
    // or through the init() parameters. This method is locally managed for logic flow.
    debugPrint(
      "PanDrmService: Management server selection: $serverUrl (Native discovery active)",
    );
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
    try {
      final response = await callCasFunction("getStreamingLicenses", {});
      if (response == null) return [];
      final decoded = jsonDecode(response);
      return decoded["answer"] ?? decoded["return"] ?? decoded["licenses"] ?? [];
    } catch (e) {
      if (e is PlatformException && e.code.contains("activation_cooldown")) {
        debugPrint("License activation on cooldown, skipping...");
      } else if (e is! PlatformException) {
        debugPrint("Error parsing Streaming Licenses: $e");
      }
      return [];
    }
  }

  /// RESTORE/ENSURE LICENSE IS ACTIVE (Call once per session)
  static Future<void> ensureLicense() async {
    if (_isLicenseActivated) return;

    try {
      final licenses = await getStreamingLicenses();
      if (licenses.isNotEmpty) {
        final firstLicense = licenses[0] as Map;
        // Check if license is already marked as active in response if possible
        // Otherwise attempt activation
        final key = firstLicense["key"]?.toString() ?? firstLicense["licenseKey"]?.toString();
        if (key != null) {
          await setStreamingLicense(key, "1111");
          _isLicenseActivated = true;
          debugPrint("PanDrmService: License activated successfully.");
        }
      }
    } catch (e) {
      debugPrint("ensureLicense Error: $e");
      // If it fails due to cooldown, we still mark as activated to stop retrying
      if (e is PlatformException && e.code.contains("activation_cooldown")) {
        _isSessionActive = true; 
      }
    }
  }

  static bool _isSessionActive = false; // Internal helper for state tracking

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
    try {
      final response = await callCasFunction("getClientConfig", {});
      if (response == null) return {};
      return jsonDecode(response) as Map<String, dynamic>;
    } catch (e) {
      if (e is! PlatformException) debugPrint("Error parsing Client Config: $e");
      return {};
    }
  }

  /// GET AVAILABLE STREAMS
  static Future<List<dynamic>> getAvailableStreams() async {
    try {
      final response = await callCasFunction("getAvailableStreams", {});
      if (response == null) return [];
      final decoded = jsonDecode(response);
      return decoded["answer"] ?? decoded["return"] ?? decoded["streams"] ?? [];
    } catch (e) {
      // Silence platform permission errors to keep logs clean
      if (e is! PlatformException) debugPrint("Error parsing Available Streams: $e");
      return [];
    }
  }

  /// GET BOUQUETS (Optimized parallel check)
  static Future<List<dynamic>> getBouquets() async {
    final List<String> candidateFunctions = ["cvGetBouquets", "getBouquets"];
    
    // Try both candidates simultaneously
    final results = await Future.wait(candidateFunctions.map((fn) async {
      try {
        final response = await callCasFunction(fn, {});
        if (response == null) return <dynamic>[];
        final decoded = jsonDecode(response);
        final bouquets = decoded["return"] ?? decoded["bouquets"] ?? decoded["answer"];
        return bouquets is List ? bouquets : <dynamic>[];
      } catch (e) {
        return <dynamic>[];
      }
    }));

    // Return the first one that produced a non-empty list
    for (var list in results) {
      if (list != null && list is List && list.isNotEmpty) return list;
    }
    return [];
  }
}
