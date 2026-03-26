// import 'package:flutter/services.dart';

// typedef VoidCallback = void Function();
// typedef NumberCallback = void Function(int number);

// class KeyboardNavigation {
//   static bool _initialized = false;

//   static void initialize({
//     required VoidCallback onUp,
//     required VoidCallback onDown,
//     required VoidCallback onLeft,
//     required VoidCallback onRight,
//     required VoidCallback onEnter,
//     required NumberCallback onNumber,
//   }) {
//     if (_initialized) return;
//     _initialized = true;

//     // Listen to raw remote/keyboard events
//     // ignore: deprecated_member_use
//     RawKeyboard.instance.addListener((RawKeyEvent event) {
//       // ignore: deprecated_member_use
//       if (event is RawKeyDownEvent) {
//         final key = event.logicalKey;

//         if (key == LogicalKeyboardKey.arrowUp) {
//           onUp();
//         } else if (key == LogicalKeyboardKey.arrowDown) {
//           onDown();
//         } else if (key == LogicalKeyboardKey.arrowLeft) {
//           onLeft();
//         } else if (key == LogicalKeyboardKey.arrowRight) {
//           onRight();
//         } else if (key == LogicalKeyboardKey.enter ||
//             key == LogicalKeyboardKey.select) {
//           onEnter();
//         } else if (_isNumberKey(key)) {
//           int number = _keyToNumber(key);
//           onNumber(number);
//         }
//       }
//     });
//   }

//   static bool _isNumberKey(LogicalKeyboardKey key) {
//     return (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
//             key.keyId <= LogicalKeyboardKey.digit9.keyId) ||
//         (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
//             key.keyId <= LogicalKeyboardKey.numpad9.keyId);
//   }

//   static int _keyToNumber(LogicalKeyboardKey key) {
//     if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
//         key.keyId <= LogicalKeyboardKey.digit9.keyId) {
//       return key.keyId - LogicalKeyboardKey.digit0.keyId;
//     }
//     if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
//         key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
//       return key.keyId - LogicalKeyboardKey.numpad0.keyId;
//     }
//     return 0;
//   }
// }
