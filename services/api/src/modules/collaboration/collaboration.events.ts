import { Injectable, MessageEvent } from '@nestjs/common';
import { Observable, Subject, finalize, map } from 'rxjs';

export interface CollaborationStreamEvent {
  shareCode: string;
  version: number;
  status: 'ACTIVE' | 'CLOSED' | 'QUARANTINED';
  eventType: 'snapshot_updated' | 'session_closed' | 'session_quarantined';
}

@Injectable()
export class CollaborationEventsService {
  private readonly channels = new Map<
    string,
    { subject: Subject<CollaborationStreamEvent>; subscriberCount: number }
  >();

  subscribe(shareCode: string): Observable<MessageEvent> {
    let channel = this.channels.get(shareCode);
    if (!channel) {
      channel = {
        subject: new Subject<CollaborationStreamEvent>(),
        subscriberCount: 0,
      };
      this.channels.set(shareCode, channel);
    }
    channel.subscriberCount += 1;

    return channel.subject.asObservable().pipe(
      map(
        (payload): MessageEvent => ({
          type: payload.eventType,
          id: String(payload.version),
          data: payload,
        }),
      ),
      finalize(() => {
        const current = this.channels.get(shareCode);
        if (!current) return;
        current.subscriberCount -= 1;
        if (current.subscriberCount <= 0 && current.subject.closed) {
          this.channels.delete(shareCode);
        } else if (current.subscriberCount <= 0) {
          current.subject.complete();
          this.channels.delete(shareCode);
        }
      }),
    );
  }

  emit(shareCode: string, payload: CollaborationStreamEvent): void {
    const channel = this.channels.get(shareCode);
    if (!channel) return;
    channel.subject.next(payload);
    if (
      payload.eventType === 'session_closed' ||
      payload.eventType === 'session_quarantined'
    ) {
      channel.subject.complete();
      this.channels.delete(shareCode);
    }
  }
}
