import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { InvitationCodesModule } from '../invitation-codes/invitation-codes.module';

@Module({
  imports: [TypeOrmModule.forFeature([User]), InvitationCodesModule],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService], // Экспортируем UsersService для использования в других модулях (например, AuthModule)
})
export class UsersModule {}
