import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity';
import { User } from '../users/entities/user.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { UsersService } from '../users/users.service'; // Импортируем UsersService

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Chat)
    private chatRepository: Repository<Chat>,
    private usersService: UsersService, // Инжектируем UsersService
  ) {}

  async createChat(createChatDto: CreateChatDto, creatorId: string): Promise<Chat> {
    const { name, participantIds } = createChatDto;

    const participants = await this.usersService.findAllByIds(participantIds); // Используем UsersService
    const creator = await this.usersService.findOne(creatorId); // Используем UsersService

    if (!creator) {
      throw new NotFoundException('Creator not found');
    }

    // Ensure all participants exist
    if (participants.length !== participantIds.length) {
      throw new BadRequestException('One or more participants not found');
    }

    // Ensure creator is among participants if it's not a group chat or specific logic applies
    if (!participants.some(p => p.id === creatorId)) {
        participants.push(creator);
    }

    const chat = this.chatRepository.create({
      name,
      participants,
    });

    return this.chatRepository.save(chat);
  }

  async findChatById(id: string): Promise<Chat | null> {
    return this.chatRepository.findOne({ where: { id }, relations: ['participants', 'messages'] });
  }

  async findUserChats(userId: string): Promise<Chat[]> {
    return this.chatRepository.find({
      where: { participants: { id: userId } },
      relations: ['participants', 'messages'],
    });
  }

  async addParticipantToChat(chatId: string, userId: string): Promise<Chat> {
    const chat = await this.findChatById(chatId);
    const user = await this.usersService.findOne(userId); // Используем UsersService

    if (!chat) throw new NotFoundException('Chat not found');
    if (!user) throw new NotFoundException('User not found');

    if (chat.participants.some(p => p.id === userId)) {
      throw new BadRequestException('User is already a participant');
    }

    chat.participants.push(user);
    return this.chatRepository.save(chat);
  }

  async removeParticipantFromChat(chatId: string, userId: string): Promise<Chat> {
    const chat = await this.findChatById(chatId);
    if (!chat) throw new NotFoundException('Chat not found');

    chat.participants = chat.participants.filter(p => p.id !== userId);
    return this.chatRepository.save(chat);
  }

  async deleteChat(chatId: string): Promise<void> {
    const result = await this.chatRepository.delete(chatId);
    if (result.affected === 0) {
      throw new NotFoundException(`Chat with ID ${chatId} not found`);
    }
  }
}
