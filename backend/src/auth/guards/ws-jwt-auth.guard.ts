import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';

@Injectable()
export class WsJwtAuthGuard implements CanActivate {
  constructor(private jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    try {
      const client: Socket = context.switchToWs().getClient();
      const token = this.extractTokenFromHeader(client);
      
      if (!token) {
        throw new WsException('Unauthorized access');
      }

      const payload = await this.jwtService.verifyAsync(token);
      // ИСПРАВЛЯЕМ: Устанавливаем правильную структуру
      client.data.user = {
        id: payload.sub,
        username: payload.username
      };
      
      return true;
    } catch (err) {
      throw new WsException('Invalid token');
    }
  }

  private extractTokenFromHeader(client: Socket): string | undefined {
    const token = client.handshake.auth.token || 
                  client.handshake.headers.authorization?.replace('Bearer ', '');
    return token;
  }
}
