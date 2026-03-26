// import 'package:flutter/material.dart';
// import 'package:xeranet_tv_application/Application/Presentation/LoginScreen/loginscreen.dart';
// import 'package:xeranet_tv_application/Application/Presentation/SplashScreen/splashscreen.dart';
// import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';

// class RootController extends StatefulWidget {
//   const RootController({Key? key}) : super(key: key);

//   @override
//   _RootControllerState createState() => _RootControllerState();
// }

// class _RootControllerState extends State<RootController> {
//   String screen = 'splash'; // splash | login | main | player
//   Channel? selectedChannel;
//   List<Channel> allChannels = [];

//   void goToLogin() => setState(() => screen = 'login');
//   void goToMain() => setState(() => screen = 'main');
//   void openPlayer(Channel ch) => setState(() {
//     selectedChannel = ch;
//     screen = 'player';
//   });

//   void closePlayer() => setState(() => screen = 'main');

//   void handleChannelChange(String direction) {
//     if (selectedChannel == null || allChannels.isEmpty) return;
//     final currentIndex = allChannels.indexWhere(
//       (c) => c.id == selectedChannel!.id,
//     );
//     if (currentIndex == -1) return;
//     int newIndex;
//     if (direction == 'next') {
//       newIndex = (currentIndex + 1) % allChannels.length;
//     } else {
//       newIndex = currentIndex == 0 ? allChannels.length - 1 : currentIndex - 1;
//     }
//     setState(() => selectedChannel = allChannels[newIndex]);
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget body;
//     switch (screen) {
//       case 'splash':
//         body = SplashScreen(onComplete: goToLogin);
//         break;
//       case 'login':
//         body = LoginScreen(onLogin: goToMain);
//         break;
//       case 'main':
//         body = MainScreen(
//           onChannelSelect: (ch, channels) {
//             allChannels = channels; // keep master list
//             openPlayer(ch);
//           },
//         );
//         break;
//       case 'player':
//         body = FullScreenPlayer(
//           channel: selectedChannel!,
//           onClose: closePlayer,
//           onChannelChange: (dir) => handleChannelChange(dir),
//         );
//         break;
//       default:
//         body = const SizedBox.shrink();
//     }

//     return Scaffold(body: SafeArea(child: body));
//   }
// }
