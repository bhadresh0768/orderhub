import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'order.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.issueType,
    required this.priority,
    required this.status,
    required this.description,
    this.orderId,
    this.attachments = const [],
    this.adminNote,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final UserRole userRole;
  final SupportIssueType issueType;
  final SupportPriority priority;
  final SupportTicketStatus status;
  final String description;
  final String? orderId;
  final List<OrderAttachment> attachments;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': enumToString(userRole),
      'issueType': enumToString(issueType),
      'priority': enumToString(priority),
      'status': enumToString(status),
      'description': description,
      'orderId': orderId,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'adminNote': adminNote,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
      'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
    };
  }

  factory SupportTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Support ticket document is empty');
    }
    final attachmentsData = (data['attachments'] as List?) ?? [];
    return SupportTicket(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      userRole: enumFromString(
        UserRole.values,
        data['userRole'] as String?,
        UserRole.customer,
      ),
      issueType: enumFromString(
        SupportIssueType.values,
        data['issueType'] as String?,
        SupportIssueType.other,
      ),
      priority: enumFromString(
        SupportPriority.values,
        data['priority'] as String?,
        SupportPriority.medium,
      ),
      status: enumFromString(
        SupportTicketStatus.values,
        data['status'] as String?,
        SupportTicketStatus.open,
      ),
      description: (data['description'] as String?) ?? '',
      orderId: data['orderId'] as String?,
      attachments: attachmentsData
          .whereType<Map>()
          .map(
            (entry) =>
                OrderAttachment.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(),
      adminNote: data['adminNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
