import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';
import 'package:xeranet_tv_application/main.dart'; 
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  bool _isSessionActive = false;

  LoginBloc() : super(LoginInitial()) {
    on<CheckSavedCredentials>(_onCheckSavedCredentials);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSavedCredentials(
    CheckSavedCredentials event,
    Emitter<LoginState> emit,
  ) async {
    emit(AutoLoginInProgress());
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('saved_username');
      final password = prefs.getString('saved_password');

      if (username != null && password != null) {
        // 1. Inspect Local Cache FIRST
        final hasCache = await DiscoveryService().loadFromCache();

        if (hasCache) {
          // 🚀 ENSURE DRM INIT before navigating to prevent early player failures
          await PanDrmService.initDrm().catchError((e) => debugPrint("Auto-login InitDrm error: $e"));
          
          // Navigate immediately using cached data
          emit(const LoginSuccess(streamUrl: "use_cache"));
          
          // Background: Silently refresh session and data
          _backgroundRefresh(username, password, emit);
        } else {
          // No cache: Minimal login to get streams, then go to UI
          await _performInitialLogin(username, password, emit);
        }
      } else {
        emit(LoginInitial());
      }
    } catch (e) {
      debugPrint("Silent auto-login failed: $e");
      add(LogoutRequested());
    }
  }

  Future<void> _backgroundRefresh(String username, String password, Emitter<LoginState> emit) async {
    if (_isSessionActive) return; // Prevent multiple refreshes
    try {
      await PanDrmService.initDrm();
      await PanDrmService.login(username, password);
      _isSessionActive = true;
      await DiscoveryService().discoverAllContentSilently();
      emit(LoginDataLoaded());
    } catch (e) {
      debugPrint("Background refresh failed: $e");
      _isSessionActive = false;
    }
  }

  Future<void> _performInitialLogin(String username, String password, Emitter<LoginState> emit, {bool isFresh = false}) async {
    if (!_isSessionActive) {
      // 1. Initialise DRM and login
      await PanDrmService.initDrm();
      await PanDrmService.login(username, password);
      _isSessionActive = true;
    }

    if (isFresh) {
      // 2. FRESH LOGIN: Setup licenses and config (MANDATORY)
      await Future.wait([
        _setupLicenses(),
        PanDrmService.getClientConfig().catchError((_) => <String, dynamic>{}),
      ]);
    }

    // 3. Fetch basic content
    await DiscoveryService().discoverAllContent();
    
    // 4. Debug Check: If no streams, try license setup as a last resort fallback
    if (DiscoveryService().streams.isEmpty && !isFresh) {
       debugPrint("⚠️ No streams found with cached session - forcing full refresh");
       await _setupLicenses();
       await DiscoveryService().discoverAllContent();
    }
    
    final streamUrl = DiscoveryService().selectedStreamUrl;
    final streamId = DiscoveryService().selectedStreamId;
    
    if (DiscoveryService().streams.isNotEmpty) {
      emit(LoginSuccess(streamUrl: streamUrl ?? streamId ?? ""));
      emit(LoginDataLoaded());
    } else {
      add(LogoutRequested());
    }
  }

  Future<void> _performFullLogin(String username, String password, Emitter<LoginState> emit) async {
    await _performInitialLogin(username, password, emit, isFresh: true);
  }

  Future<void> _setupLicenses() async {
    final licenses = await PanDrmService.getStreamingLicenses();
    if (licenses.isNotEmpty) {
      final firstLicense = licenses[0] as Map;
      final key = firstLicense["key"]?.toString() ?? firstLicense["licenseKey"]?.toString();
      if (key != null) {
        await PanDrmService.setStreamingLicense(key, "1111");
      }
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      // For manual login, we always reset session status to ensure fresh login
      _isSessionActive = false;
      await _performFullLogin(event.username, event.password, emit);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', event.username);
      await prefs.setString('saved_password', event.password);
    } catch (e) {
      emit(LoginFailure(error: e.toString()));
    }
  }

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<LoginState> emit,
  ) async {
    _isSessionActive = false; // Reset session status on logout
    
    try {
      await PanDrmService.releaseDrm();
    } catch(e) {
      debugPrint("DRM Release during logout failed: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    await prefs.remove('cache_bouquets');
    await prefs.remove('cache_streams');
    emit(LoginInitial());

    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
