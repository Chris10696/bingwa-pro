import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthService } from '../auth.service';
import { RegisterAgentDto } from '../dto/register-agent.dto';
import { LoginAgentDto } from '../dto/login-agent.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() registerDto: RegisterAgentDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
@HttpCode(HttpStatus.OK)
async login(@Body() loginDto: LoginAgentDto) {
  return this.authService.login(loginDto);
}
}