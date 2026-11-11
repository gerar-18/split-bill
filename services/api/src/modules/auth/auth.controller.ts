import { Body, Controller, Post, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AppleAuthDto, DevAuthDto } from './dto/auth.dto';

@Controller('v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('apple')
  @HttpCode(HttpStatus.OK)
  async loginApple(@Body() dto: AppleAuthDto) {
    return this.authService.authenticateApple(dto);
  }

  @Post('dev')
  @HttpCode(HttpStatus.OK)
  async loginDev(@Body() dto: DevAuthDto) {
    return this.authService.authenticateDev(dto);
  }
}
