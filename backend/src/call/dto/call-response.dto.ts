import { IsUUID, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * DTO для ответа на входящий звонок
 * 
 * Используется когда пользователь принимает или отклоняет входящий звонок.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
export class CallResponseDto {
  @ApiProperty({
    description: 'ID звонка для ответа',
    example: '123e4567-e89b-12d3-a456-426614174000',
    type: 'string',
    format: 'uuid'
  })
  @IsUUID()
  callId: string;

  @ApiProperty({
    description: 'Действие с входящим звонком',
    enum: ['accept', 'reject'],
    example: 'accept',
    type: 'string'
  })
  @IsEnum(['accept', 'reject'])
  action: 'accept' | 'reject';
}
