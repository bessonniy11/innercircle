import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InvitationCode } from '../users/entities/invitation-code.entity';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class InvitationCodesService {
  constructor(
    @InjectRepository(InvitationCode)
    private invitationCodeRepository: Repository<InvitationCode>,
  ) {}

  async generateCode(): Promise<InvitationCode> {
    const code = uuidv4();
    const newCode = this.invitationCodeRepository.create({ code });
    return this.invitationCodeRepository.save(newCode);
  }

  async validateCode(code: string): Promise<InvitationCode> {
    const invitation = await this.invitationCodeRepository.findOneBy({ code });
    if (!invitation) {
      throw new NotFoundException('Invitation code not found.');
    }
    if (invitation.isUsed) {
      throw new BadRequestException('Invitation code has already been used.');
    }
    return invitation;
  }

  async markCodeAsUsed(code: string, userId: string): Promise<InvitationCode> {
    const invitation = await this.validateCode(code);
    invitation.isUsed = true;
    invitation.usedByUserId = userId;
    invitation.usedAt = new Date();
    return this.invitationCodeRepository.save(invitation);
  }

  async findAllCodes(): Promise<InvitationCode[]> {
    return this.invitationCodeRepository.find();
  }
}
