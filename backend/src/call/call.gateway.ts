// backend/src/call/call.gateway.ts
import { 
    WebSocketGateway, 
    WebSocketServer, 
    SubscribeMessage, 
    MessageBody, 
    ConnectedSocket,
    OnGatewayConnection,
  OnGatewayDisconnect,
  } from '@nestjs/websockets';
  import { Server, Socket } from 'socket.io';
import { Logger, Injectable } from '@nestjs/common'; // ИСПРАВЛЕННЫЙ ИМПОРТ
import { OnEvent } from '@nestjs/event-emitter';
  import { Call, CallStatus } from './entities/call.entity';
import { CallService } from './call.service';
import { JwtService } from '@nestjs/jwt';
  
  /**
   * WebSocket Gateway для управления звонками в реальном времени
 */
@Injectable()
  @WebSocketGateway({
    namespace: '/calls',
    cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
})
export class CallGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;
  
    private readonly logger = new Logger(CallGateway.name);
  private readonly userSockets = new Map<string, Socket>();
  private readonly callParticipants = new Map<
    string,
    { callerId: string; receiverId: string }
  >();

    constructor(
        private readonly jwtService: JwtService,
    // УДАЛЕНО: callService больше не нужен здесь
  ) {}

  // ===========================================================================
  // Event Listeners (from CallService)
  // ===========================================================================

  @OnEvent('call.created')
  async handleCallCreated(call: Call) {
    this.logger.log(`Событие: call.created для звонка ${call.id}`);
    const receiverSocket = this.userSockets.get(call.receiverId);

    if (receiverSocket) {
      const payload = {
        callId: call.id,
        remoteUserId: call.callerId,
        callerName: call.caller.username,
        callType: call.type,
      };
      this.logger.log(
        `Отправка 'incoming_call' получателю ${call.receiverId}`,
      );
      receiverSocket.emit('incoming_call', payload);
    } else {
      this.logger.warn(
        `[handleCallCreated] Получатель ${call.receiverId} не в сети (нет сокета).`,
      );
    }
  }
  
  // УДАЛЕНЫ СТАРЫЕ ОБРАБОТЧИКИ

  // ===========================================================================
  // Gateway Lifecycle Hooks
  // ===========================================================================

    async handleConnection(client: Socket) {
        try {
            const token = client.handshake.auth.token;
      if (!token) {
        throw new Error('Токен аутентификации не предоставлен');
      }
            const decoded = this.jwtService.verify(token);
            client.data.user = decoded;
      const userId = decoded.sub;

      if (userId) {
                this.userSockets.set(userId, client);
        this.logger.log(`✅ Клиент подключен: ${userId}`);
            }
        } catch (error) {
      this.logger.error(`❌ Ошибка подключения: ${error.message}`);
            client.disconnect();
        }
    }
  
    async handleDisconnect(client: Socket) {
    const userId = client.data.user?.sub;
    if (userId) {
                this.userSockets.delete(userId);
      this.logger.log(`🔌 Клиент отключен: ${userId}`);
    }
  }

  // ===========================================================================
  // WebSocket Message Handlers
  // ===========================================================================
  
  // УДАЛЕНО: handleInitiateCall - теперь это делается через REST
  
  // ... (остальные @SubscribeMessage обработчики остаются без изменений) ...
  
  @SubscribeMessage('accept_call')
  async handleAcceptCall(
    @MessageBody() data: { callId: string; callerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { callId, callerId } = data;
    const callerSocket = this.userSockets.get(callerId);
    if (callerSocket) {
      this.logger.log(
        `[accept] от ${
          client.data.user.id || client.data.user.sub
        } для звонка ${callId}`,
      );
      callerSocket.emit('call_accepted', {
        callId,
        receiverId: client.data.user.id || client.data.user.sub,
      });
      this.logger.log(`[accepted] отправлен звонящему ${callerId}`);
    } else {
      this.logger.warn(`[accept] звонящий ${callerId} не найден`);
    }
  }

  @SubscribeMessage('reject_call')
  async handleRejectCall(
    @MessageBody() data: { callId: string; remoteUserId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { callId, remoteUserId } = data;
    const otherUserSocket = this.userSockets.get(remoteUserId);
    if (otherUserSocket) {
      this.logger.log(`[reject_call] от ${client.data.user.id || client.data.user.sub} для звонка ${callId}`);
      otherUserSocket.emit('call_rejected', { callId });
    }
  }

  @SubscribeMessage('end_call')
  async handleEndCall(
    @MessageBody() data: { callId: string; remoteUserId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { callId, remoteUserId } = data;
    const otherUserSocket = this.userSockets.get(remoteUserId);
    if (otherUserSocket) {
      this.logger.log(`[end_call] от ${client.data.user.id || client.data.user.sub} для звонка ${callId}`);
      otherUserSocket.emit('call_ended', { callId });
    }
  }

  @SubscribeMessage('sdp_offer')
  async handleSdpOffer(
    @MessageBody() data: { callId: string; sdp: any; receiverId: string },
    @ConnectedSocket() client: Socket,
  ) {
        const { callId, sdp, receiverId } = data;
        const receiverSocket = this.userSockets.get(receiverId);
        if (receiverSocket) {
      this.logger.log(
        `[offer] от ${client.data.user.id || client.data.user.sub} для звонка ${callId}`,
      );
      receiverSocket.emit('sdp_offer', {
            callId,
            sdp,
        from: client.data.user.id || client.data.user.sub,
      });
      this.logger.log(`[offer] отправлен получателю ${receiverId}`);
    } else {
      this.logger.warn(`[offer] получатель ${receiverId} не найден`);
    }
  }

    @SubscribeMessage('sdp_answer')
    async handleSdpAnswer(
    @MessageBody() data: { callId:string; sdp: any; callerId: string },
    @ConnectedSocket() client: Socket,
  ) {
        const { callId, sdp, callerId } = data;
        const callerSocket = this.userSockets.get(callerId);
        if (callerSocket) {
      this.logger.log(
        `[answer] от ${client.data.user.id || client.data.user.sub} для звонка ${callId}`,
      );
      callerSocket.emit('sdp_answer', {
            callId,
            sdp,
        from: client.data.user.id || client.data.user.sub,
      });
      this.logger.log(`[answer] отправлен звонящему ${callerId}`);
    } else {
      this.logger.warn(`[answer] звонящий ${callerId} не найден`);
    }
  }

    @SubscribeMessage('ice_candidate')
    async handleIceCandidate(
    @MessageBody() data: { callId: string; candidate: any; targetId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { callId, candidate, targetId } = data;
    const targetSocket = this.userSockets.get(targetId);
        
        if (targetSocket) {
        targetSocket.emit('ice_candidate', {
            callId,
            candidate,
            from: client.data.user.id || client.data.user.sub,
        });
      }
    }
  }