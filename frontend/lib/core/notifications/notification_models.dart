import 'package:flutter/material.dart';

import '../design/korai_tokens.dart';

/// Types de notifications (alignés avec l'enum backend + types locaux de sync).
enum NotificationType {
  expertiseRequested('EXPERTISE_REQUESTED'),
  expertiseAssigned('EXPERTISE_ASSIGNED'),
  expertiseCompleted('EXPERTISE_COMPLETED'),
  patientValidated('PATIENT_VALIDATED'),
  nurseRegistrationRequest('NURSE_REGISTRATION_REQUEST'),
  // Types purement locaux (générés côté app, jamais envoyés par le serveur).
  syncCompleted('SYNC_COMPLETED'),
  syncFailed('SYNC_FAILED'),
  unknown('UNKNOWN');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromValue(String? raw) {
    for (final t in NotificationType.values) {
      if (t.value == raw) return t;
    }
    return NotificationType.unknown;
  }

  IconData get icon => switch (this) {
        NotificationType.expertiseRequested => Icons.assignment_outlined,
        NotificationType.expertiseAssigned => Icons.how_to_reg_outlined,
        NotificationType.expertiseCompleted => Icons.verified_user_outlined,
        NotificationType.patientValidated => Icons.check_circle_outline,
        NotificationType.nurseRegistrationRequest => Icons.person_add_alt_1_outlined,
        NotificationType.syncCompleted => Icons.cloud_done_outlined,
        NotificationType.syncFailed => Icons.sync_problem_outlined,
        NotificationType.unknown => Icons.notifications_none,
      };

  /// Tonalité sémantique (couleurs issues des jetons Korai).
  KTone get tone => switch (this) {
        NotificationType.expertiseRequested => KTone.brand,
        NotificationType.expertiseAssigned => KTone.info,
        NotificationType.expertiseCompleted => KTone.success,
        NotificationType.patientValidated => KTone.success,
        NotificationType.nurseRegistrationRequest => KTone.warning,
        NotificationType.syncCompleted => KTone.success,
        NotificationType.syncFailed => KTone.danger,
        NotificationType.unknown => KTone.neutral,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.isLocal,
    required this.createdAt,
    this.consultationId,
    this.patientId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final bool isLocal;
  final DateTime createdAt;
  final String? consultationId;
  final String? patientId;

  factory AppNotification.fromApi(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: NotificationType.fromValue(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isRead: json['isRead'] == true,
      isLocal: false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      consultationId: json['consultationId']?.toString(),
      patientId: json['patientId']?.toString(),
    );
  }

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'].toString(),
      type: NotificationType.fromValue(row['type']?.toString()),
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      isRead: row['is_read'] == 1,
      isLocal: row['is_local'] == 1,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      consultationId: row['consultation_id']?.toString(),
      patientId: row['patient_id']?.toString(),
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'type': type.value,
        'title': title,
        'body': body,
        'consultation_id': consultationId,
        'patient_id': patientId,
        'is_read': isRead ? 1 : 0,
        'is_local': isLocal ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
