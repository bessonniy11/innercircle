import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class InvitationCode {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    unique: true,
  })
  code: string;

  @Column({
    default: false,
  })
  isUsed: boolean;

  @Column({
    nullable: true,
  })
  usedByUserId: string;

  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  @Column({
    type: 'timestamp',
    nullable: true,
  })
  usedAt?: Date;
} 