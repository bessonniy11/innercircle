import { Controller, Post, Get, UseGuards, Request, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { InvitationCodesService } from './invitation-codes.service';
import { InvitationCode } from '../users/entities/invitation-code.entity';

@Controller('invitation-codes')
export class InvitationCodesController {
  constructor(private readonly invitationCodesService: InvitationCodesService) {}

  @UseGuards(AuthGuard('jwt'))
  @Post('generate')
  @HttpCode(HttpStatus.CREATED)
  async generateCode(@Request() req): Promise<InvitationCode> {
    // TODO: Implement isAdmin check here later
    // For now, any authenticated user can generate, which is not ideal.
    // We will add role-based authorization later.
    return this.invitationCodesService.generateCode();
  }

  @UseGuards(AuthGuard('jwt'))
  @Get()
  async findAllCodes(@Request() req): Promise<InvitationCode[]> {
    // TODO: Implement isAdmin check here later
    return this.invitationCodesService.findAllCodes();
  }
}
