import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Enable CORS for mobile app
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });
  
  const port = process.env.PORT ?? 3000;
  
  // Listen on all network interfaces
  await app.listen(port, '0.0.0.0');
  
  // FORCE the Wi-Fi IP (192.168.100.8) for network access
  const wifiIp = '192.168.100.8';
  
  console.log(`🚀 Backend running at:`);
  console.log(`   - Local: http://localhost:${port}`);
  console.log(`   - Wi-Fi Network: http://${wifiIp}:${port} (USE THIS FOR PHONE)`);
  console.log(`   - vEthernet: http://172.27.128.1:${port}`);
  console.log(`   - Ethernet 4: http://10.40.63.223:${port}`);
  
  // Log all available network interfaces for debugging
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