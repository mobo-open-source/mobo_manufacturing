import 'package:in_app_review/in_app_review.dart';
import 'package:mobo_manufacturing_app/Rating/rating_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../core/navigation/global_keys.dart';

/// A singleton service that manages in-app review requests and
/// user feedback flow.
///
/// This service:
/// - Tracks app opens and significant user events.
/// - Determines when to show a custom rating dialog based on:
///     • Minimum app opens
///     • Minimum significant events
///     • Minimum days since first launch
/// - Prevents repeated prompts within the same app session.
/// - Supports postponing review requests.
/// - Allows users to permanently disable review prompts.
/// - Falls back to opening the store listing if native review
///   dialog quotas prevent showing the in-app review.
/// - Sends email feedback for low ratings (1–3 stars).
///
/// Review Flow:
/// 1. App usage is tracked via [trackAppOpen] and [trackSignificantEvent].
/// 2. [checkAndShowRating] evaluates whether conditions are met.
/// 3. If eligible, a [CustomRatingDialog] is displayed.
/// 4. Based on rating:
///     • High rating (≥4): triggers native store review.
///     • Low rating (<4): sends feedback email and postpones review.
///
/// Persistent state is stored using SharedPreferences.
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();

  factory ReviewService() => _instance;

  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _keyOpenCount = 'review_open_count';
  static const String _keyEventCount = 'review_event_count';
  static const String _keyFirstOpenDate = 'review_first_open_date';
  static const String _keyNextAllowedDate = 'review_next_allowed_date';
  static const String _keyNeverAskAgain = 'review_never_ask_again';

  // Thresholds
  static const int _thresholdOpens = 5;
  static const int _thresholdEvents = 5;
  static const int _thresholdDays = 5;

  bool _wasRequestedThisRun = false;

  Future<void> trackAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. First Open Date
    if (!prefs.containsKey(_keyFirstOpenDate)) {
      await prefs.setInt(
        _keyFirstOpenDate,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    // 2. Increment Open Count
    int currentOpens = prefs.getInt(_keyOpenCount) ?? 0;
    currentOpens++;
    await prefs.setInt(_keyOpenCount, currentOpens);
  }

  Future<void> trackSignificantEvent() async {
    final prefs = await SharedPreferences.getInstance();

    // Increment Event Count
    int currentEvents = prefs.getInt(_keyEventCount) ?? 0;

    currentEvents++;
    await prefs.setInt(_keyEventCount, currentEvents);
  }

  Future<void> _checkAndRequestReview(
      SharedPreferences prefs, [
        BuildContext? context,
      ]) async {
    if (_wasRequestedThisRun) return;

    if (prefs.getBool(_keyNeverAskAgain) ?? false) {
      return;
    }

    // Check if we are past the next allowed date
    int? nextAllowedEpoch = prefs.getInt(_keyNextAllowedDate);
    if (nextAllowedEpoch != null) {
      final nextAllowedDate = DateTime.fromMillisecondsSinceEpoch(
        nextAllowedEpoch,
      );
      if (DateTime.now().isBefore(nextAllowedDate)) {
        return;
      }
    }

    if (await _inAppReview.isAvailable()) {
      bool shouldRequest = false;

      // Criteria 1: Nth usage (open)
      int openCount = prefs.getInt(_keyOpenCount) ?? 0;
      if (openCount >= _thresholdOpens) {
        shouldRequest = true;
      }

      // Criteria 2: Nth significant event
      int eventCount = prefs.getInt(_keyEventCount) ?? 0;
      if (eventCount >= _thresholdEvents) {
        shouldRequest = true;
      }

      // Criteria 3: N days usage
      int? firstOpenEpoch = prefs.getInt(_keyFirstOpenDate);
      if (firstOpenEpoch != null) {
        final firstOpenDate = DateTime.fromMillisecondsSinceEpoch(
          firstOpenEpoch,
        );
        final diff = DateTime.now().difference(firstOpenDate).inDays;
        if (diff >= _thresholdDays) {
          shouldRequest = true;
        }
      }

      if (shouldRequest) {
        if (context != null && context.mounted) {
          _wasRequestedThisRun = true;

          CustomRatingDialog.show(context);
        } else {
          // If no context, we just wait or skip for now to avoid showing dialog on transition screen
        }
      } else {}
    } else {}
  }

  /// Postpone the review dialog by a specific duration
  Future<void> postponeReview(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final nextAllowedDate = DateTime.now().add(duration);
    await prefs.setInt(
      _keyNextAllowedDate,
      nextAllowedDate.millisecondsSinceEpoch,
    );
  }

  /// Track app open and show dialog if criteria met
  Future<void> checkAndShowRating(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndRequestReview(prefs, context);
  }

  /// Force a review request. If the native dialog is suppressed by Google Play
  /// (due to quotas), it will fall back to opening the Store Listing directly.
  Future<void> forceRequestReview() async {
    // Update next allowed date to enforce cooldown period
    await postponeReview(const Duration(days: 30));

    // Show a small snackbar so the user knows the code is working
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Requesting Google Play review...'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue[700],
      ),
    );

    try {
      if (await _inAppReview.isAvailable()) {
        _wasRequestedThisRun = true;
        // Increase delay to 2.5 seconds to ensure stable activity transition
        await Future.delayed(const Duration(milliseconds: 2500));
        await _inAppReview.requestReview();
      } else {
        await openStoreListing();
      }
    } catch (e) {
      await openStoreListing();
    }
  }

  /// Opens the store listing directly. Use this as a fallback or for a "Rate Us" button.
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing();
    } catch (_) {}
  }

  /// Send email feedback for low ratings (1-3 stars)
  Future<void> sendEmailFeedback(double rating, String comment) async {
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'cybroplay@gmail.com', // Updated support email
        query: encodeQueryParameters(<String, String>{
          'subject':
          'Feedback for Odoo Mobile Community (${rating.toInt()} Stars)',
          'body':
          'Rating: ${rating.toInt()}/5\n\nComment:\n$comment\n\n---\nSent from Odoo Mobile Community',
        }),
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {}
    } catch (e) {}
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (MapEntry<String, String> e) =>
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
    )
        .join('&');
  }

  /// Permanently disable future review requests
  Future<void> neverAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNeverAskAgain, true);
  }

  /// Debug method to print current review tracking statistics
  Future<void> printReviewStats() async {
    final prefs = await SharedPreferences.getInstance();

    int openCount = prefs.getInt(_keyOpenCount) ?? 0;
    int eventCount = prefs.getInt(_keyEventCount) ?? 0;
    int? firstOpenEpoch = prefs.getInt(_keyFirstOpenDate);
    int? nextAllowedEpoch = prefs.getInt(_keyNextAllowedDate);
    if (firstOpenEpoch != null) {
      final firstOpenDate = DateTime.fromMillisecondsSinceEpoch(firstOpenEpoch);
      final daysSinceFirst = DateTime.now().difference(firstOpenDate).inDays;
    } else {}

    if (nextAllowedEpoch != null) {
      final nextAllowedDate = DateTime.fromMillisecondsSinceEpoch(
        nextAllowedEpoch,
      );
    } else {}
  }

  /// Reset all review tracking data (useful for testing)
  Future<void> resetReviewTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpenCount);
    await prefs.remove(_keyEventCount);
    await prefs.remove(_keyFirstOpenDate);
    await prefs.remove(_keyNextAllowedDate);
    await prefs.remove(_keyNeverAskAgain);
  }
}
