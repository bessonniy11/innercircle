import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatGateway } from './chat.gateway';
import { Chat } from './entities/chat.entity';
import { ChatService } from './chat.service';
import { AuthModule } from '../auth/auth.module'; // Импортируем AuthModule
import { UsersModule } from '../users/users.module'; // Импортируем UsersModule
import { MessageModule } from './message/message.module'; // Import MessageModule
import { ChatController } from './chat.controller'; // Add ChatController here

@Module({
  imports: [
    TypeOrmModule.forFeature([Chat]), // Remove Message entity from here
    forwardRef(() => AuthModule),
    forwardRef(() => UsersModule),
    forwardRef(() => MessageModule), // Import MessageModule here
  ],
  controllers: [ChatController], // Add ChatController here
  providers: [ChatGateway, ChatService], // Remove MessageService from providers
  exports: [ChatService], // Remove MessageService from exports
})
export class ChatModule {}
