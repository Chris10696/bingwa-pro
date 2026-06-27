// bingwa-pro-backend/src/app-update/app-update.service.ts
// W5.H — version metadata for the in-app updater (Hybrid AppUpdateRepository.checkForUpdates).
// The APK itself is hosted on YOUR deployment (D-W5-3); this endpoint just advertises the
// latest version + where to download it, driven by env so you bump it when you publish.
// Defaults advertise the current shipping version (1.0.0+1) → "up to date" until you set them.
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AppUpdateService {
  constructor(private readonly config: ConfigService) {}

  getLatest() {
    return {
      latestVersion: this.config.get<string>('APP_UPDATE_VERSION') ?? '1.0.0',
      latestVersionCode: parseInt(
        this.config.get<string>('APP_UPDATE_VERSION_CODE') ?? '1',
        10,
      ),
      // Points at your APK host; empty until configured (client treats empty as "no download").
      apkUrl: this.config.get<string>('APP_UPDATE_APK_URL') ?? '',
      releaseNotes: this.config.get<string>('APP_UPDATE_NOTES') ?? '',
      forced: (this.config.get<string>('APP_UPDATE_FORCED') ?? 'false') === 'true',
    };
  }
}
