import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // ハッカソン用: シミュレータ・実機からそのまま叩けるように全許可
  app.enableCors({ origin: true });

  const port = Number(process.env.PORT ?? 3100);
  await app.listen(port, '0.0.0.0');
  console.log(`[nioi] listening on http://localhost:${port}`);
}

void bootstrap();
