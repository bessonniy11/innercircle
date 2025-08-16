import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InvitationCodesService } from './invitation-codes.service';
import { InvitationCodesController } from './invitation-codes.controller';
import { InvitationCode } from '../users/entities/invitation-code.entity'; // Assuming it's here

@Module({
  imports: [TypeOrmModule.forFeature([InvitationCode])],
  providers: [InvitationCodesService],
  controllers: [InvitationCodesController],
  exports: [InvitationCodesService], // Export the service to be used in other modules (e.g., UsersModule)
})
export class InvitationCodesModule {}
