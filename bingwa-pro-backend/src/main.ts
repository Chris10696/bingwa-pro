// bingwa-pro-backend/src/main.ts
// W2.E: global ValidationPipe (whitelist strips unknown body props; transform
// coerces query types so offer-filter @Type/@Transform actually work).
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');

  const wifiIp = '192.168.100.8';
  console.log(`🚀 Backend running at:`);
  console.log(`   - Local: http://localhost:${port}`);
  console.log(`   - Wi-Fi Network: http://${wifiIp}:${port} (USE THIS FOR PHONE)`);

  const { networkInterfaces } = require('os');
  const nets = networkInterfaces();
  console.log('\n📡 Available Network Interfaces:');
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(`   - ${name}: ${net.address}`);
      }
    }
  }
}
bootstrap();