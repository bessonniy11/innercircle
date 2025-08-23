import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Chat } from './chat.entity';

@Entity()
export class Message {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  content: string;

  @ManyToOne(() => User, user => user.messages)
  @JoinColumn({ name: 'senderId' })
  sender: User;

  @Column()
  senderId: string;

  @ManyToOne(() => Chat, chat => chat.messages, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'chatId' })
  chat: Chat;

  @Column()
  chatId: string;

  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
    onUpdate: 'CURRENT_TIMESTAMP',
  })
  updatedAt: Date;
} 