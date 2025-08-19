import { Controller, Get, UseGuards, Req, HttpStatus, Res } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Request, Response } from 'express'; // Corrected import
import { ChatService } from './chat.service';

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
}
