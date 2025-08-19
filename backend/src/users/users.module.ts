import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { InvitationCodesModule } from '../invitation-codes/invitation-codes.module';
import { ChatModule } from '../chat/chat.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]), 
    InvitationCodesModule,
    forwardRef(() => ChatModule), // Импортируем ChatModule с forwardRef
  ],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService], // Экспортируем UsersService для использования в других модулях (например, AuthModule, ChatModule)
})
export class UsersModule {}
