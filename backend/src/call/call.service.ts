// backend/src/call/call.service.ts
import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Call, CallStatus, CallType } from './entities/call.entity';
import { InitiateCallDto } from './dto/initiate-call.dto';
import { CallResponseDto } from './dto/call-response.dto';

/**
 * Сервис для управления голосовыми и видеозвонками
 * 
 * Обеспечивает бизнес-логику для:
 * - Инициации звонков
 * - Управления статусами звонков
 * - Получения истории звонков
 * - Валидации прав доступа
 * - Эмиссии событий для WebSocket уведомлений
 * 
 * В MVP версии поддерживаются только голосовые звонки.
 * WebRTC сигналинг происходит через CallGateway.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Injectable()
export class CallService {
  constructor(
    @InjectRepository(Call)
    private readonly callRepository: Repository<Call>,
    private readonly eventEmitter: EventEmitter2 // НОВОЕ - Event Emitter вместо CallGateway
  ) {}

  /**
   * Создает новый звонок в системе
   * 
   * @param initiateCallDto - Данные для инициации звонка
   * @param callerId - ID пользователя, который звонит
   * @returns Promise<Call> - Созданный звонок
   * @throws {BadRequestException} - Если попытка позвонить самому себе
   * @throws {NotFoundException} - Если целевой пользователь не найден
   * 
   * @example
   * ```typescript
   * const call = await callService.createCall(
   *   { targetUserId: 'user-uuid', type: CallType.VOICE },
   *   'caller-uuid'
   * );
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async createCall(initiateCallDto: InitiateCallDto, callerId: string): Promise<Call> {
    const { targetUserId, type = CallType.VOICE } = initiateCallDto;

    // Проверяем, что пользователь не звонит самому себе
    if (callerId === targetUserId) {
      throw new BadRequestException('Нельзя позвонить самому себе');
    }

    // Создаем новый звонок
    const call = this.callRepository.create({
      callerId,
      receiverId: targetUserId,
      status: CallStatus.INITIATING,
      type,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const savedCall = await this.callRepository.save(call);

    // НОВОЕ: Сразу переводим в статус RINGING
    const ringingCall = await this.updateCallStatus(savedCall.id, CallStatus.RINGING, callerId);
    
    // НОВОЕ: Эмитим событие вместо прямого вызова Gateway
    this.eventEmitter.emit('call.created', ringingCall);
    
    return ringingCall; // Возвращаем звонок в статусе RINGING
  }

  /**
   * Обновляет статус звонка
   * 
   * @param callId - ID звонка
   * @param status - Новый статус
   * @param userId - ID пользователя, который изменяет статус
   * @returns Promise<Call> - Обновленный звонок
   * @throws {NotFoundException} - Если звонок не найден
   * @throws {ForbiddenException} - Если пользователь не участник звонка
   * 
   * @example
   * ```typescript
   * const call = await callService.updateCallStatus(
   *   'call-uuid',
   *   CallStatus.RINGING,
   *   'user-uuid'
   * );
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async updateCallStatus(callId: string, status: CallStatus, userId: string): Promise<Call> {
    const call = await this.callRepository.findOne({
      where: { id: callId },
      relations: ['caller', 'receiver'],
    });

    if (!call) {
      throw new NotFoundException('Звонок не найден');
    }

    // Проверяем, что пользователь является участником звонка
    if (call.callerId !== userId && call.receiverId !== userId) {
      throw new ForbiddenException('Нет доступа к этому звонку');
    }

    // Обновляем статус и время
    call.status = status;
    call.updatedAt = new Date();

    // Устанавливаем время начала/окончания в зависимости от статуса
    if (status === CallStatus.ANSWERED && !call.startedAt) {
      call.startedAt = new Date();
    } else if ([CallStatus.ENDED, CallStatus.MISSED, CallStatus.REJECTED].includes(status)) {
      call.endedAt = new Date();
      if (call.startedAt) {
        call.duration = Math.floor((call.endedAt.getTime() - call.startedAt.getTime()) / 1000);
      }
    }

    const updatedCall = await this.callRepository.save(call);
    
    // НОВОЕ: Эмитим событие об изменении статуса
    this.eventEmitter.emit('call.status.changed', { call: updatedCall, status });
    
    return updatedCall;
  }

  /**
   * Получает звонок по ID с проверкой прав доступа
   * 
   * @param callId - ID звонка
   * @param userId - ID пользователя для проверки доступа
   * @returns Promise<Call> - Звонок с relations
   * @throws {NotFoundException} - Если звонок не найден
   * @throws {ForbiddenException} - Если пользователь не участник звонка
   * 
   * @example
   * ```typescript
   * const call = await callService.getCallById('call-uuid', 'user-uuid');
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async getCallById(callId: string, userId: string): Promise<Call> {
    const call = await this.callRepository.findOne({
      where: { id: callId },
      relations: ['caller', 'receiver'],
    });

    if (!call) {
      throw new NotFoundException('Звонок не найден');
    }

    // Проверяем, что пользователь является участником звонка
    if (call.callerId !== userId && call.receiverId !== userId) {
      throw new ForbiddenException('Нет доступа к этому звонку');
    }

    return call;
  }

  /**
   * Получает историю звонков пользователя
   * 
   * @param userId - ID пользователя
   * @param limit - Лимит записей (по умолчанию 50)
   * @param offset - Смещение для пагинации (по умолчанию 0)
   * @returns Promise<Call[]> - Список звонков пользователя
   * 
   * @example
   * ```typescript
   * const calls = await callService.getUserCallHistory('user-uuid', 20, 0);
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async getUserCallHistory(userId: string, limit: number = 50, offset: number = 0): Promise<Call[]> {
    return await this.callRepository.find({
      where: [
        { callerId: userId },
        { receiverId: userId }
      ],
      relations: ['caller', 'receiver'],
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  /**
   * Обрабатывает ответ на звонок (принять/отклонить)
   * 
   * @param callResponseDto - DTO с ответом на звонок
   * @param userId - ID пользователя, который отвечает
   * @returns Promise<Call> - Обновленный звонок
   * @throws {NotFoundException} - Если звонок не найден
   * @throws {ForbiddenException} - Если пользователь не получатель звонка
   * 
   * @example
   * ```typescript
   * const call = await callService.handleCallResponse(
   *   { callId: 'call-uuid', action: 'accept' },
   *   'receiver-uuid'
   * );
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async handleCallResponse(callResponseDto: CallResponseDto, userId: string): Promise<Call> {
    const { callId, action } = callResponseDto;
    
    const call = await this.getCallById(callId, userId);

    // Проверяем, что пользователь является получателем звонка
    if (call.receiverId !== userId) {
        throw new ForbiddenException('Только получатель может отвечать на звонок');
    }

    // ИСПРАВЛЯЕМ: Проверяем статус RINGING или INITIATING
    if (![CallStatus.RINGING, CallStatus.INITIATING].includes(call.status)) {
        throw new BadRequestException(`Звонок не в статусе ожидания ответа. Текущий статус: ${call.status}`);
    }

    // Обновляем статус в зависимости от действия
    let newStatus: CallStatus;
    if (action === 'accept') {
        newStatus = CallStatus.ANSWERED;
    } else if (action === 'reject') {
        newStatus = CallStatus.REJECTED;
    } else {
        throw new BadRequestException('Неизвестное действие');
    }
    
    return await this.updateCallStatus(callId, newStatus, userId);
  }

  /**
   * Завершает активный звонок
   * 
   * @param callId - ID звонка
   * @param userId - ID пользователя, который завершает
   * @returns Promise<Call> - Завершенный звонок
   * @throws {NotFoundException} - Если звонок не найден
   * @throws {ForbiddenException} - Если пользователь не участник звонка
   * 
   * @example
   * ```typescript
   * const call = await callService.endCall('call-uuid', 'user-uuid');
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async endCall(callId: string, userId: string): Promise<Call> {
    const call = await this.getCallById(callId, userId);
    
    // ИСПРАВЛЯЕМ: Разрешаем завершать звонки в разных статусах
    if (![CallStatus.INITIATING, CallStatus.RINGING, CallStatus.ANSWERED].includes(call.status)) {
      throw new BadRequestException('Звонок уже завершен или не может быть завершен');
    }
    
    // Обновляем статус и время завершения
    call.status = CallStatus.ENDED;
    call.endedAt = new Date();
    
    // Вычисляем длительность если звонок был активен
    if (call.startedAt) {
      call.duration = Math.floor((call.endedAt.getTime() - call.startedAt.getTime()) / 1000);
    }
    
    const endedCall = await this.callRepository.save(call);
    
    // НОВОЕ: Эмитим событие о завершении звонка
    this.eventEmitter.emit('call.ended', endedCall);
    
    return endedCall;
  }

  /**
   * Получает активные звонки пользователя
   * 
   * @param userId - ID пользователя
   * @returns Promise<Call[]> - Список активных звонков
   * 
   * @example
   * ```typescript
   * const activeCalls = await callService.getActiveCalls('user-uuid');
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async getActiveCalls(userId: string): Promise<Call[]> {
    return await this.callRepository.find({
      where: [
        { callerId: userId, status: CallStatus.ANSWERED },
        { receiverId: userId, status: CallStatus.ANSWERED }
      ],
      relations: ['caller', 'receiver'],
    });
  }

  /**
   * НОВОЕ: Изменяет статус звонка на RINGING (для WebSocket уведомлений)
   * 
   * @param callId - ID звонка
   * @param userId - ID пользователя, который изменяет статус
   * @returns Promise<Call> - Обновленный звонок
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async setCallRinging(callId: string, userId: string): Promise<Call> {
    return await this.updateCallStatus(callId, CallStatus.RINGING, userId);
  }

  /**
   * НОВОЕ: Принимает звонок (изменяет статус на ANSWERED)
   * 
   * @param callId - ID звонка
   * @param userId - ID пользователя, который принимает
   * @returns Promise<Call> - Обновленный звонок
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async acceptCall(callId: string, userId: string): Promise<Call> {
    return await this.updateCallStatus(callId, CallStatus.ANSWERED, userId);
  }

  /**
   * НОВОЕ: Отклоняет звонок (изменяет статус на REJECTED)
   * 
   * @param callId - ID звонка
   * @param userId - ID пользователя, который отклоняет
   * @returns Promise<Call> - Обновленный звонок
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async rejectCall(callId: string, userId: string): Promise<Call> {
    return await this.updateCallStatus(callId, CallStatus.REJECTED, userId);
  }
}