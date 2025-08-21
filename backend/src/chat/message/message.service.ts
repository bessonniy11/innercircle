import { Injectable, NotFoundException, BadRequestException, Inject, forwardRef } from '@nestjs/common';
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
    @Inject(forwardRef(() => UsersService))
    private usersService: UsersService, // Инжектируем UsersService с forwardRef
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

    console.log('MessageService: Attempting to save new message...', message);
    const savedMessage = await this.messageRepository.save(message);
    console.log('MessageService: Message saved. ID:', savedMessage.id);
    // Загружаем связанные сущности sender и chat после сохранения, чтобы фронтенд получил полные данные
    const fullMessage = (await this.messageRepository.findOne({
      where: { id: savedMessage.id },
      relations: ['sender', 'chat'],
    }))!;
    console.log('MessageService: Full message object after saving:', fullMessage);
    return fullMessage;
  }

  /**
   * Получает историю сообщений для указанного чата.
   * @param chatId - ID чата, для которого нужно получить сообщения.
   * @param limit - Максимальное количество сообщений для получения (по умолчанию 50).
   * @param offset - Смещение для пагинации (по умолчанию 0).
   * @returns Promise<Message[]> - Массив сообщений.
   * @throws {NotFoundException} Если чат не найден.
   */
  async getMessagesForChat(chatId: string, limit: number = 50, offset: number = 0): Promise<Message[]> {
    console.log(`MessageService: Fetching messages for chat: ${chatId} with limit: ${limit}, offset: ${offset}`);
    const chat = await this.chatRepository.findOneBy({ id: chatId });
    if (!chat) {
      throw new NotFoundException('Chat not found');
    }

    const messages = await this.messageRepository.find({
      where: { chat: { id: chatId } },
      relations: ['sender', 'chat'], // Загружаем sender и chat
      order: { createdAt: 'ASC' },
      take: limit,
      skip: offset,
    });
    console.log(`MessageService: Found ${messages.length} messages for chat ${chatId}.`);
    return messages;
  }
}
