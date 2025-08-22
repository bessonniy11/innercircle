import { Injectable, BadRequestException, NotFoundException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, Not } from 'typeorm';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import * as bcrypt from 'bcryptjs';
import { InvitationCodesService } from '../invitation-codes/invitation-codes.service';
import { ChatService } from '../chat/chat.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private invitationCodesService: InvitationCodesService,
    @Inject(forwardRef(() => ChatService))
    private chatService: ChatService, // Инжектируем ChatService с forwardRef
  ) {}

  /**
   * Создает нового пользователя и автоматически добавляет его в семейный чат
   * @param createUserDto - Данные для создания пользователя (username, password, invitationCode)
   * @returns Promise<User> - Созданный пользователь
   */
  async create(createUserDto: CreateUserDto): Promise<User> {
    const { username, password, invitationCode } = createUserDto;

    // Validate and mark invitation code as used
    if (!invitationCode) {
      throw new BadRequestException('Invitation code is required.');
    }
    const validInvitationCode = await this.invitationCodesService.validateCode(invitationCode);

    const existingUser = await this.usersRepository.findOneBy({ username });
    if (existingUser) {
      throw new BadRequestException('Username already exists.');
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = this.usersRepository.create({
      username,
      passwordHash,
      invitationCode: validInvitationCode.code, // Store the actual code from the validated entity
    });

    const savedUser = await this.usersRepository.save(user);
    await this.invitationCodesService.markCodeAsUsed(validInvitationCode.code, savedUser.id);

    // Автоматически добавляем пользователя в семейный чат
    try {
      await this.chatService.addUserToFamilyChat(savedUser.id);
    } catch (error) {
      // Логируем ошибку, но не прерываем регистрацию
      console.error('Failed to add user to family chat:', error.message);
    }

    return savedUser;
  }

  /**
   * Получает всех пользователей системы
   * @returns Promise<User[]> - Список всех пользователей
   */
  async findAll(): Promise<User[]> {
    return this.usersRepository.find();
  }

  /**
   * Получает всех пользователей системы, исключая текущего пользователя.
   * @param currentUserId - ID текущего аутентифицированного пользователя, которого нужно исключить из списка.
   * @returns Promise<User[]> - Список всех пользователей, кроме текущего.
   * @example
   * ```typescript
   * const users = await this.usersService.findAllUsersExcludingCurrentUser('some-uuid-123');
   * // Возвращает всех пользователей, кроме пользователя с ID 'some-uuid-123'
   * ```
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  async findAllUsersExcludingCurrentUser(currentUserId: string): Promise<User[]> {
    return this.usersRepository.find({
      where: {
        id: Not(currentUserId),
      },
    });
  }

  /**
   * Находит пользователя по ID
   * @param id - ID пользователя
   * @returns Promise<User | null> - Найденный пользователь или null
   */
  async findOne(id: string): Promise<User | null> {
    return this.usersRepository.findOneBy({ id });
  }

  /**
   * Находит пользователя по имени пользователя
   * @param username - Имя пользователя
   * @returns Promise<User | null> - Найденный пользователь или null
   */
  async findOneByUsername(username: string): Promise<User | null> {
    return this.usersRepository.findOneBy({ username });
  }

  /**
   * Обновляет данные пользователя
   * @param id - ID пользователя
   * @param updateUserDto - Данные для обновления
   * @returns Promise<User> - Обновленный пользователь
   */
  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.usersRepository.findOneBy({ id });
    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    if (updateUserDto.username && updateUserDto.username !== user.username) {
      const existingUser = await this.usersRepository.findOneBy({ username: updateUserDto.username });
      if (existingUser) {
        throw new BadRequestException('Username already exists.');
      }
    }

    if (updateUserDto.password) {
      updateUserDto.password = await bcrypt.hash(updateUserDto.password, 10);
    }

    // Merge the existing user with the new data
    Object.assign(user, updateUserDto);

    return this.usersRepository.save(user);
  }

  /**
   * Находит пользователей по списку ID
   * @param ids - Массив ID пользователей
   * @returns Promise<User[]> - Найденные пользователи
   */
  async findAllByIds(ids: string[]): Promise<User[]> {
    return this.usersRepository.findBy({ id: In(ids) });
  }

  /**
   * Удаляет пользователя по ID
   * @param id - ID пользователя для удаления
   * @returns Promise<void>
   */
  async remove(id: string): Promise<void> {
    const result = await this.usersRepository.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
  }
}
