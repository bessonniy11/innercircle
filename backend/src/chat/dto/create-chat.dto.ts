import { IsString, IsNotEmpty, IsArray, ArrayMinSize } from 'class-validator';

export class CreateChatDto {
  @IsString()
  @IsNotEmpty()
  name: string; // For group chats, or can be generic for direct chats

  @IsArray()
  @ArrayMinSize(1, { message: 'At least one participant is required' })
  @IsString({ each: true }) // Each element in the array must be a string (user ID)
  participantIds: string[];
} 