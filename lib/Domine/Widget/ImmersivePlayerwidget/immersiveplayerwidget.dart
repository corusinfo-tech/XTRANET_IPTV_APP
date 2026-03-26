// // ignore_for_file: non_constant_identifier_names, deprecated_member_use

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:video_player/video_player.dart';
// import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';

// class ImmersivePlayerWidget extends StatefulWidget {
//   final Channel channel;
//   final EPGProgram? currentProgram;
//   final EPGProgram? nextProgram;
//   final VoidCallback onClose;

//   const ImmersivePlayerWidget({
//     super.key,
//     required this.channel,
//     required this.onClose,
//     this.currentProgram,
//     this.nextProgram,
//   });

//   @override
//   // ignore: library_private_types_in_public_api
//   _ImmersivePlayerWidgetState createState() => _ImmersivePlayerWidgetState();
// }

// class _ImmersivePlayerWidgetState extends State<ImmersivePlayerWidget>
//     with TickerProviderStateMixin {
//   bool showOverlay = true;
//   bool isPlaying = true;
//   bool isMuted = false;
//   int volume = 80;
//   double programProgress = 0.0;
//   Timer? overlayTimer;
//   Timer? clockTimer;
//   DateTime currentTime = DateTime.now();

//   late VideoPlayerController _videoController;
//   final FocusNode _focusNode = FocusNode();

//   @override
//   void initState() {
//     super.initState();

//     _videoController = VideoPlayerController.network(widget.channel.streamUrl)
//       ..initialize().then((_) {
//         setState(() {});
//         _videoController.setLooping(true);
//         _videoController.setVolume(volume / 100.0);
//         _videoController.play();
//       });

//     _calcProgramProgress();
//     _startOverlayTimer();

//     clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       setState(() {
//         currentTime = DateTime.now();
//       });
//     });

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _focusNode.requestFocus();
//     });
//   }

//   @override
//   void didUpdateWidget(covariant ImmersivePlayerWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (oldWidget.channel.streamUrl != widget.channel.streamUrl) {
//       _videoController.pause();
//       _videoController.dispose();

//       _videoController = VideoPlayerController.network(widget.channel.streamUrl)
//         ..initialize().then((_) {
//           setState(() {});
//           _videoController.setLooping(true);
//           _videoController.setVolume(isMuted ? 0 : volume / 100.0);
//           _videoController.play();
//         });
//     }

//     _calcProgramProgress();
//   }

//   @override
//   void dispose() {
//     overlayTimer?.cancel();
//     clockTimer?.cancel();
//     _videoController.dispose();
//     _focus_node_dispose_safe();
//     super.dispose();
//   }

//   // safe focus node dispose (in case it was already disposed)
//   void _focus_node_dispose_safe() {
//     try {
//       _focus_node_try_unfocus();
//       _focusNode.dispose();
//     } catch (_) {}
//   }

//   void _focus_node_try_unfocus() {
//     if (_focusNode.hasFocus) _focusNode.unfocus();
//   }

//   void _startOverlayTimer() {
//     overlayTimer?.cancel();
//     setState(() => showOverlay = true);

//     overlayTimer = Timer(const Duration(seconds: 5), () {
//       setState(() => showOverlay = false);
//     });
//   }

//   void _onKey(RawKeyEvent event) {
//     if (event is RawKeyDownEvent) {
//       _startOverlayTimer();

//       if (event.logicalKey == LogicalKeyboardKey.escape) {
//         widget.onClose();
//       } else if (event.logicalKey == LogicalKeyboardKey.space) {
//         setState(() {
//           isPlaying = !isPlaying;
//           if (isPlaying) {
//             _videoController.play();
//           } else {
//             _videoController.pause();
//           }
//         });
//       } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
//         setState(() {
//           isMuted = !isMuted;
//           _videoController.setVolume(isMuted ? 0 : volume / 100.0);
//         });
//       } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
//         setState(() {
//           volume = (volume + 5).clamp(0, 100);
//           if (!isMuted) {
//             _videoController.setVolume(volume / 100.0);
//           }
//         });
//       } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
//         setState(() {
//           volume = (volume - 5).clamp(0, 100);
//           if (!isMuted) {
//             _videoController.setVolume(volume / 100.0);
//           }
//         });
//       }
//     }
//   }

//   // Accepts DateTime or ISO String; returns DateTime
//   DateTime _toDateTime(dynamic value) {
//     if (value is DateTime) return value;
//     if (value is String) {
//       // try parse; if fails, fallback to epoch 0
//       try {
//         return DateTime.parse(value);
//       } catch (_) {
//         // attempt to parse milliseconds (string number)
//         try {
//           final ms = int.parse(value);
//           return DateTime.fromMillisecondsSinceEpoch(ms);
//         } catch (_) {
//           return DateTime.fromMillisecondsSinceEpoch(0);
//         }
//       }
//     }
//     // fallback
//     return DateTime.fromMillisecondsSinceEpoch(0);
//   }

