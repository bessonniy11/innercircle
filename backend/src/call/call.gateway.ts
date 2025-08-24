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
  
    constructor(
        private readonly eventEmitter: EventEmitter2,
        private readonly jwtService: JwtService 
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
        const token = client.handshake.auth.token;
        const decoded = this.jwtService.verify(token);
        client.data.user = decoded;
        try {
            // Получаем пользователя из JWT токена
            const user = client.data.user;
            if (user && user.sub) {
              this.userSockets.set(user.sub, client);
              // Присоединяем к персональной комнате для уведомлений
              await client.join(`user_${user.sub}`);
            } else {
              console.log('❌ Пользователь не найден в client.data.user');
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
                if (user && user.id) {
                this.userSockets.delete(user.id);
            }
        } catch (error) {
            this.logger.error(`Ошибка отключения: ${error.message}`);
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
        
        // Отправляем SDP offer получателю звонка
        const receiverSocket = this.userSockets.get(receiverId);
        if (receiverSocket) {
          await receiverSocket.emit('call_offer', {
            callId,
            sdp,
            from: user.id
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
    @SubscribeMessage('call_answer')
    async handleCallAnswer(
      @MessageBody() data: { callId: string; sdp: string; callerId: string }, // ИСПРАВЛЕНО - добавлен callerId
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, sdp, callerId } = data;
        
        // Отправляем SDP answer звонящему
        const callerSocket = this.userSockets.get(callerId);
        if (callerSocket) {
          await callerSocket.emit('call_answer', {
            callId,
            sdp,
            from: user.id
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
      @MessageBody() data: { callId: string; candidate: any; targetUserId: string },
      @ConnectedSocket() client: Socket
    ) {
      try {
        const user = client.data.user;
        const { callId, candidate, targetUserId } = data;
        
        // Отправляем ICE кандидат целевому пользователю
        const targetSocket = this.userSockets.get(targetUserId);
        
        if (targetSocket) {
          await targetSocket.emit('ice_candidate', {
            callId,
            candidate,
            from: user.id
          });
          
          this.logger.log(`ICE кандидат для звонка ${callId} отправлен`);
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