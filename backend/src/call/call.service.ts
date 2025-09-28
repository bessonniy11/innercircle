// backend/src/call/call.service.ts
import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ConfigService } from '@nestjs/config'; // НОВЫЙ ИМПОРТ
import * as crypto from 'crypto'; // НОВЫЙ ИМПОРТ
import { Call, CallStatus, CallType } from './entities/call.entity';
import { InitiateCallDto } from './dto/initiate-call.dto';
import { CallResponseDto } from './dto/call-response.dto';
import { NotificationsService } from 'src/notifications/notifications.service';
import { UsersService } from 'src/users/users.service';
import { Logger } from '@nestjs/common'; // НОВЫЙ ИМПОРТ

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
  // Конфигурация WebRTC STUN серверов
  private readonly webrtcConfig = {
    iceServers: [
      { urls: 'stun:5.8.76.33:3478' }, // НАШ STUN сервер (приоритетный)
      { urls: 'stun:stun.l.google.com:19302' }, // Fallback Google STUN
      { urls: 'stun:stun1.l.google.com:19302' }, // Fallback Google STUN
    ],
  };

  private readonly logger = new Logger(CallService.name); // НОВЫЙ ЛОГЕР

  constructor(
    @InjectRepository(Call)
    private readonly callRepository: Repository<Call>,
    private readonly eventEmitter: EventEmitter2, // НОВОЕ - Event Emitter вместо CallGateway
    private readonly configService: ConfigService, // НОВЫЙ СЕРВИС
    private readonly notificationsService: NotificationsService,
    private readonly usersService: UsersService,
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

    // Получаем данные о звонящем и получателе
    const [caller, receiver] = await Promise.all([
      this.usersService.findOne(callerId),
      this.usersService.findOne(targetUserId),
    ]);

    if (!caller || !receiver) {
      throw new NotFoundException('Один из пользователей не найден');
    }

    // Создаем новый звонок
    const newCall = this.callRepository.create({
      caller,
      receiver,
      type, // ИСПРАВЛЕНИЕ: Используем 'type' вместо 'callType'
      status: CallStatus.INITIATING, // ИСПРАВЛЕНИЕ: Используем enum вместо строки 'pending'
    });

    // 1. СНАЧАЛА сохраняем звонок, чтобы получить сгенерированный ID
    const savedCall = await this.callRepository.save(newCall);

    // 2. ТЕПЕРЬ отправляем Push-уведомление с реальным ID
    if (receiver.fcmToken) {
      this.logger.log(
        `Найден FCM токен для получателя ${targetUserId}. Попытка отправить Push-уведомление для звонка ${savedCall.id}.`,
      );
      const callerName = caller.username;

      // Мы не будем здесь использовать await, чтобы не блокировать основной поток ответа.
      // Отправка уведомления может происходить в фоновом режиме.
      this.notificationsService
        .sendPushNotification(
          receiver.fcmToken,
          'Входящий звонок',
          `Вам звонит ${callerName}`,
          {
            callId: savedCall.id, // Используем ID из сохраненной сущности
            callerName,
            callType: savedCall.type,
            'remoteUserId': caller.id, // НОВОЕ ПОЛЕ
          },
        )
        .catch((error) => {
          this.logger.error(
            `Ошибка при отправке Push-уведомления для звонка ${savedCall.id}:`,
            error,
          );
        });
    } else {
      this.logger.warn(
        `FCM токен для получателя ${targetUserId} не найден. Push-уведомление не отправлено.`,
      );
    }

    // НОВОЕ: Отправляем событие через WebSocket для онлайн-пользователей (веб-версия)
    this.eventEmitter.emit('call.created', savedCall);

    return savedCall;
  }

  /**
   * НОВЫЙ МЕТОД: Сохраняет ICE кандидат для звонка.
   * Определяет, от звонящего или от получателя пришел кандидат,
   * и добавляет его в соответствующий массив в базе данных.
   * @param callId ID звонка
   * @param senderId ID пользователя, отправившего кандидат
   * @param candidate ICE кандидат
   */
  async saveIceCandidate(
    callId: string,
    senderId: string,
    candidate: any,
  ): Promise<void> {
    const call = await this.callRepository.findOne({ where: { id: callId } });

    if (!call) {
      this.logger.warn(
        `Попытка сохранить ICE кандидат для несуществующего звонка: ${callId}`,
      );
      return;
    }

    if (senderId === call.callerId) {
      const candidates = call.callerIceCandidates || [];
      candidates.push(candidate);
      await this.callRepository.update(
        { id: callId },
        { callerIceCandidates: candidates },
      );
    } else if (senderId === call.receiverId) {
      const candidates = call.receiverIceCandidates || [];
      candidates.push(candidate);
      await this.callRepository.update(
        { id: callId },
        { receiverIceCandidates: candidates },
      );
    } else {
      this.logger.warn(
        `Попытка сохранить ICE кандидат от пользователя ${senderId}, не являющегося участником звонка ${callId}`,
      );
    }
  }

  /**
   * НОВЫЙ МЕТОД: Сохраняет SDP Offer для звонка.
   * @param callId ID звонка
   * @param sdpOffer SDP Offer объект
   * @returns Promise<void>
   */
  async saveSdpOffer(callId: string, sdpOffer: any): Promise<void> {
    const result = await this.callRepository.update(
      { id: callId },
      { sdpOffer: sdpOffer },
    );

    if (result.affected === 0) {
      this.logger.warn(
        `Попытка сохранить SDP Offer для несуществующего звонка: ${callId}`,
      );
      // Мы не выбрасываем ошибку, чтобы не прерывать основной поток сигналинга
    }
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
    // this.eventEmitter.emit('call.status.changed', { call: updatedCall, status });
    
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
    let eventToEmit: string | null = null; // <-- Переменная для события

    if (action === 'accept') {
        newStatus = CallStatus.ANSWERED;
        eventToEmit = 'call.accepted'; // <-- Событие для принятия
    } else if (action === 'reject') {
        newStatus = CallStatus.REJECTED;
        eventToEmit = 'call.rejected'; // <-- Событие для отклонения
    } else {
        throw new BadRequestException('Неизвестное действие');
    }
    
    const updatedCall = await this.updateCallStatus(callId, newStatus, userId);

    // Явно эмитим событие после обновления статуса
    if (eventToEmit) {
      this.eventEmitter.emit(eventToEmit, updatedCall);
    }

    return updatedCall;
  }

  /**
   * НОВЫЙ МЕТОД: Обрабатывает публичный ответ на звонок (отклонение)
   */
  async handlePublicCallResponse(
    callResponseDto: CallResponseDto,
  ): Promise<Call> {
    const { callId, action } = callResponseDto;

    // На публичном эндпоинте разрешаем только отклонение
    if (action !== 'reject') {
      throw new BadRequestException(
        'Для данного эндпоинта доступно только действие "reject"',
      );
    }

    const call = await this.callRepository.findOne({
      where: { id: callId },
      relations: ['caller', 'receiver'],
    });

    if (!call) {
      throw new NotFoundException('Звонок не найден');
    }

    // Проверяем, что звонок все еще ожидает ответа, чтобы избежать повторной обработки
    if (
      ![CallStatus.RINGING, CallStatus.INITIATING].includes(call.status)
    ) {
      this.logger.warn(
        `Попытка публичного отклонения уже обработанного звонка ${callId} со статусом ${call.status}. Действие проигнорировано.`,
      );
      return call;
    }

    // Для updateCallStatus нам нужен ID пользователя, который совершает действие.
    // В данном случае это всегда получатель звонка.
    const receiverId = call.receiverId;
    const updatedCall = await this.updateCallStatus(
      callId,
      CallStatus.REJECTED,
      receiverId,
    );

    // Эмитим событие, чтобы CallGateway уведомил звонящего
    this.eventEmitter.emit('call.rejected', updatedCall);
    this.logger.log(`Сгенерировано событие call.rejected для звонка ${callId}`);

    return updatedCall;
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

  /**
   * НОВОЕ: Получает конфигурацию WebRTC для клиентов
   * 
   * Генерирует временные учетные данные для TURN сервера.
   * 
   * @returns WebRTC конфигурация с STUN и TURN серверами
   * @since 2.1.0
   * @author ИИ-Ассистент + Bessonniy
   */
  getWebRTCConfig() {
    const turnUrl = this.configService.get<string>('TURN_URL');
    const turnSecret = this.configService.get<string>('TURN_SECRET');

    if (!turnUrl || !turnSecret) {
      // Если TURN не настроен, возвращаем только STUN
      return {
        iceServers: [
          { urls: `stun:${turnUrl}` },
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun1.l.google.com:19302' },
        ],
      };
    }

    // Генерация временных учетных данных для TURN
    const expiry = Math.floor(Date.now() / 1000) + 3600; // Срок действия - 1 час
    const username = `${expiry}:${Math.random().toString(36).substring(7)}`;
    
    const hmac = crypto.createHmac('sha1', turnSecret);
    hmac.update(username);
    const credential = hmac.digest('base64');

    return {
      iceServers: [
        { urls: `stun:${turnUrl}` },
        {
          urls: `turn:${turnUrl}`,
          username,
          credential,
        },
        // Fallback STUN серверы
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ],
    };
  }
}