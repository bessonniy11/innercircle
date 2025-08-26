import { Controller, Post, Get, Delete, Body, Param, UseGuards, Request, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBody, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { CallService } from './call.service';
import { InitiateCallDto } from './dto/initiate-call.dto';
import { CallResponseDto } from './dto/call-response.dto';
import { Call, CallStatus, CallType } from './entities/call.entity';

/**
 * Контроллер для управления голосовыми и видеозвонками
 * 
 * Обеспечивает REST API для:
 * - Инициации звонков
 * - Управления статусами звонков
 * - Получения истории звонков
 * - Завершения активных звонков
 * 
 * В MVP версии поддерживаются только голосовые звонки.
 * WebRTC сигналинг происходит через WebSocket Gateway.
 * 
 * @since 2.0.0
 * @author ИИ-Ассистент + Bessonniy
 */
@ApiTags('calls (Звонки)')
@Controller('calls')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class CallController {
  constructor(private readonly callService: CallService) {}

  /**
   * Инициация нового звонка
   * 
   * @param initiateCallDto - Данные для инициации звонка
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<Call> - Созданный звонок
   * 
   * @example
   * ```typescript
   * POST /calls/initiate
   * {
   *   "targetUserId": "550e8400-e29b-41d4-a716-446655440001",
   *   "type": "voice"
   * }
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Post('initiate')
  @ApiOperation({
    summary: 'Инициация звонка',
    description: 'Создает новый звонок от текущего пользователя к указанному целевому пользователю'
  })
  @ApiBody({
    type: InitiateCallDto,
    description: 'Данные для инициации звонка'
  })
  @ApiResponse({
    status: 201,
    description: 'Звонок успешно создан',
    type: Call
  })
  @ApiResponse({
    status: 400,
    description: 'Некорректные данные или попытка позвонить самому себе'
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  @ApiResponse({
    status: 404,
    description: 'Целевой пользователь не найден'
  })
  async initiateCall(
    @Body() initiateCallDto: InitiateCallDto,
    @Request() req: any
  ): Promise<Call> {
    const callerId = req.user.id;
    return await this.callService.createCall(initiateCallDto, callerId);
  }

  /**
   * Ответ на входящий звонок (принять/отклонить)
   * 
   * @param callResponseDto - DTO с ответом на звонок
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<Call> - Обновленный звонок
   * 
   * @example
   * ```typescript
   * POST /calls/respond
   * {
   *   "callId": "123e4567-e89b-12d3-a456-426614174000",
   *   "action": "accept"
   * }
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Post('respond')
  @ApiOperation({
    summary: 'Ответ на входящий звонок',
    description: 'Позволяет принять или отклонить входящий звонок'
  })
  @ApiBody({
    type: CallResponseDto,
    description: 'Данные для ответа на звонок'
  })
  @ApiResponse({
    status: 200,
    description: 'Звонок успешно обработан',
    type: Call
  })
  @ApiResponse({
    status: 400,
    description: 'Некорректные данные или звонок не в статусе ожидания'
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  @ApiResponse({
    status: 403,
    description: 'Нет доступа к звонку или только получатель может отвечать'
  })
  @ApiResponse({
    status: 404,
    description: 'Звонок не найден'
  })
  async respondToCall(
    @Body() callResponseDto: CallResponseDto,
    @Request() req: any
  ): Promise<Call> {
    const userId = req.user.id;
    return await this.callService.handleCallResponse(callResponseDto, userId);
  }

  /**
   * Завершение активного звонка
   * 
   * @param callId - ID звонка для завершения
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<Call> - Завершенный звонок
   * 
   * @example
   * ```typescript
   * POST /calls/123e4567-e89b-12d3-a456-426614174000/end
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Post(':callId/end')
  @ApiOperation({
    summary: 'Завершение звонка',
    description: 'Завершает активный звонок (только для участников звонка)'
  })
  @ApiParam({
    name: 'callId',
    description: 'ID звонка для завершения',
    type: 'string',
    format: 'uuid'
  })
  @ApiResponse({
    status: 200,
    description: 'Звонок успешно завершен',
    type: Call
  })
  @ApiResponse({
    status: 400,
    description: 'Можно завершить только активный звонок'
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  @ApiResponse({
    status: 403,
    description: 'Нет доступа к звонку'
  })
  @ApiResponse({
    status: 404,
    description: 'Звонок не найден'
  })
  async endCall(
    @Param('callId') callId: string,
    @Request() req: any
  ): Promise<Call> {
    const userId = req.user.id;
    return await this.callService.endCall(callId, userId);
  }

  /**
   * Получение истории звонков пользователя
   * 
   * @param req - Запрос с аутентифицированным пользователем
   * @param limit - Лимит записей (по умолчанию 50)
   * @param offset - Смещение для пагинации (по умолчанию 0)
   * @returns Promise<Call[]> - Список звонков пользователя
   * 
   * @example
   * ```typescript
   * GET /calls/history?limit=20&offset=0
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Get('history')
  @ApiOperation({
    summary: 'История звонков',
    description: 'Получает историю всех звонков текущего пользователя (входящие и исходящие)'
  })
  @ApiQuery({
    name: 'limit',
    description: 'Количество записей для получения',
    type: 'number',
    required: false,
    example: 50
  })
  @ApiQuery({
    name: 'offset',
    description: 'Смещение для пагинации',
    type: 'number',
    required: false,
    example: 0
  })
  @ApiResponse({
    status: 200,
    description: 'История звонков успешно получена',
    type: [Call]
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  async getCallHistory(
    @Request() req: any,
    @Query('limit') limit: number = 50,
    @Query('offset') offset: number = 0
  ): Promise<Call[]> {
    const userId = req.user.id;
    return await this.callService.getUserCallHistory(userId, limit, offset);
  }

  /**
   * Получение активных звонков пользователя
   * 
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<Call[]> - Список активных звонков
   * 
   * @example
   * ```typescript
   * GET /calls/active
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Get('active')
  @ApiOperation({
    summary: 'Активные звонки',
    description: 'Получает список активных (отвеченных) звонков текущего пользователя'
  })
  @ApiResponse({
    status: 200,
    description: 'Активные звонки успешно получены',
    type: [Call]
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  async getActiveCalls(@Request() req: any): Promise<Call[]> {
    const userId = req.user.id;
    return await this.callService.getActiveCalls(userId);
  }

  /**
   * Получение информации о конкретном звонке
   * 
   * @param callId - ID звонка
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<Call> - Информация о звонке
   * 
   * @example
   * ```typescript
   * GET /calls/123e4567-e89b-12d3-a456-426614174000
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Get(':callId')
  @ApiOperation({
    summary: 'Информация о звонке',
    description: 'Получает детальную информацию о конкретном звонке (только для участников)'
  })
  @ApiParam({
    name: 'callId',
    description: 'ID звонка',
    type: 'string',
    format: 'uuid'
  })
  @ApiResponse({
    status: 200,
    description: 'Информация о звонке успешно получена',
    type: Call
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  @ApiResponse({
    status: 403,
    description: 'Нет доступа к звонку'
  })
  @ApiResponse({
    status: 404,
    description: 'Звонок не найден'
  })
  async getCallById(
    @Param('callId') callId: string,
    @Request() req: any
  ): Promise<Call> {
    const userId = req.user.id;
    return await this.callService.getCallById(callId, userId);
  }

  /**
   * Удаление записи звонка (только для администраторов)
   * 
   * @param callId - ID звонка для удаления
   * @param req - Запрос с аутентифицированным пользователем
   * @returns Promise<{ message: string }> - Подтверждение удаления
   * 
   * @example
   * ```typescript
   * DELETE /calls/123e4567-e89b-12d3-a456-426614174000
   * ```
   * @since 2.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @Delete(':callId')
  @ApiOperation({
    summary: 'Удаление звонка',
    description: 'Удаляет запись звонка из системы (только для администраторов)'
  })
  @ApiParam({
    name: 'callId',
    description: 'ID звонка для удаления',
    type: 'string',
    format: 'uuid'
  })
  @ApiResponse({
    status: 200,
    description: 'Звонок успешно удален',
    schema: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          example: 'Звонок успешно удален'
        }
      }
    }
  })
  @ApiResponse({
    status: 401,
    description: 'Пользователь не аутентифицирован'
  })
  @ApiResponse({
    status: 403,
    description: 'Недостаточно прав для удаления'
  })
  @ApiResponse({
    status: 404,
    description: 'Звонок не найден'
  })
  async deleteCall(
    @Param('callId') callId: string,
    @Request() req: any
  ): Promise<{ message: string }> {
    // Проверяем, что пользователь является администратором
    if (!req.user.isAdmin) {
      throw new Error('Недостаточно прав для удаления звонка');
    }

    // TODO: Реализовать удаление звонка в CallService
    // await this.callService.deleteCall(callId);
    
    return { message: 'Звонок успешно удален' };
  }
}
