import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CallController } from './call.controller';
import { CallService } from './call.service';
import { Call } from './entities/call.entity';

/**
 * Модуль звонков для управления голосовыми и видеозвонками
 * 
 * Интегрирует:
 * - CallController - REST API endpoints
 * - CallService - бизнес-логика звонков
 * - Call entity - модель данных
 * 
 * В MVP версии поддерживаются только голосовые звонки.
 * WebRTC сигналинг планируется через CallGateway.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([Call])
  ],
  controllers: [CallController],
  providers: [CallService],
  exports: [CallService] // Экспортируем для использования в других модулях
})
export class CallModule {}
