import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatGateway } from './chat.gateway';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity';
import { ChatService } from './chat.service';
import { MessageService } from './message/message.service';
import { AuthModule } from '../auth/auth.module'; // Импортируем AuthModule
import { UsersModule } from '../users/users.module'; // Импортируем UsersModule

@Module({
  imports: [TypeOrmModule.forFeature([Chat, Message]), AuthModule, UsersModule], // Добавляем AuthModule и UsersModule сюда
  providers: [ChatGateway, ChatService, MessageService],
  exports: [ChatService, MessageService], // Export services for use in other modules if needed
})
export class ChatModule {}
