import { ApiProperty } from '@nestjs/swagger';
import { IsUUID, IsString, IsBoolean, IsDateString } from 'class-validator';

/**
 * DTO для публичного представления пользователя.
 *
 * Используется для возврата данных пользователя, исключая конфиденциальную информацию, такую как passwordHash.
 * Содержит основные публичные поля сущности User.
 */
export class UserPublicDto {
  /**
   * Уникальный идентификатор пользователя (UUID).
   * @example "a1b2c3d4-e5f6-7890-1234-567890abcdef"
   */
  @ApiProperty({
    description: 'Уникальный идентификатор пользователя',
    format: 'uuid',
    example: 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
  })
  @IsUUID()
  id: string;

  /**
   * Имя пользователя.
   * @example "bessonniy_dev"
   */
  @ApiProperty({ description: 'Имя пользователя', example: 'bessonniy_dev' })
  @IsString()
  username: string;

  /**
   * Флаг, указывающий, является ли пользователь администратором.
   * @example false
   */
  @ApiProperty({ description: 'Является ли пользователь администратором', example: false })
  @IsBoolean()
  isAdmin: boolean;

  /**
   * Дата и время создания пользователя.
   * @example "2023-08-20T10:00:00.000Z"
   */
  @ApiProperty({
    description: 'Дата создания пользователя',
    format: 'date-time',
    example: '2023-08-20T10:00:00.000Z',
  })
  @IsDateString()
  createdAt: Date;

  /**
   * Дата и время последнего обновления пользователя.
   * @example "2023-08-20T10:00:00.000Z"
   */
  @ApiProperty({
    description: 'Дата последнего обновления пользователя',
    format: 'date-time',
    example: '2023-08-20T10:00:00.000Z',
  })
  @IsDateString()
  updatedAt: Date;
}
