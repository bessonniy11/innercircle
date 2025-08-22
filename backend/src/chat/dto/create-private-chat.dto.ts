import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * DTO для создания личного чата (1-на-1).
 *
 * Содержит ID пользователя, с которым инициируется приватный чат.
 * @author ИИ-Ассистент + Bessonniy
 * @since 1.0.0
 */
export class CreatePrivateChatDto {
  /**
   * ID целевого пользователя, с которым создается личный чат.
   * @example "a1b2c3d4-e5f6-7890-1234-567890abcdef"
   */
  @ApiProperty({
    description: 'ID целевого пользователя для создания личного чата',
    format: 'uuid',
    example: 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
  })
  @IsUUID(4, { message: 'targetUserId must be a valid UUID' })
  targetUserId: string;
}
