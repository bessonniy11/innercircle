import { Injectable, BadRequestException, NotFoundException, ForbiddenException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, MoreThan, Not } from 'typeorm';
import { Chat } from './entities/chat.entity';
import { Message } from './entities/message.entity';
import { ChatParticipant } from './entities/chat-participant.entity';
import { User } from '../users/entities/user.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { UsersService } from '../users/users.service'; // Импортируем UsersService

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Chat)
    private chatRepository: Repository<Chat>,
    @InjectRepository(Message)
    private messageRepository: Repository<Message>,
    @InjectRepository(ChatParticipant)
    private chatParticipantRepository: Repository<ChatParticipant>,
    @Inject(forwardRef(() => UsersService))
    private usersService: UsersService, // Инжектируем UsersService с forwardRef
  ) {}

  /**
   * Создает новый чат с участниками
   * @param createChatDto - Данные для создания чата (название и список участников)
   * @param creatorId - ID создателя чата
   * @returns Promise<Chat> - Созданный чат с участниками
   */
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
      isPrivate: false, // Default to false for general chat creation
    });

    return this.chatRepository.save(chat);
  }

  /**
   * Находит или создает общий семейный чат для всех пользователей
   * @returns Promise<Chat> - Общий семейный чат
   */
  async findOrCreateFamilyChat(): Promise<Chat> {
    // Ищем существующий семейный чат по названию
    let familyChat = await this.chatRepository.findOne({
      where: { name: 'Семейный Чат' },
      relations: ['participants'],
    });

    // Если семейный чат не существует, создаем его
    if (!familyChat) {
      // Получаем всех существующих пользователей
      const allUsers = await this.usersService.findAll();
      
      if (allUsers.length === 0) {
        throw new BadRequestException('No users found to create family chat');
      }

      // Создаем семейный чат со всеми пользователями
      familyChat = this.chatRepository.create({
        name: 'Семейный Чат',
        participants: allUsers,
        isPrivate: false, // Mark as not private
      });

      familyChat = await this.chatRepository.save(familyChat);
    }

    return familyChat;
  }

  /**
   * Добавляет пользователя в общий семейный чат
   * @param userId - ID пользователя для добавления
   * @returns Promise<Chat> - Обновленный семейный чат
   */
  async addUserToFamilyChat(userId: string): Promise<Chat> {
    const familyChat = await this.findOrCreateFamilyChat();
    const user = await this.usersService.findOne(userId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Проверяем, что пользователь еще не участник
    const isAlreadyParticipant = familyChat.participants.some(p => p.id === userId);
    
    if (!isAlreadyParticipant) {
      familyChat.participants.push(user);
      return this.chatRepository.save(familyChat);
    }

    return familyChat;
  }

  /**
   * Находит или создает приватный чат между двумя пользователями.
   * Если чат уже существует, возвращает его. Иначе создает новый.
   * @param user1Id - ID первого пользователя.
   * @param user2Id - ID второго пользователя.
   * @returns Promise<Chat> - Существующий или новый приватный чат.
   * @throws NotFoundException Если один из пользователей не найден.
   * @throws BadRequestException Если ID пользователей совпадают.
   * @example
   * ```typescript
   * const chat = await chatService.findOrCreatePrivateChat('user-id-1', 'user-id-2');
   * ```
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async findOrCreatePrivateChat(user1Id: string, user2Id: string): Promise<Chat> {
    if (user1Id === user2Id) {
      throw new BadRequestException('Cannot create a private chat with yourself.');
    }

    const user1 = await this.usersService.findOne(user1Id);
    const user2 = await this.usersService.findOne(user2Id);

    if (!user1 || !user2) {
      throw new NotFoundException('One or both users not found.');
    }

    // Check if a private chat between these two users already exists
    const existingChats = await this.chatRepository.find({
      relations: ['participants'],
      where: {
        isPrivate: true, // Filter only private chats
      },
    });

    for (const chat of existingChats) {
      // Ensure it's a private chat (exactly two participants) and contains both users
      if (chat.participants.length === 2 &&
          chat.participants.some(p => p.id === user1Id) &&
          chat.participants.some(p => p.id === user2Id)) {
        return chat; // Found existing private chat
      }
    }

    // If no existing private chat, create a new one
    const newChat = this.chatRepository.create({
      name: `${user1.username} & ${user2.username}`,
      participants: [user1, user2],
      isPrivate: true, // Mark as private
    });

    return this.chatRepository.save(newChat);
  }

  async findChatById(id: string): Promise<Chat | null> {
    return this.chatRepository.findOne({ where: { id }, relations: ['participants', 'messages'] });
  }

  /**
   * Находит все чаты пользователя с оптимизированной загрузкой последних сообщений
   * и подсчетом непрочитанных сообщений.
   * 
   * В MVP версии: загружает последнее сообщение для каждого чата и считает
   * количество непрочитанных сообщений на основе lastReadAt.
   * 
   * @param userId - ID пользователя
   * @returns Promise<Chat[]> - Массив чатов с последними сообщениями и счетчиками непрочитанных
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async findUserChats(userId: string): Promise<Chat[]> {
    const chats = await this.chatRepository.find({
      where: { participants: { id: userId } },
      relations: ['participants'],
      order: { updatedAt: 'DESC' }, // Сортируем по времени последнего обновления
    });

    // Для каждого чата загружаем дополнительную информацию
    for (const chat of chats) {
      // Загружаем последнее сообщение
      const lastMessage = await this.messageRepository.findOne({
        where: { chatId: chat.id },
        relations: ['sender'],
        order: { createdAt: 'DESC' },
      });
      
      // Загружаем информацию о прочтении для этого пользователя
      const chatParticipant = await this.chatParticipantRepository.findOne({
        where: { chatId: chat.id, userId: userId },
      });
      
      // Подсчитываем непрочитанные сообщения (исключая собственные)
      let unreadCount = 0;
      if (chatParticipant && chatParticipant.lastReadAt) {
        unreadCount = await this.messageRepository.count({
          where: {
            chatId: chat.id,
            createdAt: MoreThan(chatParticipant.lastReadAt),
            senderId: Not(userId), // Исключаем собственные сообщения
          },
        });
      } else {
        // Если пользователь никогда не читал сообщения в этом чате
        unreadCount = await this.messageRepository.count({
          where: { 
            chatId: chat.id,
            senderId: Not(userId), // Исключаем собственные сообщения
          },
        });
      }
      
      // Добавляем дополнительную информацию к объекту чата
      (chat as any).lastMessage = lastMessage;
      (chat as any).unreadCount = unreadCount;
    }

    return chats;
  }

  /**
   * Отмечает сообщения в чате как прочитанные для указанного пользователя.
   * 
   * В MVP версии: простое обновление lastReadAt на текущее время.
   * В будущих версиях: может быть расширено для отдельных сообщений.
   * 
   * @param chatId - ID чата
   * @param userId - ID пользователя
   * @returns Promise<void>
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async markMessagesAsRead(chatId: string, userId: string): Promise<void> {
    // Ищем или создаем запись ChatParticipant
    let chatParticipant = await this.chatParticipantRepository.findOne({
      where: { chatId, userId },
    });

    if (!chatParticipant) {
      // Создаем новую запись, если её нет
      chatParticipant = this.chatParticipantRepository.create({
        chatId,
        userId,
        lastReadAt: new Date(),
        joinedAt: new Date(),
      });
    } else {
      // Обновляем время последнего прочтения
      chatParticipant.lastReadAt = new Date();
    }

    await this.chatParticipantRepository.save(chatParticipant);
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

  /**
   * Удаляет чат по ID с проверкой прав доступа
   * 
   * @param chatId - ID чата для удаления
   * @param userId - ID пользователя, который хочет удалить чат
   * @throws ForbiddenException если чат нельзя удалить
   * @throws NotFoundException если чат не найден
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async deleteChat(chatId: string, userId: string): Promise<void> {
    // Находим чат с участниками
    const chat = await this.chatRepository.findOne({
      where: { id: chatId },
      relations: ['participants'],
    });

    if (!chat) {
      throw new NotFoundException('Chat not found');
    }

    // Проверяем, что пользователь участник чата
    const isParticipant = chat.participants.some(p => p.id === userId);
    if (!isParticipant) {
      throw new ForbiddenException('You are not a participant of this chat');
    }

    // Запрещаем удаление семейного чата
    if (chat.name === 'Семейный Чат') {
      throw new ForbiddenException('Cannot delete family chat');
    }

    // Используем транзакцию для безопасного удаления
    await this.chatRepository.manager.transaction(async transactionalEntityManager => {
      // Сначала удаляем все сообщения в чате
      await transactionalEntityManager.delete('message', { chatId: chatId });
      
      // Затем удаляем записи участников  
      await transactionalEntityManager.delete('chat_participants', { chatId: chatId });
      
      // И наконец удаляем сам чат
      await transactionalEntityManager.delete('chat', { id: chatId });
    });
  }
}
