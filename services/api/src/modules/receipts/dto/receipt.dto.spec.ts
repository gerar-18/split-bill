import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import {
  UpsertReceiptDto,
  ReceiptItemDto,
  ReceiptParticipantDto,
} from './receipt.dto';

describe('Receipt DTO Validation (ValidationPipe rules)', () => {
  const getValidReceiptPayload = () => ({
    title: 'Dinner at Taco Place',
    date: '2026-11-11T12:00:00.000Z',
    currency: 'USD',
    subtotalCents: 3000,
    taxCents: 300,
    tipCents: 450,
    totalCents: 3750,
    version: 1,
    clientCreatedAt: '2026-11-11T12:00:00.000Z',
    clientUpdatedAt: '2026-11-11T12:05:00.000Z',
    items: [
      {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Tacos al Pastor',
        quantity: 2,
        priceCents: 1500,
      },
    ],
    participants: [
      {
        id: '223e4567-e89b-12d3-a456-426614174001',
        name: 'Alice',
      },
    ],
  });

  describe('UpsertReceiptDto', () => {
    it('passes validation with completely valid payload', async () => {
      const payload = getValidReceiptPayload();
      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);
      expect(errors.length).toBe(0);
    });

    it('rejects missing required fields (title, date, currency, timestamps)', async () => {
      const dto = plainToInstance(UpsertReceiptDto, {});
      const errors = await validate(dto);

      const errorProperties = errors.map((e) => e.property);
      expect(errorProperties).toContain('title');
      expect(errorProperties).toContain('date');
      expect(errorProperties).toContain('currency');
      expect(errorProperties).toContain('subtotalCents');
      expect(errorProperties).toContain('taxCents');
      expect(errorProperties).toContain('tipCents');
      expect(errorProperties).toContain('totalCents');
      expect(errorProperties).toContain('clientCreatedAt');
      expect(errorProperties).toContain('clientUpdatedAt');
      expect(errorProperties).toContain('items');
      expect(errorProperties).toContain('participants');
    });

    it('rejects negative monetary amounts (subtotalCents, taxCents, tipCents, totalCents)', async () => {
      const payload = {
        ...getValidReceiptPayload(),
        subtotalCents: -100,
        taxCents: -10,
        tipCents: -50,
        totalCents: -160,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);

      const subtotalErr = errors.find((e) => e.property === 'subtotalCents');
      const taxErr = errors.find((e) => e.property === 'taxCents');
      const tipErr = errors.find((e) => e.property === 'tipCents');
      const totalErr = errors.find((e) => e.property === 'totalCents');

      expect(subtotalErr?.constraints?.min).toBeDefined();
      expect(taxErr?.constraints?.min).toBeDefined();
      expect(tipErr?.constraints?.min).toBeDefined();
      expect(totalErr?.constraints?.min).toBeDefined();
    });

    it('rejects floating point amounts in money fields', async () => {
      const payload = {
        ...getValidReceiptPayload(),
        subtotalCents: 10.55,
        taxCents: 1.05,
        tipCents: 2.5,
        totalCents: 14.1,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);

      expect(errors.find((e) => e.property === 'subtotalCents')?.constraints?.isInt).toBeDefined();
      expect(errors.find((e) => e.property === 'taxCents')?.constraints?.isInt).toBeDefined();
      expect(errors.find((e) => e.property === 'tipCents')?.constraints?.isInt).toBeDefined();
      expect(errors.find((e) => e.property === 'totalCents')?.constraints?.isInt).toBeDefined();
    });

    it('rejects invalid ISO-8601 date strings', async () => {
      const payload = {
        ...getValidReceiptPayload(),
        date: 'not-a-date',
        clientCreatedAt: '2026/11/11 12:00',
        clientUpdatedAt: 'yesterday',
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);

      expect(errors.find((e) => e.property === 'date')?.constraints?.isDateString).toBeDefined();
      expect(errors.find((e) => e.property === 'clientCreatedAt')?.constraints?.isDateString).toBeDefined();
      expect(errors.find((e) => e.property === 'clientUpdatedAt')?.constraints?.isDateString).toBeDefined();
    });

    it('rejects non-array items or participants', async () => {
      const payload = {
        ...getValidReceiptPayload(),
        items: 'invalid-items-type' as any,
        participants: 12345 as any,
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);

      expect(errors.find((e) => e.property === 'items')?.constraints?.isArray).toBeDefined();
      expect(errors.find((e) => e.property === 'participants')?.constraints?.isArray).toBeDefined();
    });

    it('validates nested items and participants', async () => {
      const payload = {
        ...getValidReceiptPayload(),
        items: [
          {
            id: 'invalid-uuid',
            name: '',
            quantity: 0,
            priceCents: -50,
          },
        ],
        participants: [
          {
            id: 'not-a-uuid',
            name: '',
          },
        ],
      };

      const dto = plainToInstance(UpsertReceiptDto, payload);
      const errors = await validate(dto);

      const itemsError = errors.find((e) => e.property === 'items');
      const participantsError = errors.find((e) => e.property === 'participants');

      expect(itemsError?.children?.length).toBeGreaterThan(0);
      expect(participantsError?.children?.length).toBeGreaterThan(0);
    });
  });

  describe('ReceiptItemDto', () => {
    it('accepts valid item DTO', async () => {
      const item = plainToInstance(ReceiptItemDto, {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Guacamole',
        quantity: 1,
        priceCents: 850,
      });

      const errors = await validate(item);
      expect(errors.length).toBe(0);
    });

    it('rejects quantity < 1 and floats in quantity or priceCents', async () => {
      const item = plainToInstance(ReceiptItemDto, {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Guacamole',
        quantity: 0,
        priceCents: 850.5,
      });

      const errors = await validate(item);
      expect(errors.find((e) => e.property === 'quantity')?.constraints?.min).toBeDefined();
      expect(errors.find((e) => e.property === 'priceCents')?.constraints?.isInt).toBeDefined();
    });

    it('rejects negative priceCents', async () => {
      const item = plainToInstance(ReceiptItemDto, {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Guacamole',
        quantity: 1,
        priceCents: -1,
      });

      const errors = await validate(item);
      expect(errors.find((e) => e.property === 'priceCents')?.constraints?.min).toBeDefined();
    });

    it('rejects invalid UUID in id', async () => {
      const item = plainToInstance(ReceiptItemDto, {
        id: '12345',
        name: 'Guacamole',
        quantity: 1,
        priceCents: 500,
      });

      const errors = await validate(item);
      expect(errors.find((e) => e.property === 'id')?.constraints?.isUuid).toBeDefined();
    });
  });

  describe('ReceiptParticipantDto', () => {
    it('accepts valid participant', async () => {
      const participant = plainToInstance(ReceiptParticipantDto, {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Bob',
      });

      const errors = await validate(participant);
      expect(errors.length).toBe(0);
    });

    it('rejects empty name and non-UUID id', async () => {
      const participant = plainToInstance(ReceiptParticipantDto, {
        id: 'not-uuid',
        name: '',
      });

      const errors = await validate(participant);
      expect(errors.find((e) => e.property === 'id')?.constraints?.isUuid).toBeDefined();
      expect(errors.find((e) => e.property === 'name')?.constraints?.isNotEmpty).toBeDefined();
    });
  });
});
