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
        
        // 1. Silent DRM Login to explicitly validate session prior to ANY data/cache actions
        await PanDrmService.login(username, password);
        
        // 2. Refresh Licenses & Config sequentially
        final licenses = await PanDrmService.getStreamingLicenses().catchError((_) => <dynamic>[]);
        String? activeLicenseKey;
        if (licenses.isNotEmpty) {
          final firstLicense = licenses[0] as Map;
          activeLicenseKey = firstLicense["key"]?.toString() ??
              firstLicense["licenseKey"]?.toString() ??
              firstLicense["smartcard"]?.toString() ??
              firstLicense["license"]?.toString();
        }

        if (activeLicenseKey != null && activeLicenseKey.isNotEmpty) {
          await PanDrmService.setStreamingLicense(activeLicenseKey, "1111");
        }

        await PanDrmService.getClientConfig().catchError((_) => <String, dynamic>{});
        
        // Let DRM library stabilize internal keys briefly 
        await Future.delayed(const Duration(milliseconds: 1500));

        // 3. Inspect Local Cache 
        final hasCache = await DiscoveryService().loadFromCache();

        if (hasCache) {
          // If valid cache is mapped, navigate user IMMEDIATELY 
          emit(const LoginSuccess(streamUrl: "use_cache"));
          
          // Emit Loading state to trigger background UI spinners for Data refresh 
          emit(LoginDataLoading());
          
          try {
             await DiscoveryService().discoverAllContentSilently();
             // Emit fresh state so UI rehydrates updated streams 
             emit(LoginDataLoaded());
          } catch(e) {
             debugPrint("Background silent refresh failed: $e");
             // On background failure, keep Cache state intact, don't crash the active UI. 
          }

        } else {
          // No cache available: block UI and load fresh from Network 
          await DiscoveryService().discoverAllContent();
          
          final streamUrl = DiscoveryService().selectedStreamUrl;
          final streamId = DiscoveryService().selectedStreamId;
          final url = await PanDrmService.getStreamUrl(streamUrl ?? streamId);
          
          if (url != null && url.isNotEmpty) {
            emit(LoginSuccess(streamUrl: url));
          } else {
            add(LogoutRequested());
          }
        }
      } else {
        emit(LoginInitial());
      }
    } catch (e) {
      debugPrint("Silent auto-login session validation failed: $e");
      // Force Login screen redirect on Expired / Invalidated Session 
      add(LogoutRequested());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      await PanDrmService.initDrm();
      await PanDrmService.setManagementServer("https://cv01.panaccess.com");

      // Validate manually 
      await PanDrmService.login(event.username, event.password);

      final licenses = await PanDrmService.getStreamingLicenses().catchError((_) => <dynamic>[]);
      String? activeLicenseKey;
      if (licenses.isNotEmpty) {
        final firstLicense = licenses[0] as Map;
        activeLicenseKey = firstLicense["key"]?.toString() ??
            firstLicense["licenseKey"]?.toString() ??
            firstLicense["smartcard"]?.toString() ??
            firstLicense["license"]?.toString();
      }

      if (activeLicenseKey != null && activeLicenseKey.isNotEmpty) {
        await PanDrmService.setStreamingLicense(activeLicenseKey, "1111");
      }

      await PanDrmService.getClientConfig().catchError((_) => <String, dynamic>{});
      await Future.delayed(const Duration(milliseconds: 1500));

      // Force Discovery synchronously 
      await DiscoveryService().discoverAllContent();

      final streamUrl = DiscoveryService().selectedStreamUrl;
      final streamId = DiscoveryService().selectedStreamId;
      final url = await PanDrmService.getStreamUrl(streamUrl ?? streamId);

      if (url != null && url.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username', event.username);
        await prefs.setString('saved_password', event.password);
        emit(LoginSuccess(streamUrl: url));
        emit(LoginDataLoaded()); // Data is fresh
      } else {
        emit(const LoginFailure(error: "Could not retrieve stream URL"));
      }
    } catch (e) {
      emit(LoginFailure(error: e.toString()));
    }
  }

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<LoginState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    await prefs.remove('cache_bouquets');
    await prefs.remove('cache_streams');
    emit(LoginInitial());

    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
