import { Injectable, MessageEvent } from '@nestjs/common';
import { Observable, Subject, concat, finalize, map, of } from 'rxjs';

export interface CollaborationStreamEvent {
  shareCode: string;
  version: number;
  status: 'ACTIVE' | 'CLOSED' | 'QUARANTINED';
  eventType: 'snapshot_updated' | 'session_closed' | 'session_quarantined';
}

interface ChannelEntry {
  subject: Subject<CollaborationStreamEvent>;
  subscriberCount: number;
}

@Injectable()
export class CollaborationEventsService {
  private readonly channels = new Map<string, ChannelEntry>();

  subscribe(
    shareCode: string,
    initialEvent?: CollaborationStreamEvent,
  ): Observable<MessageEvent> {
    if (
      initialEvent &&
      (initialEvent.eventType === 'session_closed' ||
        initialEvent.eventType === 'session_quarantined')
    ) {
      return of(this.toMessageEvent(initialEvent));
    }

    let channel = this.channels.get(shareCode);
    if (!channel) {
      channel = {
        subject: new Subject<CollaborationStreamEvent>(),
        subscriberCount: 0,
      };
      this.channels.set(shareCode, channel);
    }
    const boundChannel = channel;
    boundChannel.subscriberCount += 1;

    const liveStream$ = boundChannel.subject.asObservable().pipe(
      map((payload) => this.toMessageEvent(payload)),
      finalize(() => {
        boundChannel.subscriberCount -= 1;
        // Verify map still points to THIS exact channel instance to avoid tearing down a newer channel
        if (
          boundChannel.subscriberCount <= 0 &&
          this.channels.get(shareCode) === boundChannel
        ) {
          this.channels.delete(shareCode);
          if (!boundChannel.subject.closed) {
            boundChannel.subject.complete();
          }
        }
      }),
    );

    if (initialEvent) {
      return concat(of(this.toMessageEvent(initialEvent)), liveStream$);
    }
    return liveStream$;
  }

  emit(shareCode: string, payload: CollaborationStreamEvent): void {
    const channel = this.channels.get(shareCode);
    if (!channel) return;
    channel.subject.next(payload);
    if (
      payload.eventType === 'session_closed' ||
      payload.eventType === 'session_quarantined'
    ) {
      this.channels.delete(shareCode);
      if (!channel.subject.closed) {
        channel.subject.complete();
      }
    }
  }

  private toMessageEvent(payload: CollaborationStreamEvent): MessageEvent {
    return {
      type: payload.eventType,
      id: String(payload.version),
      data: payload,
    };
  }
}
