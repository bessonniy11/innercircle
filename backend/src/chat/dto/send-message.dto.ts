import { IsString, IsNotEmpty, IsUUID } from 'class-validator';

export class SendMessageDto {
  @IsUUID()
  @IsNotEmpty()
  chatId: string;

  @IsString()
  @IsNotEmpty()
  content: string;
} 