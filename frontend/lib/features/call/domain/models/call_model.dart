/// Модель звонка для WebRTC
class CallModel {
  final String id;
  final String callerId;
  final String callerUsername;
  final String receiverId;
  final String receiverUsername;
  final CallStatus status;
  final CallType type;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final Duration? duration;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerUsername,
    required this.receiverId,
    required this.receiverUsername,
    required this.status,
    required this.type,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.duration,
  });

  /// Создание модели из JSON
  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      callerUsername: json['callerUsername'] as String,
      receiverId: json['receiverId'] as String,
      receiverUsername: json['receiverUsername'] as String,
      status: CallStatus.values.firstWhere(
        (e) => e.toString() == 'CallStatus.${json['status']}',
        orElse: () => CallStatus.unknown,
      ),
      type: CallType.values.firstWhere(
        (e) => e.toString() == 'CallType.${json['type']}',
        orElse: () => CallType.voice,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      answeredAt: json['answeredAt'] != null 
          ? DateTime.parse(json['answeredAt'] as String) 
          : null,
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt'] as String) 
          : null,
      duration: json['duration'] != null 
          ? Duration(milliseconds: json['duration'] as int) 
          : null,
    );
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerUsername': callerUsername,
      'receiverId': receiverId,
      'receiverUsername': receiverUsername,
      'status': status.name,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'answeredAt': answeredAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': duration?.inMilliseconds,
    };
  }

  /// Копирование с изменениями
  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerUsername,
    String? receiverId,
    String? receiverUsername,
    CallStatus? status,
    CallType? type,
    DateTime? createdAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    Duration? duration,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerUsername: callerUsername ?? this.callerUsername,
      receiverId: receiverId ?? this.receiverId,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
    );
  }

  /// Проверка, является ли пользователь звонящим
  bool isCaller(String userId) => callerId == userId;

  /// Проверка, является ли пользователь принимающим
  bool isReceiver(String userId) => receiverId == userId;

  /// Получение имени собеседника для пользователя
  String getPeerUsername(String userId) {
    if (isCaller(userId)) {
      return receiverUsername;
    } else if (isReceiver(userId)) {
      return callerUsername;
    }
    return 'Неизвестный';
  }

  /// Проверка, активен ли звонок
  bool get isActive => status == CallStatus.ringing || 
                      status == CallStatus.answered;

  /// Проверка, завершен ли звонок
  bool get isEnded => status == CallStatus.ended || 
                     status == CallStatus.rejected || 
                     status == CallStatus.missed;

  @override
  String toString() {
    return 'CallModel(id: $id, caller: $callerUsername, receiver: $receiverUsername, status: $status, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Статусы звонка
enum CallStatus {
  /// Звонок создан, но еще не начался
  created,
  
  /// Звонок звонит (входящий)
  ringing,
  
  /// Звонок принят
  answered,
  
  /// Звонок отклонен
  rejected,
  
  /// Звонок пропущен
  missed,
  
  /// Звонок завершен
  ended,
  
  /// Неизвестный статус
  unknown,
}

/// Типы звонков
enum CallType {
  /// Голосовой звонок
  voice,
  
  /// Видеозвонок (планируется в будущем)
  video,
}

/// Расширения для CallStatus
extension CallStatusExtension on CallStatus {
  /// Получение человекочитаемого названия
  String get displayName {
    switch (this) {
      case CallStatus.created:
        return 'Создан';
      case CallStatus.ringing:
        return 'Звонит';
      case CallStatus.answered:
        return 'Отвечен';
      case CallStatus.rejected:
        return 'Отклонен';
      case CallStatus.missed:
        return 'Пропущен';
      case CallStatus.ended:
        return 'Завершен';
      case CallStatus.unknown:
        return 'Неизвестно';
    }
  }

  /// Получение цвета для UI
  String get color {
    switch (this) {
      case CallStatus.created:
      case CallStatus.ringing:
        return '#FF9800'; // Оранжевый
      case CallStatus.answered:
        return '#4CAF50'; // Зеленый
      case CallStatus.rejected:
      case CallStatus.missed:
        return '#F44336'; // Красный
      case CallStatus.ended:
        return '#9E9E9E'; // Серый
      case CallStatus.unknown:
        return '#607D8B'; // Сине-серый
    }
  }

  /// Проверка, можно ли принять звонок
  bool get canAnswer => this == CallStatus.ringing;

  /// Проверка, можно ли завершить звонок
  bool get canEnd => this == CallStatus.answered || this == CallStatus.ringing;

  /// Проверка, можно ли отклонить звонок
  bool get canReject => this == CallStatus.ringing;
}
