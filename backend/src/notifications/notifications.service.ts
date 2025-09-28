import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { ConfigService } from '@nestjs/config';
import * as path from 'path';

/**
 * Сервис для управления Push-уведомлениями через Firebase Cloud Messaging (FCM)
 *
 * Отвечает за:
 * - Инициализацию Firebase Admin SDK при старте приложения.
 * - Отправку push-уведомлений на конкретные устройства по их FCM токенам.
 *
 * @since 2.2.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly configService: ConfigService) {}

  /**
   * Инициализирует Firebase Admin SDK при запуске модуля.
   * Использует сервисный ключ, путь к которому определяется относительно корня проекта.
   */
  onModuleInit() {
    try {
      const serviceAccountPath = path.join(
        process.cwd(),
        'firebase-service-account.json',
      );

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccountPath),
      });

      this.logger.log('Firebase Admin SDK initialized successfully.');
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK:', error.message);
    }
  }

  /**
   * Отправляет push-уведомление на одно устройство.
   *
   * @param token - FCM токен целевого устройства.
   * @param title - Заголовок уведомления.
   * @param body - Тело уведомления.
   * @param data - Дополнительные данные, которые будут переданы в уведомлении.
   */
  async sendPushNotification(
    token: string,
    title: string,
    body: string,
    data: { [key: string]: string },
  ) {
    if (!admin.apps.length) {
      this.logger.error('Firebase Admin SDK not initialized. Cannot send notification.');
      return;
    }
    
    if (!token) {
      this.logger.warn('Attempted to send notification to a user without an FCM token.');
      return;
    }

    const message: admin.messaging.Message = {
      token,
      notification: {
        title,
        body,
      },
      data,
      // Настройки для Android для обеспечения высокого приоритета доставки
      android: {
        priority: 'high',
      },
      // Настройки для iOS, критически важные для работы CallKit
      apns: {
        payload: {
          aps: {
            'content-available': 1, // "Разбудить" приложение
            sound: 'default', // Стандартный звук уведомления
          },
        },
        headers: {
            'apns-push-type': 'voip', // Указывает, что это VoIP звонок для CallKit
            'apns-priority': '10', // Максимальный приоритет
        }
      },
    };

    try {
      const response = await admin.messaging().send(message);
      this.logger.log(`Successfully sent message to token ${token}: ${response}`);
    } catch (error) {
      this.logger.error(`Error sending message to token ${token}:`, error);
    }
  }
}
