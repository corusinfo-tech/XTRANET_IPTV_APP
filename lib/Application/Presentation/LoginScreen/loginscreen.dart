import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_event.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_state.dart';
import 'package:xeranet_tv_application/Application/Presentation/FullScreen/fullscreen.dart';
import 'package:xeranet_tv_application/Application/Presentation/MenuScreen/menuscreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController =
      TextEditingController(text: "5391348");
  final TextEditingController passwordController =
      TextEditingController(text: "Tz6M6bWJ");

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _loginButtonFocus = FocusNode();

  String? focusedField;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });

    _emailFocus.addListener(() => _onFocusChange('email', _emailFocus));
    _passwordFocus.addListener(
      () => _onFocusChange('password', _passwordFocus),
    );
    _loginButtonFocus.addListener(
      () => _onFocusChange('login', _loginButtonFocus),
    );
  }

  void _onFocusChange(String field, FocusNode node) {
    if (mounted) {
      setState(() {
        if (node.hasFocus) {
          focusedField = field;
        } else if (focusedField == field) {
          focusedField = null;
        }
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _loginButtonFocus.dispose();
    super.dispose();
  }

  void _signIn() {
    final username = emailController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter credentials")));
      return;
    }

    context.read<LoginBloc>().add(
      LoginSubmitted(username: username, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          // Find the initial channel from DiscoveryService
          final discovery = DiscoveryService();
          final streamId = discovery.selectedStreamId?.toString();
          final stream = discovery.streams.firstWhere(
            (s) => s["id"]?.toString() == streamId,
            orElse: () => discovery.streams.isNotEmpty ? discovery.streams[0] : null,
          );
          
          if (stream != null) {
            final channel = Channel.fromMap(stream);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenPlayerWidget(
                  channel: channel,
                  streamUrl: state.streamUrl,
                ),
              ),
            );
          } else {
            // Revert if no active streaming packages found for user
            context.read<LoginBloc>().add(LogoutRequested());
          }
        } else if (state is LoginFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error)));
        }
      },
      builder: (context, state) {
        if (state is AutoLoginInProgress || state is LoginLoading || state is LoginSuccess) {
          return const Scaffold(
            backgroundColor: Color(0xFF1a1a2e),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 20),
                  Text(
                    "Authenticating...",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              _blob(Colors.blue, top: 0.18, left: 0.70),
              _blob(Colors.purple, bottom: 0.30, right: 0.08),
              _blob(Colors.cyan, top: 0.48, left: 0.10),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double maxWidth = constraints.maxWidth * 0.38;
                    maxWidth = maxWidth.clamp(360.0, 480.0);
                    double titleSize = maxWidth * 0.100;
                    double subtitleSize = maxWidth * 0.04;
                    double inputHeight = maxWidth * 0.135;
                    double buttonHeight = maxWidth * 0.13;

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minWidth: 320,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            "XTRANET",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Premium Television Experience",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: inputHeight,
                            child: _inputField(
                              controller: emailController,
                              focusNode: _emailFocus,
                              hint: "User Name",
                              icon: Icons.person_outline,
                              field: "username",
                              nextFocus: _passwordFocus,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: inputHeight,
                            child: _inputField(
                              controller: passwordController,
                              focusNode: _passwordFocus,
                              hint: "Password",
                              icon: Icons.lock_outline,
                              field: "password",
                              obscure: true,
                              nextFocus: _loginButtonFocus,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(height: buttonHeight, child: _loginButton()),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                fontSize: subtitleSize,
                                color: Colors.grey[350],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob(
    Color color, {
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) {
    return Positioned(
      top: top != null ? MediaQuery.of(context).size.height * top : null,
      left: left != null ? MediaQuery.of(context).size.width * left : null,
      right: right != null ? MediaQuery.of(context).size.width * right : null,
      bottom:
          bottom != null ? MediaQuery.of(context).size.height * bottom : null,
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withOpacity(0.4), color.withOpacity(0.0)],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required String field,
    FocusNode? nextFocus,
    bool obscure = false,
  }) {
    bool isFocused = focusedField == field;

    return Stack(
      children: [
        AnimatedOpacity(
          opacity: isFocused ? 0.55 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(blurRadius: 22, color: Colors.blue.withOpacity(0.42)),
              ],
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(icon, color: Colors.blueAccent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      obscureText: obscure,
                      onSubmitted: (_) {
                        if (nextFocus != null) {
                          nextFocus.requestFocus();
                        } else {
                          _signIn();
                        }
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loginButton() {
    bool isFocused = focusedField == "login";

    return Stack(
      children: [
        AnimatedOpacity(
          opacity: isFocused ? 0.78 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  color: Colors.blue.withOpacity(0.36),
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: _loginButtonFocus,
            onTap: _signIn,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: const Text(
                "Sign In",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
