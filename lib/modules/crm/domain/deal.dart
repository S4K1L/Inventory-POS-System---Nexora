import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Pipeline stages a deal moves through.
enum DealStage {
  lead('lead', 'Lead'),
  contacted('contacted', 'Contacted'),
  proposal('proposal', 'Proposal'),
  won('won', 'Won'),
  lost('lost', 'Lost');

  const DealStage(this.id, this.label);
  final String id;
  final String label;

  static DealStage fromId(String? id) =>
      DealStage.values.firstWhere((s) => s.id == id, orElse: () => DealStage.lead);

  bool get isOpen => this != DealStage.won && this != DealStage.lost;

  Color get color => switch (this) {
        DealStage.lead => AppColors.brandLight,
        DealStage.contacted => AppColors.accent,
        DealStage.proposal => AppColors.warning,
        DealStage.won => AppColors.success,
        DealStage.lost => AppColors.danger,
      };
}

/// A sales opportunity. Stored at `companies/{cid}/deals/{id}` (company-wide).
class Deal {
  const Deal({
    required this.id,
    required this.title,
    required this.stage,
    this.contactName = '',
    this.phone = '',
    this.value = 0,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String title;
  final DealStage stage;
  final String contactName;
  final String phone;
  final num value;
  final String note;
  final DateTime createdAt;

  Deal copyWith({
    String? title,
    DealStage? stage,
    String? contactName,
    String? phone,
    num? value,
    String? note,
  }) {
    return Deal(
      id: id,
      title: title ?? this.title,
      stage: stage ?? this.stage,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      value: value ?? this.value,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'stage': stage.id,
        'contactName': contactName,
        'phone': phone,
        'value': value,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Deal.fromMap(String id, Map<String, dynamic> data) {
    return Deal(
      id: id,
      title: (data['title'] ?? '') as String,
      stage: DealStage.fromId(data['stage'] as String?),
      contactName: (data['contactName'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      value: (data['value'] ?? 0) as num,
      note: (data['note'] ?? '') as String,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}
