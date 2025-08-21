import { WebSocketGateway, SubscribeMessage, MessageBody, ConnectedSocket, WebSocketServer, OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards, UsePipes, ValidationPipe } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from '../auth/auth.service';
import { UsersService } from '../users/users.service';
import { ChatService } from './chat.service';
import { MessageService } from './message/message.service';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';

@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private authService: AuthService,
    private usersService: UsersService,
    private chatService: ChatService,
    private messageService: MessageService,
  ) {}

  async handleConnection(client: Socket) {
    const authToken = client.handshake.auth.token as string; // Получаем токен из auth опции
    console.log(`ChatGateway: handleConnection received authToken: ${authToken ? 'present' : 'absent'}`);
    if (!authToken) {
      client.disconnect(true);
      console.log('ChatGateway: Disconnected - authToken not provided.');
      return;
    }

    try {
      const token = authToken; // Токен приходит напрямую, без префикса 'Bearer '
      console.log(`ChatGateway: Attempting to verify token: ${token}`);
      const decoded = this.authService.verifyJwt(token);
      console.log(`ChatGateway: Decoded token payload:`, decoded);
      console.log(`ChatGateway: Decoded user ID (sub): ${decoded.sub}`);
      const user = await this.usersService.findOne(decoded.sub);

      console.log(`ChatGateway: User found by ID: ${user ? user.username : 'null'}`);
      if (!user) {
        client.disconnect(true);
        console.log(`ChatGateway: Disconnected - User not found for ID: ${decoded.sub}`);
        return;
      }
      // Attach user to the socket for later use
      (client as any).user = user;
      // Join a personal room for direct messaging/notifications
      client.join(user.id);
      this.server.emit('userConnected', user.id);
      console.log(`User ${user.username} connected to WebSocket.`);
    } catch (error) {
      console.error('WebSocket authentication error:', error.message);
      console.log(`ChatGateway: Disconnected - Error in authentication process: ${error.message}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const user = (client as any).user;
    if (user) {
      this.server.emit('userDisconnected', user.id);
      console.log(`User ${user.username} disconnected from WebSocket.`);
    }
  }

  @UsePipes(new ValidationPipe())
  @SubscribeMessage('createChat')
  async createChat(@MessageBody() createChatDto: CreateChatDto, @ConnectedSocket() client: Socket) {
    const user = (client as any).user;
    if (!user) { throw new Error('Unauthorized'); }

    try {
      const chat = await this.chatService.createChat(createChatDto, user.id);
      // Add all participants to the chat room
      chat.participants.forEach(participant => {
        this.server.to(participant.id).emit('chatCreated', chat);
      });
      return { event: 'chatCreated', data: chat };
    } catch (error) {
      console.error('Error creating chat:', error.message);
      return { event: 'error', data: error.message };
    }
  }

  @UsePipes(new ValidationPipe())
  @SubscribeMessage('sendMessage')
  async sendMessage(@MessageBody() sendMessageDto: SendMessageDto, @ConnectedSocket() client: Socket) {
    const user = (client as any).user;
    if (!user) { throw new Error('Unauthorized'); }

    try {
      const message = await this.messageService.sendMessage(user.id, sendMessageDto);
      // Emit message to all participants of the chat
      const chat = await this.chatService.findChatById(message.chat.id);
      if (chat) {
        chat.participants.forEach(participant => {
          console.log(`ChatGateway: Emitting messageReceived to user ${participant.id} for chat ${chat.id}:`, message);
          this.server.to(participant.id).emit('messageReceived', message);
        });
      }
      return { event: 'messageSent', data: message };
    } catch (error) {
      console.error('Error sending message:', error.message);
      return { event: 'error', data: error.message };
    }
  }

  @SubscribeMessage('getChats')
  async getChats(@ConnectedSocket() client: Socket) {
    const user = (client as any).user;
    if (!user) { throw new Error('Unauthorized'); }

    try {
      const chats = await this.chatService.findUserChats(user.id);
      client.emit('userChats', chats);
      return { event: 'userChats', data: chats };
    } catch (error) {
      console.error('Error getting user chats:', error.message);
      return { event: 'error', data: error.message };
    }
  }

  @SubscribeMessage('getMessages')
  async getMessages(@MessageBody() payload: { chatId: string, limit?: number, offset?: number }, @ConnectedSocket() client: Socket) {
    const user = (client as any).user;
    if (!user) { throw new Error('Unauthorized'); }

    try {
      const { chatId, limit, offset } = payload;
      const chat = await this.chatService.findChatById(chatId);
      if (!chat || !chat.participants.some(p => p.id === user.id)) {
        throw new Error('Chat not found or user not a participant');
      }
      const messages = await this.messageService.getMessagesForChat(chatId, limit, offset);
      client.emit('chatMessages', messages);
      return { event: 'chatMessages', data: messages };
    } catch (error) {
      console.error('Error getting chat messages:', error.message);
      return { event: 'error', data: error.message };
    }
  }
}
