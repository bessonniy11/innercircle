import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * Статусы звонка в системе
 * 
 * @enum CallStatus
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
export enum CallStatus {
  /** Звонок инициируется */
  INITIATING = 'initiating',
  /** Звонок звонит (пользователь Б получает уведомление) */
  RINGING = 'ringing', 
  /** Звонок принят и активен */
  ANSWERED = 'answered',
  /** Звонок завершен нормально */
  ENDED = 'ended',
  /** Звонок пропущен */
  MISSED = 'missed',
  /** Звонок отклонен */
  REJECTED = 'rejected'
}

/**
 * Типы звонков
 * 
 * @enum CallType
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
export enum CallType {
  /** Голосовой звонок (MVP) */
  VOICE = 'voice',
  /** Видеозвонок (планируется в Phase 3) */
  VIDEO = 'video'
}

/**
 * Сущность звонка для хранения информации о голосовых/видеозвонках
 * 
 * В MVP версии поддерживаются только голосовые звонки.
 * WebRTC данные (ICE кандидаты) хранятся для отладки и анализа.
 * 
 * @entity calls
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Entity('calls')
export class Call {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'callerId', type: 'uuid' })
  callerId: string;

  @Column({ name: 'receiverId', type: 'uuid' })
  receiverId: string;

  @Column({ 
    type: 'enum', 
    enum: CallStatus, 
    default: CallStatus.INITIATING 
  })
  status: CallStatus;

  @Column({ 
    type: 'enum', 
    enum: CallType, 
    default: CallType.VOICE 
  })
  type: CallType;

  @Column({ name: 'startedAt', type: 'timestamp', nullable: true })
  startedAt: Date | null;

  @Column({ name: 'endedAt', type: 'timestamp', nullable: true })
  endedAt: Date | null;

  @Column({ type: 'integer', nullable: true })
  duration: number | null; // в секундах

  @Column({ name: 'callerIceCandidates', type: 'jsonb', nullable: true })
  callerIceCandidates: any[] | null;

  @Column({ name: 'receiverIceCandidates', type: 'jsonb', nullable: true })
  receiverIceCandidates: any[] | null;

  @CreateDateColumn({ name: 'createdAt' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'callerId' })
  caller: User;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'receiverId' })
  receiver: User;
}
