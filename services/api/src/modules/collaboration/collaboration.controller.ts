import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  MessageEvent,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
  Sse,
  UseGuards,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import {
  CreateSharedSessionDto,
  JoinSharedSessionDto,
  ReportSessionDto,
  ToggleClaimDto,
} from './dto/collaboration.dto';
import {
  CollabRateLimit,
  CollaborationRateLimitGuard,
} from './guards/collaboration-rate-limit.guard';
import {
  CollaborationActor,
  SessionTokenGuard,
} from './guards/session-token.guard';
import { CollaborationService } from './collaboration.service';

@Controller('v1/shared-sessions')
@UseGuards(CollaborationRateLimitGuard)
export class CollaborationController {
  constructor(private readonly collaborationService: CollaborationService) {}

  @Post()
  @CollabRateLimit(15)
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateSharedSessionDto, @Req() req: any) {
    const ownerId: string | undefined = req.user?.id;
    return this.collaborationService.createSession(dto, ownerId);
  }

  @Post(':code/join')
  @CollabRateLimit(10)
  @HttpCode(HttpStatus.OK)
  async join(
    @Param('code') code: string,
    @Body() dto: JoinSharedSessionDto,
  ) {
    return this.collaborationService.joinSession(code, dto);
  }

  @Get(':code')
  @UseGuards(SessionTokenGuard)
  async getSnapshot(
    @Param('code') code: string,
    @Query('sinceVersion', new ParseIntPipe({ optional: true }))
    sinceVersion?: number,
  ) {
    return this.collaborationService.getSnapshot(code, sinceVersion);
  }

  @Sse(':code/events')
  @UseGuards(SessionTokenGuard)
  streamEvents(@Param('code') code: string): Promise<Observable<MessageEvent>> {
    return this.collaborationService.subscribeToEvents(code);
  }

  @Post(':code/claims')
  @UseGuards(SessionTokenGuard)
  @CollabRateLimit(60)
  @HttpCode(HttpStatus.OK)
  async toggleClaim(
    @Param('code') code: string,
    @Body() dto: ToggleClaimDto,
    @Req() req: { collaborationActor: CollaborationActor },
  ) {
    return this.collaborationService.toggleClaim(
      code,
      req.collaborationActor,
      dto,
    );
  }

  @Post(':code/reports')
  @UseGuards(SessionTokenGuard)
  @CollabRateLimit(10)
  @HttpCode(HttpStatus.OK)
  async report(
    @Param('code') code: string,
    @Body() dto: ReportSessionDto,
    @Req() req: { collaborationActor: CollaborationActor },
  ) {
    return this.collaborationService.reportSession(
      code,
      req.collaborationActor,
      dto,
    );
  }

  @Post(':code/leave')
  @UseGuards(SessionTokenGuard)
  @HttpCode(HttpStatus.OK)
  async leave(
    @Param('code') code: string,
    @Req() req: { collaborationActor: CollaborationActor },
  ) {
    return this.collaborationService.leaveSession(code, req.collaborationActor);
  }

  @Delete(':code')
  @UseGuards(SessionTokenGuard)
  @HttpCode(HttpStatus.OK)
  async close(
    @Param('code') code: string,
    @Req() req: { collaborationActor: CollaborationActor },
  ) {
    return this.collaborationService.closeSession(code, req.collaborationActor);
  }
}
