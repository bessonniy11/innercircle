// backend/src/call/call.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { JwtModule } from '@nestjs/jwt'; // НОВОЕ - импорт JwtModule
import { ConfigModule, ConfigService } from '@nestjs/config'; // НОВОЕ - для JWT_SECRET
import { CallController } from './call.controller';
import { CallService } from './call.service';
import { CallGateway } from './call.gateway';
import { Call } from './entities/call.entity';
import { WsJwtAuthGuard } from 'src/auth/guards/ws-jwt-auth.guard';

/**
 * Модуль звонков для управления голосовыми и видеозвонками
 * 
 * Интегрирует:
 * - CallController - REST API endpoints
 * - CallService - бизнес-логика звонков
 * - CallGateway - WebSocket для real-time сигналинга
 * - EventEmitter - система событий для loose coupling
 * - JwtModule - для аутентификации WebSocket
 * - Call entity - модель данных
 * 
 * В MVP версии поддерживаются только голосовые звонки.
 * WebRTC сигналинг работает через CallGateway.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([Call]),
    EventEmitterModule.forRoot(),
    JwtModule.registerAsync({ // НОВОЕ - асинхронная конфигурация JWT
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
        signOptions: { expiresIn: '24h' },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [CallController],
  providers: [CallService, CallGateway, WsJwtAuthGuard],
  exports: [CallService, CallGateway]
})
export class CallModule {}