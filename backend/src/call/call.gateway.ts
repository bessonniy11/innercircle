// backend/src/call/call.gateway.ts
import { 
    WebSocketGateway, 
    WebSocketServer, 
    SubscribeMessage, 
    MessageBody, 
    ConnectedSocket,
    OnGatewayConnection,
    OnGatewayDisconnect
  } from '@nestjs/websockets';
  import { Server, Socket } from 'socket.io';
  import { UseGuards, Logger, Injectable, OnModuleInit } from '@nestjs/common'; // ИСПРАВЛЕНО - OnModuleInit из common
  import { EventEmitter2 } from '@nestjs/event-emitter'; // ИСПРАВЛЕНО - правильный импорт
  import { WsJwtAuthGuard } from '../auth/guards/ws-jwt-auth.guard';
  import { Call, CallStatus } from './entities/call.entity';
import { CallService } from './call.service';
import { JwtService } from '@nestjs/jwt';
  
  /**
   * WebSocket Gateway для управления звонками в реальном времени
   * 
   * Обеспечивает:
   * - Real-time уведомления о входящих звонках
   * - WebRTC сигналинг (SDP offer/answer, ICE candidates)
   * - Автоматическое обновление статусов звонков
   * - Синхронизацию состояния между участниками
   * 
   * В MVP версии поддерживаются только голосовые звонки.
   * 
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @WebSocketGateway({
    namespace: '/calls',
    cors: {
      origin: "*",
      methods: ["GET", "POST"]
    }
  })
  @UseGuards(WsJwtAuthGuard)
  @Injectable()
  export class CallGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit {
    @WebSocketServer()
    server: Server;
  
    private readonly logger = new Logger(CallGateway.name);
    private readonly userSockets = new Map<string, Socket>(); // userId -> Socket
    private readonly callParticipants = new Map<string, { callerId: string, receiverId: string }>();


    constructor(
        private readonly eventEmitter: EventEmitter2,
        private readonly jwtService: JwtService,
        private readonly callService: CallService
    ) {}
  
    /**
     * Инициализация модуля - подписка на события от CallService
     * 
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    onModuleInit() {
      // Подписываемся на события от CallService
      this.eventEmitter.on('call.created', (call: Call) => {
        this.notifyIncomingCall(call);
      });
  
      this.eventEmitter.on('call.status.changed', (data: { call: Call, status: CallStatus }) => {
        this.notifyCallStatusChange(data.call, data.status);
      });
  
      this.eventEmitter.on('call.ended', (call: Call) => {
        this.notifyCallStatusChange(call, CallStatus.ENDED);
      });
  
      this.logger.log('CallGateway подписан на события CallService');
    }
  
    /**
     * Обработка подключения пользователя к WebSocket
     * 
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    async handleConnection(client: Socket) {
        try {
            const token = client.handshake.auth.token;
            console.log('🔐 Токен получен:', token ? 'да' : 'нет');
            
            const decoded = this.jwtService.verify(token);
            console.log('🔐 JWT декодирован:', decoded);
            
            client.data.user = decoded;
            
            // Получаем пользователя из JWT токена
            const user = client.data.user;
            console.log('🔐 Пользователь из client.data.user:', user);
            console.log('🔐 user.id:', user?.id);
            console.log('🔐 user.sub:', user?.sub);
            
            if (user && (user.id || user.sub)) {
                const userId = user.id || user.sub;
                this.userSockets.set(userId, client);
                console.log('✅ Пользователь добавлен в userSockets:', userId);
                console.log('✅ Всего пользователей в userSockets:', this.userSockets.size);
                
                // Присоединяем к персональной комнате для уведомлений
                await client.join(`user_${userId}`);
                console.log('✅ Пользователь присоединен к комнате: user_${userId}');
            } else {
                console.log('❌ Пользователь не найден в client.data.user');
                console.log('❌ user:', user);
                console.log('❌ user.id:', user?.id);
                console.log('❌ user.sub:', user?.sub);
            }
        } catch (error) {
            this.logger.error(`Ошибка подключения: ${error.message}`);
            console.log('❌ Ошибка подключения:', error);
            client.disconnect();
        }
    }
  
    /**
     * Обработка отключения пользователя от WebSocket
     * 
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    async handleDisconnect(client: Socket) {
        try {
            const user = client.data.user;
            if (user && (user.id || user.sub)) {
                const userId = user.id || user.sub;
                this.userSockets.delete(userId);
                console.log('🔌 Пользователь удален из userSockets:', userId);
                console.log('🔌 Осталось пользователей в userSockets:', this.userSockets.size);
            }
        } catch (error) {
            this.logger.error(`Ошибка отключения: ${error.message}`);
        }
    }

    /**
     * Обработка инициации звонка
     * 
     * @param data - Данные для инициации звонка
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('initiate_call')
    async handleInitiateCall(
      @MessageBody() data: { remoteUserId: string; callType: string; sdp: string; type: string; callerUsername?: string },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { remoteUserId, callType, sdp, type, callerUsername } = data;
        
        const userId = user.id || user.sub;
        this.logger.log(`Пользователь ${userId} инициирует звонок к ${remoteUserId}`);
        
        // Генерируем callId для звонка
        const callId = `call_${Date.now()}_${userId}_${remoteUserId}`;
        
        // Сохраняем участников звонка
        this.callParticipants.set(callId, { callerId: userId, receiverId: remoteUserId });
        this.logger.log(`Участники для звонка ${callId} сохранены: ${userId} -> ${remoteUserId}`);

        // Отправляем уведомление о входящем звонке получателю
        const receiverSocket = this.userSockets.get(remoteUserId);
        if (receiverSocket) {
          await receiverSocket.emit('incoming_call', {
            callId: callId,
            remoteUserId: userId,
            callType: callType,
            sdp: sdp,
            type: type,
            callerUsername: callerUsername || `User${userId.substring(0, 4)}`, // Передаем имя звонящего
            timestamp: new Date().toISOString()
          });
          
          // Отправляем callId обратно звонящему пользователю
          await client.emit('call_initiated', { callId });
          
          this.logger.log(`Уведомление о входящем звонке отправлено пользователю ${remoteUserId}`);
          this.logger.log(`CallId ${callId} отправлен звонящему пользователю ${userId}`);
        } else {
          this.logger.warn(`Пользователь ${remoteUserId} не подключен к WebSocket`);
          await client.emit('error', { message: 'Пользователь не в сети' });
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки инициации звонка: ${error.message}`);
        await client.emit('error', { message: 'Ошибка инициации звонка' });
      }
    }

    /**
     * Обработка принятия звонка
     *
     * @param data - Данные для принятия звонка
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('accept_call')
    async handleAcceptCall(
      @MessageBody() data: { callId: string },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId } = data;
        const userId = user.id || user.sub;

        this.logger.log(`Пользователь ${userId} принимает звонок ${callId}`);

        // Извлекаем ID звонящего из callId (формат: call_timestamp_callerId)
        const parts = callId.split('_');
        if (parts.length >= 3) {
          const callerId = parts[2];
          const callerSocket = this.userSockets.get(callerId);
          
          if (callerSocket) {
            await callerSocket.emit('call_accepted', { callId });
            this.logger.log(`Уведомление о принятии звонка отправлено пользователю ${callerId}`);
          } else {
            this.logger.warn(`Пользователь ${callerId} не подключен к WebSocket`);
          }
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки принятия звонка: ${error.message}`);
        await client.emit('error', { message: 'Ошибка принятия звонка' });
      }
    }

    /**
     * Обработка отклонения звонка
     *
     * @param data - Данные для отклонения звонка
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('reject_call')
    async handleRejectCall(
      @MessageBody() data: { callId: string },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId } = data;
        const userId = user.id || user.sub;

        this.logger.log(`Пользователь ${userId} отклоняет звонок ${callId}`);

        // Удаляем участников из временного хранилища
        this.callParticipants.delete(callId);

        // Извлекаем ID звонящего из callId (формат: call_timestamp_callerId)
        const parts = callId.split('_');
        if (parts.length >= 3) {
          const callerId = parts[2];
          const callerSocket = this.userSockets.get(callerId);
          
          if (callerSocket) {
            await callerSocket.emit('call_rejected', { callId });
            this.logger.log(`Уведомление об отклонении звонка отправлено пользователю ${callerId}`);
          } else {
            this.logger.warn(`Пользователь ${callerId} не подключен к WebSocket`);
          }
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки отклонения звонка: ${error.message}`);
        await client.emit('error', { message: 'Ошибка отклонения звонка' });
      }
    }

    /**
     * Обработка завершения звонка
     *
     * @param data - Данные для завершения звонка
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('end_call')
    async handleEndCall(
      @MessageBody() data: { callId: string; remoteUserId?: string }, // remoteUserId опционален для обратной совместимости
      @ConnectedSocket() client: Socket,
    ) {
      try {
        const user = client.data.user;
        const { callId, remoteUserId } = data;
        const userId = user.id || user.sub;

        this.logger.log(`Пользователь ${userId} завершает звонок ${callId}`);

        // Удаляем участников из временного хранилища
        this.callParticipants.delete(callId);

        // Определяем ID другого участника
        let otherUserId: string | undefined;

        // НОВЫЙ, ПРИОРИТЕТНЫЙ СПОСОБ: Если frontend передал remoteUserId, используем его
        if (remoteUserId) {
          otherUserId = remoteUserId;
          this.logger.log(`Целевой пользователь для end_call определен напрямую: ${otherUserId}`);
        } else {
          // СТАРЫЙ СПОСОБ (fallback): Извлекаем ID из callId
          this.logger.warn(`Поле remoteUserId не было передано в end_call, пытаюсь извлечь из callId`);
          if (callId && callId.startsWith('call_')) {
            const parts = callId.split('_');
            if (parts.length >= 3) {
              const callerId = parts[2];
              // Если текущий юзер - звонящий, то мы не знаем, кто получатель.
              // Если текущий юзер - получатель, то другой - звонящий.
              if (userId !== callerId) {
                otherUserId = callerId;
              }
            }
          }
        }

        if (otherUserId) {
          const otherUserSocket = this.userSockets.get(otherUserId);
          if (otherUserSocket) {
            await otherUserSocket.emit('call_ended', { callId });
            this.logger.log(`Уведомление о завершении звонка отправлено пользователю ${otherUserId}`);
          } else {
            this.logger.warn(`Пользователь ${otherUserId} не подключен к WebSocket`);
          }
        } else {
          // Если мы не смогли определить второго участника (например, звонящий завершил звонок)
          // Рассылаем всем, кроме себя, как раньше. Это не идеально, но надежно.
          this.logger.log(`Не удалось определить второго участника, уведомляем всех остальных`);
          client.broadcast.emit('call_ended', { callId });
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки завершения звонка: ${error.message}`);
        await client.emit('error', { message: 'Ошибка завершения звонка' });
      }
    }
  
    /**
     * Уведомление о входящем звонке
     * 
     * @param call - Объект звонка
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    async notifyIncomingCall(call: Call) {
        try {
            // НОВОЕ: Проверяем, что звонок в статусе RINGING
            if (call.status !== CallStatus.RINGING) {
                return;
            }
            
            const receiverSocket = this.userSockets.get(call.receiverId);
            if (receiverSocket) {
                await receiverSocket.emit('incoming_call', {
                        callId: call.id,
                        caller: {
                        id: call.callerId,
                        username: call.caller?.username || 'Unknown'
                    },
                    type: call.type,
                    timestamp: new Date().toISOString()
                });
            } else {
                this.logger.warn(`Пользователь ${call.receiverId} не подключен к WebSocket`);
            }
        } catch (error) {
            this.logger.error(`Ошибка отправки уведомления о звонке: ${error.message}`);
        }
    }
  
    /**
     * Уведомление об изменении статуса звонка
     * 
     * @param call - Объект звонка
     * @param status - Новый статус
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    async notifyCallStatusChange(call: Call, status: CallStatus) {
      try {
        const participants = [call.callerId, call.receiverId];
        
        for (const participantId of participants) {
          const participantSocket = this.userSockets.get(participantId);
          if (participantSocket) {
            await participantSocket.emit('call_status_changed', {
              callId: call.id,
              status,
              timestamp: new Date().toISOString()
            });
          }
        }
        
        this.logger.log(`Уведомление об изменении статуса звонка ${call.id} на ${status} отправлено`);
      } catch (error) {
        this.logger.error(`Ошибка отправки уведомления об изменении статуса: ${error.message}`);
      }
    }
  
    /**
     * Обработка SDP offer от звонящего
     * 
     * @param data - Данные SDP offer
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('call_offer')
    async handleCallOffer(
      @MessageBody() data: { callId: string; sdp: string; receiverId: string }, // ИСПРАВЛЕНО - добавлен receiverId
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, sdp, receiverId } = data;
        const userId = user.id || user.sub;
        
        // Отправляем SDP offer получателю звонка
        const receiverSocket = this.userSockets.get(receiverId);
        if (receiverSocket) {
          await receiverSocket.emit('call_offer', {
            callId,
            sdp,
            from: userId
          });
          
          this.logger.log(`SDP offer для звонка ${callId} отправлен получателю`);
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки SDP offer: ${error.message}`);
        await client.emit('error', { message: 'Ошибка обработки SDP offer' });
      }
    }
  
    /**
     * Обработка SDP answer от принимающего звонок
     * 
     * @param data - Данные SDP answer
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('sdp_answer')
    async handleSdpAnswer(
      @MessageBody() data: { callId: string; sdp: string; type: string },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, sdp, type } = data;
        const userId = user.id || user.sub;
        
        this.logger.log(`Получен SDP answer от пользователя ${userId} для звонка ${callId}`);
        
        // Определяем целевого пользователя по логике из callId
        let targetUserId: string;
        
        if (callId.startsWith('call_')) {
          // Постоянный callId: call_timestamp_callerId
          // Текущий пользователь - получатель, целевой - звонящий
          const parts = callId.split('_');
          if (parts.length >= 3) {
            targetUserId = parts[2]; // callerId из постоянного callId
          } else {
            this.logger.error(`Неверный формат постоянного callId: ${callId}`);
            return;
          }
        } else {
          this.logger.error(`Неизвестный формат callId: ${callId}`);
          return;
        }
        
        // Проверяем что целевой пользователь не является текущим
        if (targetUserId === userId) {
          this.logger.error(`Попытка отправить SDP answer самому себе: ${userId}`);
          return;
        }
        
        // Отправляем SDP answer звонящему
        const targetSocket = this.userSockets.get(targetUserId);
        if (targetSocket) {
          await targetSocket.emit('sdp_answer', {
            callId,
            sdp,
            type,
            from: userId
          });
          
          this.logger.log(`SDP answer для звонка ${callId} отправлен от ${userId} к ${targetUserId}`);
        } else {
          this.logger.warn(`Целевой пользователь ${targetUserId} не подключен к WebSocket`);
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки SDP answer: ${error.message}`);
        await client.emit('error', { message: 'Ошибка обработки SDP answer' });
      }
    }

    /**
     * Обработка SDP answer от принимающего звонок
     * 
     * @param data - Данные SDP answer
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('call_answer')
    async handleCallAnswer(
      @MessageBody() data: { callId: string; sdp: string; callerId: string }, // ИСПРАВЛЕНО - добавлен callerId
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, sdp, callerId } = data;
        const userId = user.id || user.sub;
        
        // Отправляем SDP answer звонящему
        const callerSocket = this.userSockets.get(callerId);
        if (callerSocket) {
          await callerSocket.emit('call_answer', {
            callId,
            sdp,
            from: userId
          });
          
          this.logger.log(`SDP answer для звонка ${callId} отправлен звонящему`);
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки SDP answer: ${error.message}`);
        await client.emit('error', { message: 'Ошибка обработки SDP answer' });
      }
    }
  
    /**
     * Обработка ICE кандидатов для WebRTC
     * 
     * @param data - Данные ICE кандидата
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('ice_candidate')
    async handleIceCandidate(
      @MessageBody() data: { callId: string; candidate: any },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, candidate } = data;
        const userId = user.id || user.sub;
        
        if (!callId) {
          this.logger.warn(`Получен ICE кандидат с callId: null от пользователя ${userId}`);
          return;
        }

        const participants = this.callParticipants.get(callId);
        if (!participants) {
          this.logger.warn(`Не найдены участники для звонка ${callId} при обработке ICE кандидата.`);
          return;
        }

        const { callerId, receiverId } = participants;
        const targetUserId = userId === callerId ? receiverId : callerId;
        
        if (targetUserId === userId) {
          this.logger.error(`Попытка отправить ICE кандидат самому себе: ${userId} для звонка ${callId}`);
          return;
        }
        
        const targetSocket = this.userSockets.get(targetUserId);
        
        if (targetSocket) {
          await targetSocket.emit('ice_candidate', {
            callId,
            candidate,
            from: userId
          });
          
          this.logger.log(`ICE кандидат для звонка ${callId} отправлен от ${userId} к ${targetUserId}`);
        } else {
          this.logger.warn(`Целевой пользователь ${targetUserId} не подключен к WebSocket`);
        }
      } catch (error) {
        this.logger.error(`Ошибка обработки ICE кандидата: ${error.message}`);
        await client.emit('error', { message: 'Ошибка обработки ICE кандидата' });
      }
    }
  
    /**
     * Получение списка подключенных пользователей (для отладки)
     * 
     * @param client - WebSocket клиент
     * @since 2.0.0
     * @author ИИ-Ассистент + Bessonniy
     */
    @SubscribeMessage('get_connected_users')
    async handleGetConnectedUsers(@ConnectedSocket() client: Socket) {
      try {
        const connectedUsers = Array.from(this.userSockets.keys());
        await client.emit('connected_users', connectedUsers);
      } catch (error) {
        this.logger.error(`Ошибка получения списка пользователей: ${error.message}`);
      }
    }
  }