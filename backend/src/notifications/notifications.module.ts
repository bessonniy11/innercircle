import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { NotificationsService } from './notifications.service';

/**
 * Модуль для управления Push-уведомлениями.
 * 
 * Предоставляет NotificationsService для использования в других частях приложения.
 * 
 * @since 2.2.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Module({
  imports: [ConfigModule], // ConfigModule необходим для доступа к переменным окружения
  providers: [NotificationsService],
  exports: [NotificationsService], // Экспортируем сервис, чтобы его можно было использовать в других модулях
})
export class NotificationsModule {}