//   void _calcProgramProgress() {
//     final cur = widget.currentProgram;
//     if (cur == null) {
//       programProgress = 0.0;
//       return;
//     }

//     final now = DateTime.now().millisecondsSinceEpoch;
//     final start = _toDateTime(cur.startTime).millisecondsSinceEpoch;
//     final end = _toDateTime(cur.endTime).millisecondsSinceEpoch;

//     final total = (end - start).toDouble();
//     final elapsed = (now - start).toDouble();

//     if (total <= 0) {
//       programProgress = 0.0;
//     } else {
//       programProgress = ((elapsed / total) * 100.0).clamp(0.0, 100.0);
//     }
//   }

//   // returns 'hh:mm AM/PM' for given DateTime or ISO string
//   String _format12Hour(dynamic value) {
//     final dt = _toDateTime(value);
//     final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
//     final minute = dt.minute.toString().padLeft(2, '0');
//     final ampm = dt.hour >= 12 ? 'PM' : 'AM';
//     return '$hour:$minute $ampm';
//   }

//   String formatProgramTime(dynamic date) {
//     return _format12Hour(date);
//   }

//   int getDurationMinutes(dynamic start, dynamic end) {
//     final s = _toDateTime(start);
//     final e = _toDateTime(end);
//     return e.difference(s).inMinutes;
//   }

//   @override
//   Widget build(BuildContext context) {
//     _calcProgramProgress();

//     return RawKeyboardListener(
//       focusNode: _focusNode,
//       onKey: _onKey,
//       child: MouseRegion(
//         onHover: (_) => _startOverlayTimer(),
//         child: Stack(
//           children: [
//             // background video
//             Positioned.fill(
//               child:
//                   _videoController.value.isInitialized
//                       ? VideoPlayer(_videoController)
//                       : Container(color: Colors.black),
//             ),

//             // gradient overlay
//             Positioned.fill(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Color(0x4D000000),
//                       Colors.transparent,
//                       Color(0xCC000000),
//                     ],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                 ),
//               ),
//             ),

