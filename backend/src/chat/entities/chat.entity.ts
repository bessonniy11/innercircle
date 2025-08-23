import { Entity, PrimaryGeneratedColumn, Column, ManyToMany, JoinTable, OneToMany } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Message } from './message.entity';
import { ChatParticipant } from './chat-participant.entity';

@Entity()
export class Chat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string; // For group chats, or a concatenated name for direct chats

  @Column({ default: false })
  isPrivate: boolean;

  @ManyToMany(() => User, user => user.chats)
  @JoinTable()
  participants: User[];

  @OneToMany(() => Message, message => message.chat)
  messages: Message[];

  @OneToMany(() => ChatParticipant, chatParticipant => chatParticipant.chat)
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