import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToMany, JoinTable } from 'typeorm';
import { Chat } from '../../chat/entities/chat.entity';
import { Message } from '../../chat/entities/message.entity';
import { ChatParticipant } from '../../chat/entities/chat-participant.entity';

@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    unique: true,
  })
  username: string;

  @Column()
  passwordHash: string;

  @Column({
    default: false,
  })
  isAdmin: boolean;

  @Column({
    nullable: true,
  })
  invitationCode?: string;

  @OneToMany(() => Message, message => message.sender)
  messages: Message[];

  @ManyToMany(() => Chat, chat => chat.participants)
  chats: Chat[];

  @OneToMany(() => ChatParticipant, chatParticipant => chatParticipant.user)
  chatParticipants: ChatParticipant[];

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