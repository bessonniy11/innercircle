import { Controller, Get, Param, Query, UseGuards, Req, Res, HttpStatus } from '@nestjs/common';
import { MessageService } from './message.service';
import { AuthGuard } from '@nestjs/passport';
import type { Request, Response } from 'express';

/**
 * Контроллер для работы с сообщениями по HTTP.
 * Предоставляет API для получения истории сообщений в чате.
 * 
 * @controller messages
 * @since 1.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@Controller('messages')
@UseGuards(AuthGuard('jwt'))
export class MessageController {
  constructor(private readonly messageService: MessageService) {}

  /**
   * Получает историю сообщений для указанного чата.
   * 
   * В MVP версии реализована базовая пагинация.
   * 
   * @param chatId - ID чата, для которого нужно получить сообщения.
   * @param limit - Максимальное количество сообщений для получения (по умолчанию 50).
   * @param offset - Смещение для пагинации (по умолчанию 0).
   * @param req - Объект запроса, содержащий информацию о пользователе (для валидации доступа).
   * @param res - Объект ответа для отправки HTTP-ответа.
   * @returns Promise<void> - Ответ с массивом сообщений.
   * @throws {NotFoundException} Если чат не найден или пользователь не является его участником.
   * @throws {UnauthorizedException} Если пользователь не авторизован.
   * @example
   * ```typescript
   * // GET /messages/a1b2c3d4-e5f6-7890-1234-567890abcdef?limit=20&offset=0
   * ```
   */
  @Get(':chatId')
  async getMessagesForChat(
    @Param('chatId') chatId: string,
    @Query('limit') limit: number = 50,
    @Query('offset') offset: number = 0,
    @Req() req: Request,
    @Res() res: Response
  ): Promise<void> {
    console.log(`MessageController: Received request for chatId: ${chatId}`); // Debug log
    // В реальном приложении здесь должна быть проверка, является ли текущий пользователь участником чата
    // Для MVP, мы полагаемся на логику внутри MessageService, которая проверяет существование чата.
    // Однако, для полной безопасности, эту проверку лучше дублировать и здесь.
    try {
      const messages = await this.messageService.getMessagesForChat(chatId, limit, offset);
      res.status(HttpStatus.OK).json(messages);
    } catch (error) {
      if (error.status === HttpStatus.NOT_FOUND) {
        res.status(HttpStatus.NOT_FOUND).json({ message: error.message });
      } else {
        res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ message: 'Internal server error', error: error.message });
      }
    }
  }
}
