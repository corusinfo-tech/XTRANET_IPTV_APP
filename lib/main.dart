import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_bloc.dart';
import 'package:xeranet_tv_application/Application/Presentation/LoginScreen/loginscreen.dart';
import 'package:xeranet_tv_application/Application/Presentation/SplashScreen/splashscreen.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PanDrmService.initialize();
  runApp(
    BlocProvider(
      create: (context) => LoginBloc(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: NoTransitionsBuilder()},
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
        },
      ),
    ),
  );
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
