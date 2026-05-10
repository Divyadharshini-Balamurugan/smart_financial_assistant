import 'package:cloud_firestore/cloud_firestore.dart';

class Tip {
  final String tipId;
  final String category;
  final String reason;
  final String message;
  final String templateId;
  final String? expenseId;
  final String severity; // 'low'|'medium'|'high'
  final DateTime createdAt;
  final bool active;
  final String? supersededBy;
  final int repeatCount;
  final DateTime? cooldownUntil;

  Tip({
    required this.tipId,
    required this.category,
    required this.reason,
    required this.message,
    required this.templateId,
    this.expenseId,
    required this.severity,
    required this.createdAt,
    required this.active,
    this.supersededBy,
    required this.repeatCount,
    this.cooldownUntil,
  });

  Map<String, dynamic> toMap() => {
        'tipId': tipId,
        'category': category,
        'reason': reason,
        'message': message,
        'templateId': templateId,
        'expenseId': expenseId,
        'severity': severity,
        'createdAt': createdAt.toUtc(),
        'active': active,
        'supersededBy': supersededBy,
        'repeatCount': repeatCount,
        'cooldownUntil': cooldownUntil?.toUtc(),
      };

  factory Tip.fromMap(Map<String, dynamic> m) => Tip(
        tipId: m['tipId'],
        category: m['category'],
        reason: m['reason'],
        message: m['message'],
        templateId: m['templateId'],
        expenseId: m['expenseId'],
        severity: m['severity'] ?? 'medium',
        createdAt: (m['createdAt'] as Timestamp).toDate(),
        active: m['active'] ?? true,
        supersededBy: m['supersededBy'],
        repeatCount: m['repeatCount'] ?? 1,
        cooldownUntil: m['cooldownUntil'] != null
            ? (m['cooldownUntil'] as Timestamp).toDate()
            : null,
      );
}
