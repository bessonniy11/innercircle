import { Controller, Post, Body, HttpCode, HttpStatus, UsePipes, ValidationPipe, Get, UseGuards, Request, Param, Put, Delete, NotFoundException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { User } from './entities/user.entity';
import { UserPublicDto } from './dto/user-public.dto'; // Импортируем новый DTO
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';

@ApiTags('users') // Добавляем тег для Swagger
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @UsePipes(ValidationPipe)
  @ApiOperation({ summary: 'Регистрация нового пользователя', description: 'Пользователь регистрируется с помощью логина, пароля и пригласительного кода.' })
  @ApiResponse({ status: HttpStatus.CREATED, description: 'Пользователь успешно зарегистрирован.', type: UserPublicDto }) // Указываем тип возвращаемого значения
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Неверный пригласительный код или имя пользователя уже существует.' })
  async register(@Body() createUserDto: CreateUserDto): Promise<Omit<User, 'passwordHash'>> {
    const user = await this.usersService.create(createUserDto);
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { passwordHash, ...result } = user;
    return result;
  }

  /**
   * Получает профиль текущего аутентифицированного пользователя.
   * @param req - Объект запроса, содержащий информацию о пользователе.
   * @returns Профиль пользователя, исключая passwordHash.
   */
  @UseGuards(AuthGuard('jwt'))
  @Get('profile')
  @ApiBearerAuth() // Указываем, что требуется Bearer токен
  @ApiOperation({ summary: 'Получить профиль текущего пользователя', description: 'Возвращает данные текущего аутентифицированного пользователя.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Профиль пользователя успешно получен.', type: UserPublicDto }) // Указываем тип возвращаемого значения
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  getProfile(@Request() req): Omit<User, 'passwordHash'> {
    const { passwordHash, ...result } = req.user;
    return result; // Возвращаем UserPublicDto
  }

  /**
   * Получает список всех пользователей в системе, исключая текущего аутентифицированного пользователя.
   * @param req - Объект запроса, содержащий информацию о текущем пользователе.
   * @returns Promise<UserPublicDto[]> - Список всех пользователей, кроме текущего.
   * @throws {UnauthorizedException} Если пользователь не авторизован.
   * @example
   * ```typescript
   * // GET /users
   * // Headers: Authorization: Bearer <JWT_TOKEN>
   * // Response:
   * // [
   * //   {
   * //     "id": "uuid-of-user-2",
   * //     "username": "user2",
   * //     "isAdmin": false,
   * //     "createdAt": "2023-08-20T10:00:00.000Z",
   * //     "updatedAt": "2023-08-20T10:00:00.000Z"
   * //   },
   * //   ...
   * // ]
   * ```
   * @since 1.0.0
   * @author ИИ-Ассистент + Bessonniy
   */
  @UseGuards(AuthGuard('jwt'))
  @Get()
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Получить список всех пользователей (исключая текущего)', description: 'Возвращает список всех зарегистрированных пользователей, за исключением пользователя, который делает запрос.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Список пользователей успешно получен.', type: [UserPublicDto] }) // Указываем тип возвращаемого значения как массив UserPublicDto
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  async findAllUsers(@Request() req): Promise<UserPublicDto[]> {
    const users = await this.usersService.findAllUsersExcludingCurrentUser(req.user.id);
    return users.map(user => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { passwordHash, ...result } = user;
      return result as UserPublicDto;
    });
  }

  /**
   * Получает пользователя по ID.
   * @param id - ID пользователя.
   * @returns Профиль пользователя, исключая passwordHash.
   * @throws {NotFoundException} Если пользователь не найден.
   */
  @UseGuards(AuthGuard('jwt'))
  @Get(':id')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Получить пользователя по ID', description: 'Возвращает данные пользователя по его уникальному идентификатору.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Пользователь успешно получен.', type: UserPublicDto })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Пользователь не найден.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  async findOne(@Param('id') id: string): Promise<UserPublicDto> {
    const user = await this.usersService.findOne(id);
    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { passwordHash, ...result } = user;
    return result as UserPublicDto;
  }

  /**
   * Обновляет данные пользователя.
   * @param id - ID пользователя для обновления.
   * @param updateUserDto - DTO с обновленными данными пользователя.
   * @returns Обновленный профиль пользователя, исключая passwordHash.
   * @throws {NotFoundException} Если пользователь не найден.
   * @throws {BadRequestException} Если имя пользователя уже существует.
   */
  @UseGuards(AuthGuard('jwt'))
  @Put(':id')
  @UsePipes(ValidationPipe)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Обновить данные пользователя', description: 'Обновляет данные существующего пользователя по его ID.' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Пользователь успешно обновлен.', type: UserPublicDto })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Пользователь не найден.' })
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Имя пользователя уже существует или некорректные данные.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  async update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto): Promise<UserPublicDto> {
    const user = await this.usersService.update(id, updateUserDto);
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { passwordHash, ...result } = user;
    return result as UserPublicDto;
  }

  /**
   * Удаляет пользователя по ID.
   * @param id - ID пользователя для удаления.
   * @throws {NotFoundException} Если пользователь не найден.
   */
  @UseGuards(AuthGuard('jwt'))
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Удалить пользователя', description: 'Удаляет пользователя из системы по его ID.' })
  @ApiResponse({ status: HttpStatus.NO_CONTENT, description: 'Пользователь успешно удален.' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Пользователь не найден.' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Не авторизован.' })
  async remove(@Param('id') id: string): Promise<void> {
    await this.usersService.remove(id);
  }
}
