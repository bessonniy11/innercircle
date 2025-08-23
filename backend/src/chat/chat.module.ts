import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatGateway } from './chat.gateway';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity'; // Добавляем импорт Message entity
import { ChatParticipant } from './entities/chat-participant.entity';
import { ChatService } from './chat.service';
import { AuthModule } from '../auth/auth.module'; // Импортируем AuthModule
import { UsersModule } from '../users/users.module'; // Импортируем UsersModule
import { MessageModule } from './message/message.module'; // Import MessageModule
import { ChatController } from './chat.controller'; // Add ChatController here

@Module({
  imports: [
    TypeOrmModule.forFeature([Chat, Message, ChatParticipant]), // Добавляем entities для доступа к repositories
    forwardRef(() => AuthModule),
    forwardRef(() => UsersModule),
    forwardRef(() => MessageModule), // Import MessageModule here
  ],
  controllers: [ChatController], // Add ChatController here
  providers: [ChatGateway, ChatService], // Remove MessageService from providers
  exports: [ChatService], // Remove MessageService from exports
})
export class ChatModule {}
