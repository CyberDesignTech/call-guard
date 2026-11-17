import 'package:flutter/material.dart';

class ListEntry {
  const ListEntry({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.titleKey,
    this.badgeKey,
    this.id,
    this.listType = 'white',
    this.expiresAt,
    required this.icon,
    required this.tint,
    required this.pale,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String? titleKey;
  final String? badgeKey;
  final int? id;
  final String listType;
  final int? expiresAt;
  final IconData icon;
  final Color tint;
  final Color pale;
}
