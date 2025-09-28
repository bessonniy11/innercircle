import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

/**
 * DTO для обновления FCM токена пользователя.
 * 
 * @since 2.2.0
 * @author ИИ-Ассистент + Bessonniy
 */
export class UpdateFcmTokenDto {
  @ApiProperty({
    description: 'FCM токен устройства',
    example: 'c2_AbcDeFgHiJkLmNoPqRsTuVwXyZ...',
  })
  @IsString()
  @IsNotEmpty()
  fcmToken: string;
}
