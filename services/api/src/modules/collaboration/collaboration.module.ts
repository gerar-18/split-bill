import { Module } from '@nestjs/common';
import { ReceiptsModule } from '../receipts/receipts.module';
import { CollaborationController } from './collaboration.controller';
import { CollaborationEventsService } from './collaboration.events';
import { CollaborationService } from './collaboration.service';
import { CollaborationRateLimitGuard } from './guards/collaboration-rate-limit.guard';
import { SessionTokenGuard } from './guards/session-token.guard';

@Module({
  imports: [ReceiptsModule],
  controllers: [CollaborationController],
  providers: [
    CollaborationService,
    CollaborationEventsService,
    SessionTokenGuard,
    CollaborationRateLimitGuard,
  ],
  exports: [CollaborationService],
})
export class CollaborationModule {}
