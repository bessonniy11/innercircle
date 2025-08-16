import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors(); // Enable CORS for HTTP requests
  app.useGlobalPipes(new ValidationPipe()); // Enable global validation
  app.useWebSocketAdapter(new IoAdapter(app)); // Use Socket.IO adapter
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
