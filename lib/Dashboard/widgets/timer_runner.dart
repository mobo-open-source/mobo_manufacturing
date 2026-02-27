import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/providers/motion_provider.dart';
import '../../globals.dart';
import 'package:provider/provider.dart';

import '../pages/dashboard_mo.dart';

/// A live running timer screen.
///
/// Features:
/// • Displays elapsed time in HH:mm:ss format
/// • Supports start, stop, and reset timer actions
/// • Uses circular UI timer display
/// • Supports reduced motion navigation transitions
/// • Provides quick navigation to Manufacturing Order dashboard
class RunningTimer extends StatefulWidget {
  const RunningTimer({super.key});

  @override
  State<RunningTimer> createState() => _RunningTimerState();
}

class _RunningTimerState extends State<RunningTimer> {
  /// Periodic timer used to update elapsed duration every second.
  late Timer _timer;

  /// Stores current elapsed time duration.
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Starts the timer and updates duration every second.
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = _duration + const Duration(seconds: 1);
      });
    });
  }

  /// Stops the timer.
  void _stopTimer() {
    _timer.cancel();
  }

  /// Formats duration into HH:mm:ss string format.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          /// Main timer UI.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),

                /// Circular timer display.
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: AppStyle.primaryColor.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                /// Timer action buttons.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// Stop timer button.
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: _stopTimer,
                      child: Text(
                        "Stop",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    /// Reset and restart timer button.
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        _stopTimer();
                        setState(() {
                          _duration = Duration.zero;
                        });
                        _startTimer();
                      },
                      child: Text(
                        "Pause",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// Navigation button to Manufacturing Order dashboard.
          Positioned(
            top: 8,
            right: 8,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const DashboardMoPage(),
                    transitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    reverseTransitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          if (motionProvider.reduceMotion) return child;
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: Text(
                'Goto MO',
                style: TextStyle(
                  color: AppStyle.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Disposes timer to prevent memory leaks.
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
