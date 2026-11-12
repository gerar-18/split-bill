import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthGuard, AuthenticatedUser } from '../../common/guards/auth.guard';
import { AiProxyService } from './ai-proxy.service';
import {
  ParseAiReceiptRequestDto,
  ParseAiReceiptResponseDto,
} from './dto/parse-ai-receipt.dto';
import { AiRateLimitGuard } from './guards/ai-rate-limit.guard';

@Controller('v1/receipts')
@UseGuards(AuthGuard, AiRateLimitGuard)
export class AiProxyController {
  constructor(private readonly aiProxyService: AiProxyService) {}

  @Post('parse-ai')
  @HttpCode(HttpStatus.OK)
  async parseAi(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ParseAiReceiptRequestDto,
  ): Promise<ParseAiReceiptResponseDto> {
    return this.aiProxyService.parseReceipt(dto, user?.id);
  }
}
