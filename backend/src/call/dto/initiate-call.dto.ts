import { IsUUID, IsEnum, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { CallType } from '../entities/call.entity';

/**
 * DTO для инициации звонка
 * 
 * Используется при нажатии кнопки звонка пользователем.
 * В MVP версии поддерживаются только голосовые звонки.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
export class InitiateCallDto {
  @ApiProperty({
    description: 'ID пользователя, которому звоним',
    example: '550e8400-e29b-41d4-a716-446655440001',
    type: 'string',
    format: 'uuid'
  })
  @IsUUID()
  targetUserId: string;

  @ApiProperty({
    description: 'Тип звонка (голосовой или видеозвонок)',
    enum: CallType,
    default: CallType.VOICE,
    example: CallType.VOICE,
    required: false
  })
  @IsEnum(CallType)
  @IsOptional()
  type?: CallType = CallType.VOICE;
}
