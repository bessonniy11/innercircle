import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Message } from '../entities/message.entity';
import { Chat } from '../entities/chat.entity';
import { User } from '../../users/entities/user.entity';
import { SendMessageDto } from '../dto/send-message.dto';
import { UsersService } from '../../users/users.service'; // Импортируем UsersService

@Injectable()
export class MessageService {
  constructor(
    @InjectRepository(Message)
    private messageRepository: Repository<Message>,
    @InjectRepository(Chat)
    private chatRepository: Repository<Chat>,
    private usersService: UsersService, // Инжектируем UsersService
  ) {}

  async sendMessage(senderId: string, sendMessageDto: SendMessageDto): Promise<Message> {
    const { chatId, content } = sendMessageDto;

    const chat = await this.chatRepository.findOne({ where: { id: chatId }, relations: ['participants'] });
    if (!chat) {
      throw new NotFoundException('Chat not found');
    }

    const sender = await this.usersService.findOne(senderId); // Используем UsersService
    if (!sender) {
      throw new NotFoundException('Sender not found');
    }

    // Ensure the sender is a participant of the chat
    if (!chat.participants.some(p => p.id === senderId)) {
      throw new BadRequestException('Sender is not a participant of this chat');
    }

    const message = this.messageRepository.create({
      chat,
      sender,
      content,
    });

    return this.messageRepository.save(message);
  }

  async getMessagesForChat(chatId: string, limit: number = 50, offset: number = 0): Promise<Message[]> {
    const chat = await this.chatRepository.findOneBy({ id: chatId });
    if (!chat) {
      throw new NotFoundException('Chat not found');
    }

    return this.messageRepository.find({
      where: { chat: { id: chatId } },
      relations: ['sender'],
      order: { createdAt: 'ASC' },
      take: limit,
      skip: offset,
    });
  }
}
