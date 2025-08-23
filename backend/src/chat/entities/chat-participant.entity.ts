import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Index } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Chat } from './chat.entity';

/**
 * Entity для отслеживания участников чата и их статуса прочтения сообщений.
 * 
 * В MVP версии: простая реализация для подсчета непрочитанных сообщений.
 * В будущих версиях: может быть расширена для ролей, прав доступа, статусов.
 * 
 * @entity chat_participants
 * @since 1.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Entity('chat_participants')
@Index(['chatId', 'userId'], { unique: true }) // Уникальная связь пользователь-чат
export class ChatParticipant {
  /**
   * Уникальный идентификатор записи участника
   * @primary
   * @generated uuid
   */
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /**
   * Ссылка на чат
   */
  @ManyToOne(() => Chat, chat => chat.participants, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'chatId' })
  chat: Chat;

  /**
   * ID чата
   */
  @Column()
  chatId: string;

  /**
   * Ссылка на пользователя
   */
  @ManyToOne(() => User, user => user.chatParticipants, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  /**
   * ID пользователя
   */
  @Column()
  userId: string;

  /**
   * Время последнего прочтения сообщений в этом чате пользователем.
   * 
   * В MVP версии: используется для подсчета непрочитанных сообщений.
   * Все сообщения с createdAt > lastReadAt считаются непрочитанными.
   * 
   * @nullable
   * @default null - пользователь еще не читал сообщения в чате
   */
  @Column({
    type: 'timestamp',
    nullable: true,
    default: null,
  })
  lastReadAt: Date | null;

  /**
   * Время присоединения к чату
   * @default CURRENT_TIMESTAMP
   */
  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  joinedAt: Date;

  /**
   * Время создания записи
   * @default CURRENT_TIMESTAMP
   */
  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  /**
   * Время последнего обновления записи
   * @default CURRENT_TIMESTAMP
   */
  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
    onUpdate: 'CURRENT_TIMESTAMP',
  })
  updatedAt: Date;
}
