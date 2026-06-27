// bingwa-pro-backend/src/app-update/app-update.controller.ts
// W5.H — public version check. Intentionally unauthenticated: the app may check for updates
// before login, and it returns only public version metadata.
import { Controller, Get } from '@nestjs/common';
import { AppUpdateService } from './app-update.service';

@Controller('app-update')
export class AppUpdateController {
  constructor(private readonly service: AppUpdateService) {}

  @Get('latest')
  getLatest() {
    return this.service.getLatest();
  }
}
