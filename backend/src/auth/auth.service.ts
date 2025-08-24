import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import * as bcrypt from 'bcryptjs';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async validateUser(username: string, pass: string): Promise<any> {
    const user = await this.usersService.findOneByUsername(username);
    if (user && await bcrypt.compare(pass, user.passwordHash)) {
      // Исключаем все чувствительные данные
      const { passwordHash, refreshToken, refreshTokenExpiresAt, ...result } = user;
      return result;
    }
    return null;
  }

  /**
   * Вход пользователя с генерацией Access и Refresh токенов
   */
  async login(user: any) {
    const payload = { username: user.username, sub: user.id };
    
    // Генерируем Access Token (короткий)
    const accessToken = this.jwtService.sign(payload, { 
      expiresIn: this.configService.get('JWT_ACCESS_EXPIRES_IN', '15m') 
    });
    
    // Генерируем Refresh Token (долгий)
    const refreshToken = this.jwtService.sign(payload, { 
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN', '30d') 
    });

    // Вычисляем время истечения Refresh Token
    const refreshTokenExpiresAt = new Date();
    refreshTokenExpiresAt.setDate(refreshTokenExpiresAt.getDate() + 30);

    // Сохраняем Refresh Token в базе данных
    await this.usersService.saveRefreshToken(user.id, refreshToken, refreshTokenExpiresAt);

    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: 15 * 60, // 15 минут в секундах
      refresh_expires_in: 30 * 24 * 60 * 60, // 30 дней в секундах
      user: {
        id: user.id,
        username: user.username
      }
    };
  }

  /**
   * Обновление Access Token по Refresh Token
   */
  async refreshToken(refreshToken: string) {
    try {
      // Проверяем Refresh Token
      const payload = this.jwtService.verify(refreshToken);
      
      // Проверяем, что токен сохранен в базе и не истек
      const isValid = await this.usersService.validateRefreshToken(payload.sub, refreshToken);
      if (!isValid) {
        throw new UnauthorizedException('Invalid or expired refresh token');
      }

      // Генерируем новый Access Token
      const newAccessToken = this.jwtService.sign(
        { username: payload.username, sub: payload.sub },
        { expiresIn: this.configService.get('JWT_ACCESS_EXPIRES_IN', '15m') }
      );

      return {
        access_token: newAccessToken,
        expires_in: 15 * 60,
        user: {
          id: payload.sub,
          username: payload.username
        }
      };
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw new UnauthorizedException('Refresh token expired');
      }
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  /**
   * Выход пользователя (удаление Refresh Token)
   */
  async logout(userId: string) {
    await this.usersService.removeRefreshToken(userId);
    return { message: 'Successfully logged out' };
  }

  /**
   * Проверка JWT токена
   */
  verifyJwt(token: string): any {
    return this.jwtService.verify(token);
  }
}
