import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config'; // Import ConfigService
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { InvitationCodesModule } from './invitation-codes/invitation-codes.module';
import { ChatModule } from './chat/chat.module';
import { CallModule } from './call/call.module'; // НОВОЕ - модуль звонков
// import { MessageService } from './message/message.service'; // Remove this line

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, // Make ConfigModule available globally
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get<string>('DATABASE_HOST'),
        port: parseInt(configService.get<string>('DATABASE_PORT') ?? '5432', 10),
        username: configService.get<string>('DATABASE_USER'),
        password: configService.get<string>('DATABASE_PASSWORD'),
        database: configService.get<string>('DATABASE_NAME'),
        autoLoadEntities: true, // Automatically load entities (when they are created)
        synchronize: true, // Auto-create database schema (for development, disable in production)
      }),
      inject: [ConfigService],
    }),
    UsersModule,
    AuthModule,
    InvitationCodesModule,
    ChatModule,
    CallModule, // НОВОЕ - модуль звонков
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
