import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

/**
 * Сущность пригласительного кода для регистрации пользователей
 * 
 * В MVP версии используется только один универсальный код 'secret_invite',
 * который можно использовать неограниченное количество раз.
 * В будущих версиях будет расширена для поддержки множественных одноразовых кодов.
 * 
 * @entity invitation_codes - Таблица в PostgreSQL
 * @class InvitationCode
 * @since 1.0.0
 * @author ИИ-Ассистент + Bessonniy
 * 
 * @example
 * ```typescript
 * // Создание нового пригласительного кода
 * const invitationCode = new InvitationCode();
 * invitationCode.code = 'secret_invite';
 * invitationCode.isUsed = false;
 * ```
 */
@Entity()
export class InvitationCode {
  /**
   * Уникальный идентификатор пригласительного кода
   * 
   * Автоматически генерируется как UUID при создании записи
   * 
   * @type {string}
   * @primary
   * @generated uuid
   * 
   * @example "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
   */
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /**
   * Сам пригласительный код
   * 
   * В MVP версии используется только 'secret_invite'.
   * Должен быть уникальным в пределах всей таблицы.
   * 
   * @type {string}
   * @unique
   * @required
   * 
   * @example "secret_invite"
   */
  @Column({
    unique: true,
  })
  code: string;

  /**
   * Флаг использования пригласительного кода
   * 
   * В MVP версии НЕ ИСПОЛЬЗУЕТСЯ (всегда false).
   * Код 'secret_invite' можно использовать многократно.
   * В будущих версиях будет контролировать одноразовое использование.
   * 
   * @type {boolean}
   * @default false
   * 
   * @example false // В MVP всегда false
   */
  @Column({
    default: false,
  })
  isUsed: boolean;

  /**
   * ID пользователя, который последним использовал код
   * 
   * Хранит ID последнего пользователя для статистики.
   * В MVP версии обновляется при каждом использовании 'secret_invite'.
   * 
   * @type {string | null}
   * @nullable
   * 
   * @example "a1b2c3d4-e5f6-7890-abcd-ef1234567890" // ID пользователя
   */
  @Column({
    nullable: true,
  })
  usedByUserId: string;

  /**
   * Дата и время создания пригласительного кода
   * 
   * Автоматически устанавливается при создании записи в БД
   * 
   * @type {Date}
   * @default CURRENT_TIMESTAMP
   * 
   * @example 2025-08-16T12:30:45.123Z
   */
  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  /**
   * Дата и время последнего использования кода
   * 
   * В MVP версии обновляется каждый раз при регистрации нового пользователя
   * с кодом 'secret_invite' для ведения статистики использования.
   * 
   * @type {Date | undefined}
   * @nullable
   * 
   * @example 2025-08-16T15:45:30.789Z
   */
  @Column({
    type: 'timestamp',
    nullable: true,
  })
  usedAt?: Date;
} 