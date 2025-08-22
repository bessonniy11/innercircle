import 'package:flutter/material.dart';

/**
 * Модель для публичного представления пользователя.
 *
 * Используется для передачи данных пользователя в UI, исключая конфиденциальную информацию.
 * Обеспечивает строгую типизацию и удобное парсинг из JSON.
 *
 * @author ИИ-Ассистент + Bessonniy
 * @since 1.0.0
 */
class UserPublicDto {
  final String id;
  final String username;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPublicDto({
    required this.id,
    required this.username,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPublicDto.fromJson(Map<String, dynamic> json) {
    return UserPublicDto(
      id: json['id'] as String,
      username: json['username'] as String,
      isAdmin: json['isAdmin'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
