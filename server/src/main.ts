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

  // どの応答も溜め込ませない。
  // 海の通数も拾える数も、古い値を見せた時点で意味を失う。
  // 便りの本文はさらに、端末に残らないことが機構の一部になっている
  // (握らないと読めないという仕掛けが、キャッシュ経由で崩れる)。
  // クライアント側でもキャッシュを切っているが、約束はサーバーが宣言する
  app.use((_req: unknown, res: { setHeader(k: string, v: string): void }, next: () => void) => {
    res.setHeader('Cache-Control', 'no-store');
    next();
  });

  const port = Number(process.env.PORT ?? 3100);
  await app.listen(port, '0.0.0.0');
  console.log(`[tenonaka] listening on http://0.0.0.0:${port}`);
}

void bootstrap();
