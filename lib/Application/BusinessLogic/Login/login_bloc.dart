import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('saved_username');
    final password = prefs.getString('saved_password');

    if (username != null && password != null) {
      // Attempt auto-login
      add(LoginSubmitted(username: username, password: password));
    } else {
      emit(LoginInitial());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      // 1. Init DRM
      await PanDrmService.initDrm();

      // 2. Set Server (Default if not provided)
      await PanDrmService.setManagementServer("https://cv01.panaccess.com");

      // 3. Login
      await PanDrmService.login(event.username, event.password);

      // 3. Get Streaming Licenses
      debugPrint("LoginBloc: Fetching streaming licenses...");
      final licenses = await PanDrmService.getStreamingLicenses();
      
      String? activeLicenseKey;
      if (licenses.isNotEmpty) {
        final firstLicense = licenses[0] as Map;
        activeLicenseKey = firstLicense["key"]?.toString() ??
            firstLicense["licenseKey"]?.toString() ??
            firstLicense["smartcard"]?.toString() ??
            firstLicense["license"]?.toString();
      }

      if (activeLicenseKey != null && activeLicenseKey.isNotEmpty) {
        debugPrint("LoginBloc: Activating license: $activeLicenseKey");
        await PanDrmService.setStreamingLicense(activeLicenseKey, "1111"); // Use "1111" as default PIN (from original code)
      }

      // 4. Get Client Config
      debugPrint("LoginBloc: Fetching client config...");
      await PanDrmService.getClientConfig();

      // 5. Wait for DRM to stabilize
      await Future.delayed(const Duration(milliseconds: 1500));

      // 6. Discovery
      await DiscoveryService().discoverAllContent();

      // 7. Get initial stream URL
      final streamUrl = DiscoveryService().selectedStreamUrl;
      final streamId = DiscoveryService().selectedStreamId;

      final url = await PanDrmService.getStreamUrl(streamUrl ?? streamId);

      if (url != null && url.isNotEmpty) {
        // Save credentials for next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username', event.username);
        await prefs.setString('saved_password', event.password);

        emit(LoginSuccess(streamUrl: url));
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
    emit(LoginInitial());
  }
}
