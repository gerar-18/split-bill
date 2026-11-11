import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, AuthenticatedUser } from '../../common/guards/auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UpsertReceiptDto } from './dto/receipt.dto';
import { ReceiptsService } from './receipts.service';

@Controller('v1/receipts')
@UseGuards(AuthGuard)
export class ReceiptsController {
  constructor(private readonly receiptsService: ReceiptsService) {}

  @Put(':id')
  @HttpCode(HttpStatus.OK)
  async upsert(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpsertReceiptDto,
  ) {
    return this.receiptsService.upsertReceipt(id, user.id, dto);
  }

  @Get()
  async list(
    @CurrentUser() user: AuthenticatedUser,
    @Query('since') since?: string,
  ) {
    return this.receiptsService.listReceipts(user.id, since);
  }

  @Get(':id')
  async get(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.receiptsService.getReceipt(id, user.id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  async delete(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.receiptsService.deleteReceipt(id, user.id);
  }
}
