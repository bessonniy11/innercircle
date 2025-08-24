import { Controller, Request, Post, UseGuards, Body, HttpStatus, HttpCode, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { LoginUserDto } from './dto/login-user.dto';
import { UsePipes, ValidationPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBody } from '@nestjs/swagger';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @ApiOperation({ 
    summary: 'Авторизация пользователя',
    description: 'Авторизация пользователя по username и password. Возвращает JWT токен для дальнейшей аутентификации.'
  })
  @ApiBody({ 
    type: LoginUserDto,
    description: 'Данные для авторизации',
    examples: {
      example1: {
        summary: 'Пример авторизации',
        value: {
          username: 'user1',
          password: 'password123'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Успешная авторизация',
    schema: {
      example: {
        access_token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        user: {
          id: '550e8400-e29b-41d4-a716-446655440000',
          username: 'user1',
          isAdmin: false
        }
      }
    }
  })
  @ApiResponse({ 
    status: 401, 
    description: 'Неверные учетные данные',
    schema: {
      example: {
        statusCode: 401,
        message: 'Unauthorized'
      }
    }
  })
  @ApiResponse({
    status: 401,
    description: 'Неверный токен обновления',
    schema: {
      example: {
        statusCode: 401,
        message: 'Invalid refresh token'
      }
    }
  })
  @UseGuards(AuthGuard('local'))
  @Post('login')
  @ApiBody({ type: LoginUserDto })
  @ApiResponse({
    status: 200,
    description: 'Успешный вход',
    schema: {
      type: 'object',
      properties: {
        access_token: { type: 'string' },
        refresh_token: { type: 'string' },
        expires_in: { type: 'number' },
        refresh_expires_in: { type: 'number' },
        user: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            username: { type: 'string' }
          }
        }
      }
    }
  })
  async login(@Body() loginUserDto: LoginUserDto) {
    const user = await this.authService.validateUser(
      loginUserDto.username,
      loginUserDto.password
    );
    
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    
    return this.authService.login(user);
  }

  @Post('refresh')
  @ApiOperation({ summary: 'Обновление Access Token' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        refresh_token: { type: 'string' }
      }
    }
  })
  @ApiResponse({
    status: 200,
    description: 'Token обновлен',
    schema: {
      type: 'object',
      properties: {
        access_token: { type: 'string' },
        expires_in: { type: 'number' },
        user: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            username: { type: 'string' }
          }
        }
      }
    }
  })
  async refresh(@Body() body: { refresh_token: string }) {
    return this.authService.refreshToken(body.refresh_token);
  }

  @Post('logout')
  @UseGuards(AuthGuard('jwt'))
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Выход пользователя' })
  @ApiResponse({
    status: 200,
    description: 'Успешный выход',
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string' }
      }
    }
  })
  async logout(@Request() req: any) {
    return this.authService.logout(req.user.id);
  }
}