//             // overlay UI (top-right clock & close)
//             AnimatedOpacity(
//               duration: const Duration(milliseconds: 400),
//               opacity: showOverlay ? 1 : 0,
//               child: IgnorePointer(
//                 ignoring: false,
//                 child: Container(
//                   width: double.infinity,
//                   height: double.infinity,
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     children: [
//                       Align(
//                         alignment: Alignment.topRight,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               // custom formatted clock
//                               _format12Hour(currentTime),
//                               style: const TextStyle(
//                                 fontSize: 42,
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               '${_weekdayShort(currentTime.weekday)}, ${_monthShort(currentTime.month)} ${currentTime.day}',
//                               style: const TextStyle(color: Colors.white70),
//                             ),
//                             const SizedBox(height: 12),
//                             SizedBox(
//                               width: 120,
//                               child: ElevatedButton(
//                                 onPressed: widget.onClose,
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.white10,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   side: BorderSide(
//                                     color: Colors.white.withOpacity(0.12),
//                                   ),
//                                 ),
//                                 child: const Icon(
//                                   Icons.close,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const Spacer(),
//                       // bottom sheet content
//                       Align(
//                         alignment: Alignment.bottomCenter,
//                         child: AnimatedSlide(
//                           offset:
//                               showOverlay
//                                   ? const Offset(0, 0)
//                                   : const Offset(0, 0.15),
//                           duration: const Duration(milliseconds: 450),
//                           curve: Curves.easeOut,
//                           child: Container(
//                             margin: const EdgeInsets.only(bottom: 12),
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color: Colors.white.withOpacity(0.08),
//                               ),
//                             ),
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 _buildChannelHeader(),
//                                 const SizedBox(height: 12),
//                                 if (widget.currentProgram != null)
//                                   _buildProgramProgress(),
//                                 const SizedBox(height: 12),
//                                 _buildControlsRow(),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildChannelHeader() {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // channel card
//         Container(
//           width: 112,
//           height: 112,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             gradient: const LinearGradient(
//               colors: [Color(0xFF4A90E2), Color(0xFF8E44AD)],
//             ),
//             border: Border.all(color: Colors.white.withOpacity(0.08)),
//           ),
//           // ignore: unnecessary_null_comparison
//           child:
//               // ignore: unnecessary_null_comparison
//               widget.channel.logoUrl != null
//                   ? ClipRRect(
//                     borderRadius: BorderRadius.circular(16),
//                     child: Image.network(
//                       widget.channel.logoUrl,
//                       fit: BoxFit.cover,
//                     ),
//                   )
//                   : Center(
//                     child: Text(
//                       widget.channel.channelNumber.toString(),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//         ),
//         const SizedBox(width: 18),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       widget.channel.name,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 28,
//                         fontWeight: FontWeight.w900,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: Colors.blue.withOpacity(0.12)),
//                     ),
//                     child: Text(
//                       'CH ${widget.channel.channelNumber}',
//                       style: const TextStyle(
//                         color: Color(0xFFBEE3FF),
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.06),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       widget.channel.quality,
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 widget.channel.language,
//                 style: const TextStyle(color: Colors.white70),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   if (widget.currentProgram != null)
//                     Expanded(child: _programCard(widget.currentProgram!, true)),
//                   const SizedBox(width: 12),
//                   if (widget.nextProgram != null)
//                     Expanded(child: _programCard(widget.nextProgram!, false)),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _programCard(EPGProgram program, bool isNow) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         gradient: LinearGradient(
//           colors: [
//             isNow
//                 ? Colors.blue.withOpacity(0.08)
//                 : Colors.purple.withOpacity(0.08),
//             isNow
//                 ? Colors.blue.withOpacity(0.02)
//                 : Colors.purple.withOpacity(0.02),
//           ],
//         ),
//         border: Border.all(color: Colors.white.withOpacity(0.06)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             isNow ? 'NOW PLAYING' : 'UP NEXT',
//             style: TextStyle(
//               color: isNow ? Colors.blue.shade300 : Colors.purple.shade300,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             program.title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Row(
//             children: [
//               Text(
//                 formatProgramTime(program.startTime),
//                 style: const TextStyle(color: Colors.white54, fontSize: 12),
//               ),
//               const SizedBox(width: 8),
//               const Text('•', style: TextStyle(color: Colors.white24)),
//               const SizedBox(width: 8),
//               Text(
//                 '${getDurationMinutes(program.startTime, program.endTime)} min',
//                 style: const TextStyle(color: Colors.white54, fontSize: 12),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildProgramProgress() {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'Program Progress',
//               style: TextStyle(color: Colors.white.withOpacity(0.6)),
//             ),
//             Text(
//               '${programProgress.round()}%',
//               style: TextStyle(color: Colors.white.withOpacity(0.6)),
//             ),
//           ],
//         ),
//         const SizedBox(height: 6),
//         ClipRRect(
//           borderRadius: BorderRadius.circular(999),
//           child: LinearProgressIndicator(
//             value: programProgress / 100.0,
//             minHeight: 8,
//             backgroundColor: Colors.white.withOpacity(0.06),
//             valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildControlsRow() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   isPlaying = !isPlaying;
//                   isPlaying
//                       ? _videoController.play()
//                       : _videoController.pause();
//                 });
//                 _startOverlayTimer();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue.shade600,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
//             ),
//             const SizedBox(width: 12),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.03),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   IconButton(
//                     onPressed: () {
//                       setState(() {
//                         isMuted = !isMuted;
//                         _videoController.setVolume(
//                           isMuted ? 0 : volume / 100.0,
//                         );
//                       });
//                       _startOverlayTimer();
//                     },
//                     icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
//                     color: Colors.white,
//                   ),
//                   SizedBox(
//                     width: 140,
//                     child: Slider(
//                       value: volume.toDouble(),
//                       min: 0,
//                       max: 100,
//                       onChanged: (v) {
//                         setState(() {
//                           volume = v.round();
//                           if (!isMuted)
//                             _videoController.setVolume(volume / 100.0);
//                         });
//                         _startOverlayTimer();
//                       },
//                     ),
//                   ),
//                   Text(
//                     '$volume%',
//                     style: const TextStyle(color: Colors.white70),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.03),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Row(
//             children: const [
//               Text('SPACE', style: TextStyle(color: Colors.white70)),
//               SizedBox(width: 6),
//               Icon(Icons.chevron_right, size: 14, color: Colors.white24),
//               SizedBox(width: 6),
//               Text('Play/Pause', style: TextStyle(color: Colors.white70)),
//               SizedBox(width: 12),
//               Text('M', style: TextStyle(color: Colors.white70)),
//               SizedBox(width: 6),
//               Icon(Icons.chevron_right, size: 14, color: Colors.white24),
//               SizedBox(width: 6),
//               Text('Mute', style: TextStyle(color: Colors.white70)),
//               SizedBox(width: 12),
//               Text('ESC', style: TextStyle(color: Colors.white70)),
//               SizedBox(width: 6),
//               Icon(Icons.chevron_right, size: 14, color: Colors.white24),
//               SizedBox(width: 6),
//               Text('Exit', style: TextStyle(color: Colors.white70)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   static String _weekdayShort(int weekday) {
//     const list = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     if (weekday >= 1 && weekday <= 7) return list[weekday - 1];
//     return '';
//   }

//   static String _monthShort(int month) {
//     const list = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     if (month >= 1 && month <= 12) return list[month - 1];
//     return '';
//   }
// }
