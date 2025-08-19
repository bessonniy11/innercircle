import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatGateway } from './chat.gateway';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity';
import { ChatService } from './chat.service';
import { MessageService } from './message/message.service';
import { AuthModule } from '../auth/auth.module'; // Импортируем AuthModule
import { UsersModule } from '../users/users.module'; // Импортируем UsersModule

@Module({
  imports: [
    TypeOrmModule.forFeature([Chat, Message]), 
    forwardRef(() => AuthModule), // Используем forwardRef для AuthModule
    forwardRef(() => UsersModule), // Используем forwardRef для избежания circular dependency
  ],
  providers: [ChatGateway, ChatService, MessageService],
  exports: [ChatService, MessageService], // Экспортируем ChatService для использования в UsersModule
})
export class ChatModule {}
