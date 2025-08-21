import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  app.enableCors(); // Enable CORS for HTTP requests
  app.useGlobalPipes(new ValidationPipe()); // Enable global validation
  app.useWebSocketAdapter(new IoAdapter(app)); // Use Socket.IO adapter

  // Swagger API Documentation
  const config = new DocumentBuilder()
    .setTitle('Inner Circle API')
    .setDescription('API документация семейного мессенджера Inner Circle')
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'JWT',
        description: 'Введите JWT токен',
        in: 'header',
      },
      'JWT-auth', // This name here is important for matching up with @ApiBearerAuth() in your controller!
    )
    .addTag('auth', 'Аутентификация и авторизация')
    .addTag('users', 'Управление пользователями')
    .addTag('chats', 'Управление чатами')
    .addTag('messages', 'Сообщения в чатах')
    .addTag('invitation-codes', 'Пригласительные коды')
    .addServer('http://localhost:3000', 'Development сервер')
    .addServer('https://yourdomain.com', 'Production сервер')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api-docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true, // Сохранять токен авторизации
      tagsSorter: 'alpha',
      operationsSorter: 'alpha',
    },
    customfavIcon: '/favicon.ico',
    customSiteTitle: 'Inner Circle API Documentation',
  });

  await app.listen(process.env.PORT ?? 3000);
  console.log(`🚀 Server running on: http://localhost:${process.env.PORT ?? 3000}`);
  console.log(`📚 API Documentation: http://localhost:${process.env.PORT ?? 3000}/api-docs`);
}
bootstrap();
