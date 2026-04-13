// lib/services/reminder_service.dart
//
// Scans accepted reservations on every app open and creates reminder
// notifications for BOTH the client AND the provider when a reservation
// is happening today or tomorrow.
//
// Duplicate prevention: each reminder has a unique key built from
// clientId + providerId + date + time + userType.
// If a notification with that key already exists in the DB we skip it,
// so re-opening the app never creates duplicate bells.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_services.dart';
import '../core/storage/user_session.dart';

const String _offerPrefix = 'OFFER_JSON:';

class ReminderService {
  /// Call this on every app open after the user is confirmed logged in.
  static Future<void> checkAndScheduleReminders() async {
    final session  = await UserSession.load();
    final userId   = session['id']   ?? 0;
    final userType = session['role'] ?? 'client';

    if (userId == 0) return;

    try {
      final conversations = await ApiService.getConversations(
          userId: userId, userType: userType);

      final now      = DateTime.now();
      final today    = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      for (final conv in conversations) {
        final bool   isClient    = userType == 'client';
        final int    partnerId   = isClient
            ? (conv['provider_id'] as int? ?? 0)
            : (conv['client_id']   as int? ?? 0);
        final String partnerName = isClient
            ? (conv['provider_name'] ?? '')
            : (conv['client_name']   ?? '');

        if (partnerId == 0) continue;

        final int clientId   = isClient ? userId   : partnerId;
        final int providerId = isClient ? partnerId : userId;

        // Determine names for both sides
        final String clientName   = isClient ? (session['full_name'] ?? '') : partnerName;
        final String providerName = isClient ? partnerName : (session['full_name'] ?? '');

        final messages = await ApiService.getConversation(
            clientId: clientId, providerId: providerId);

        // Track latest status per offer
        final Map<String, Map<String, dynamic>> latestOffers = {};
        for (final msg in messages) {
          final content = msg['content'] as String? ?? '';
          if (!content.startsWith(_offerPrefix)) continue;
          try {
            final offer = jsonDecode(content.substring(_offerPrefix.length))
                as Map<String, dynamic>;
            final key =
                '${offer['description']}|${offer['date']}|${offer['time']}';
            latestOffers[key] = offer;
          } catch (_) {}
        }

        for (final offer in latestOffers.values) {
          final status = offer['status'] as String? ?? '';
          if (status != 'accepted') continue;

          final reservationDate =
              _parseDate(offer['date'] as String? ?? '');
          if (reservationDate == null) continue;

          final resDay = DateTime(reservationDate.year,
              reservationDate.month, reservationDate.day);

          final isToday    = resDay.isAtSameMomentAs(today);
          final isTomorrow = resDay.isAtSameMomentAs(tomorrow);
          if (!isToday && !isTomorrow) continue;

          final desc    = offer['description'] as String? ?? 'Service';
          final date    = offer['date']        as String? ?? '';
          final time    = offer['time']        as String? ?? '';
          final address = offer['address']     as String? ?? '';
          final timeLabel = isToday ? 'today' : 'tomorrow';
          final emoji     = isToday ? '🔔' : '📅';

          // ── 1. Remind the CLIENT ──────────────────────────────
          await _sendReminderIfNeeded(
            userId:      clientId,
            userType:    'client',
            clientId:    clientId,
            providerId:  providerId,
            partnerName: providerName,
            desc:        desc,
            date:        date,
            time:        time,
            address:     address,
            text:        '$emoji Your reservation "$desc" is $timeLabel'
                         ' at $time'
                         '${address.isNotEmpty ? " — $address" : ""}',
          );

          // ── 2. Remind the PROVIDER ────────────────────────────
          await _sendReminderIfNeeded(
            userId:      providerId,
            userType:    'provider',
            clientId:    clientId,
            providerId:  providerId,
            partnerName: clientName,
            desc:        desc,
            date:        date,
            time:        time,
            address:     address,
            text:        '$emoji You have a job "$desc" $timeLabel'
                         ' at $time with $clientName'
                         '${address.isNotEmpty ? " — $address" : ""}',
          );
        }
      }
    } catch (e) {
      debugPrint('ReminderService error: $e');
    }
  }

  // ── Internal helper: check duplicate then send ──────────────────────────

  static Future<void> _sendReminderIfNeeded({
    required int    userId,
    required String userType,
    required int    clientId,
    required int    providerId,
    required String partnerName,
    required String desc,
    required String date,
    required String time,
    required String address,
    required String text,
  }) async {
    // Unique key per user per reservation — prevents duplicates
    final reminderKey =
        'reminder_${userType}_${clientId}_${providerId}_${date}_$time';

    final alreadySent = await ApiService.reminderAlreadySent(
        userId: userId, userType: userType, reminderKey: reminderKey);

    if (alreadySent) return;

    await ApiService.createReminderNotification(
      userId:      userId,
      userType:    userType,
      message:     text,
      reminderKey: reminderKey,
      clientId:    clientId,
      providerId:  providerId,
      partnerName: partnerName,
      date:        date,
      time:        time,
      description: desc,
    );
  }

  // ── Parse dd/MM/yyyy ────────────────────────────────────────────────────

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }
}