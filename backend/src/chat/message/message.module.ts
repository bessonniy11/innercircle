import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MessageService } from './message.service';
import { MessageController } from './message.controller';
import { Message } from '../entities/message.entity';
import { ChatModule } from '../chat.module';
import { UsersModule } from '../../users/users.module';
import { Chat } from '../entities/chat.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Message, Chat]),
    forwardRef(() => ChatModule),
    forwardRef(() => UsersModule),
  ],
  controllers: [MessageController],
  providers: [MessageService],
  exports: [MessageService],
})
export class MessageModule {}
