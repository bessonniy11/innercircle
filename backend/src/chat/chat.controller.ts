import { Controller, Get, UseGuards, Req, HttpStatus, Res, Delete, Param } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Request, Response } from 'express'; // Corrected import
import { ChatService } from './chat.service';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags, ApiBody } from '@nestjs/swagger';
import { CreatePrivateChatDto } from './dto/create-private-chat.dto';
import { Post, Body, ValidationPipe, UsePipes } from '@nestjs/common';
import { Chat } from './entities/chat.entity';
import { UnauthorizedException } from '@nestjs/common';

/**
 * Контроллер для работы с чатами по HTTP.
 * Предоставляет API для получения списка чатов пользователя.
 * 
 * @controller chats
 * @since 1.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Controller('chats')
@UseGuards(AuthGuard('jwt'))
@ApiTags('chats')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  /**
   * Получает список всех чатов, в которых участвует текущий пользователь.
   * В MVP версии включает "Семейный Чат".
   * 
   * @param req - Объект запроса, содержащий информацию о текущем пользователе.
   * @param res - Объект ответа для отправки HTTP-ответа.
   * @returns Promise<void> - Ответ с массивом чатов пользователя.
   * @throws {UnauthorizedException} Если пользователь не авторизован.
   * @example
   * ```typescript
   * // GET /chats
   * ```
   */
  @Get()
  @ApiOperation({ summary: 'Получить список чатов текущего пользователя', description: 'Возвращает все чаты, в которых участвует текущий аутентифицированный пользователь.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Список чатов успешно получен.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  @ApiBearerAuth()
  async getUserChats(@Req() req: Request, @Res() res: Response): Promise<void> {
    const user = (req as any).user; // Получаем пользователя из запроса (добавлен Passport.js JWT Strategy)
    if (!user || !user.id) {
      res.status(HttpStatus.UNAUTHORIZED).json({ message: 'Unauthorized' });
      return;
    }
    try {
      const chats = await this.chatService.findUserChats(user.id);
      res.status(HttpStatus.OK).json(chats);
    } catch (error) {
      res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ message: 'Internal server error', error: error.message });
    }
  }

  /**
   * Создает личный чат между текущим пользователем и указанным целевым пользователем.
   * Если чат уже существует, возвращает существующий чат.
   * @param req - Объект запроса, содержащий информацию о текущем пользователе.
   * @param createPrivateChatDto - DTO, содержащее ID целевого пользователя.
   * @returns Promise<Chat> - Созданный или существующий личный чат.
   * @throws {UnauthorizedException} Если пользователь не авторизован.
   * @throws {BadRequestException} Если ID целевого пользователя совпадает с текущим.
   * @throws {NotFoundException} Если целевой пользователь не найден.
   * @example
   * ```typescript
   * // POST /chats/private
   * // Body: { "targetUserId": "a1b2c3d4-e5f6-7890-1234-567890abcdef" }
   * ```
   */
  @Post('private')
  @UsePipes(new ValidationPipe({ transform: true }))
  @ApiOperation({ summary: 'Создать или найти личный чат', description: 'Инициирует новый личный чат с указанным пользователем или возвращает существующий, если он уже есть.' })
  @ApiResponse({ status: HttpStatus.CREATED, description: 'Личный чат создан или найден успешно.', type: Chat })
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Некорректный ID пользователя или попытка создать чат с самим собой.' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Целевой пользователь не найден.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  @ApiBearerAuth()
  async createPrivateChat(
    @Req() req: Request,
    @Body() createPrivateChatDto: CreatePrivateChatDto,
  ): Promise<Chat> {
    const currentUser = (req as any).user; // Текущий аутентифицированный пользователь
    if (!currentUser || !currentUser.id) {
      throw new UnauthorizedException('Unauthorized');
    }

    const chat = await this.chatService.findOrCreatePrivateChat(
      currentUser.id,
      createPrivateChatDto.targetUserId,
    );
    return chat;
  }

  /**
   * Удаляет чат по ID с проверкой прав доступа.
   * Нельзя удалить "Семейный Чат".
   * 
   * @param req - Объект запроса, содержащий информацию о текущем пользователе.
   * @param chatId - ID чата для удаления.
   * @param res - Объект ответа для отправки HTTP-ответа.
   * @returns Promise<void> - Успешный ответ или ошибка.
   * @throws {UnauthorizedException} Если пользователь не авторизован.
   * @throws {ForbiddenException} Если нет прав на удаление или это семейный чат.
   * @throws {NotFoundException} Если чат не найден.
   * @example
   * ```typescript
   * // DELETE /chats/a1b2c3d4-e5f6-7890-1234-567890abcdef
   * ```
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Delete(':id')
  @ApiOperation({ summary: 'Удалить чат', description: 'Удаляет чат по ID. Семейный чат удалить нельзя.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Чат успешно удален.' })
  @ApiResponse({ status: HttpStatus.FORBIDDEN, description: 'Нет прав на удаление или это семейный чат.' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Чат не найден.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  @ApiBearerAuth()
  async deleteChat(
    @Req() req: Request,
    @Param('id') chatId: string,
    @Res() res: Response
  ): Promise<void> {
    const user = (req as any).user;
    if (!user || !user.id) {
      res.status(HttpStatus.UNAUTHORIZED).json({ message: 'Unauthorized' });
      return;
    }

    try {
      await this.chatService.deleteChat(chatId, user.id);
      res.status(HttpStatus.OK).json({ message: 'Chat deleted successfully' });
    } catch (error) {
      if (error.name === 'ForbiddenException') {
        res.status(HttpStatus.FORBIDDEN).json({ message: error.message });
      } else if (error.name === 'NotFoundException') {
        res.status(HttpStatus.NOT_FOUND).json({ message: error.message });
      } else {
        res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ 
          message: 'Internal server error', 
          error: error.message 
        });
      }
    }
  }
}
