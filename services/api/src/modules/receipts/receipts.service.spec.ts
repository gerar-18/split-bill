import { BadRequestException, NotFoundException } from '@nestjs/common';
import { UpsertReceiptDto } from './dto/receipt.dto';
import { ReceiptsService } from './receipts.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('ReceiptsService', () => {
  let service: ReceiptsService;
  let mockPrisma: any;

  beforeEach(() => {
    mockPrisma = {
      receipt: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
        delete: jest.fn(),
      },
      receiptItem: {
        deleteMany: jest.fn(),
      },
      receiptParticipant: {
        deleteMany: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(mockPrisma)),
    };
    service = new ReceiptsService(mockPrisma as unknown as PrismaService);
  });

  describe('validateMoneyInvariants', () => {
    it('passes when sum(items.price * quantity) == subtotal and subtotal + tax + tip == total', () => {
      const dto: UpsertReceiptDto = {
        title: 'Dinner',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: 5000,
        taxCents: 500,
        tipCents: 1000,
        totalCents: 6500,
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [
          {
            id: 'b149b1a0-1234-4567-89ab-cdef01234567',
            name: 'Pizza',
            quantity: 2,
            priceCents: 2000,
          },
          {
            id: 'b149b1a0-1234-4567-89ab-cdef01234568',
            name: 'Soda',
            quantity: 1,
            priceCents: 1000,
          },
        ],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).not.toThrow();
    });

    it('passes for empty items receipt if subtotal + tax + tip == total', () => {
      const dto: UpsertReceiptDto = {
        title: 'Quick Total Entry',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: 1000,
        taxCents: 100,
        tipCents: 200,
        totalCents: 1300,
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).not.toThrow();
    });

    it('throws BadRequestException when sum of items != subtotal', () => {
      const dto: UpsertReceiptDto = {
        title: 'Mismatch Subtotal',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: 4000, // actual items sum: 2 * 2000 = 4000, wait, let's mismatch
        taxCents: 0,
        tipCents: 0,
        totalCents: 4000,
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [
          {
            id: 'b149b1a0-1234-4567-89ab-cdef01234567',
            name: 'Pizza',
            quantity: 2,
            priceCents: 1500, // 3000 != 4000
          },
        ],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).toThrow(
        BadRequestException,
      );
      expect(() => service.validateMoneyInvariants(dto)).toThrow(/Subtotal mismatch/);
    });

    it('throws BadRequestException when subtotal + tax + tip != total', () => {
      const dto: UpsertReceiptDto = {
        title: 'Mismatch Total',
        date: '2026-11-11T12:00:00Z',
        currency: 'USD',
        subtotalCents: 3000,
        taxCents: 300,
        tipCents: 300,
        totalCents: 3700, // Expected 3600
        clientCreatedAt: '2026-11-11T12:00:00Z',
        clientUpdatedAt: '2026-11-11T12:00:00Z',
        items: [
          {
            id: 'b149b1a0-1234-4567-89ab-cdef01234567',
            name: 'Pasta',
            quantity: 1,
            priceCents: 3000,
          },
        ],
        participants: [],
      };

      expect(() => service.validateMoneyInvariants(dto)).toThrow(
        BadRequestException,
      );
      expect(() => service.validateMoneyInvariants(dto)).toThrow(/Total mismatch/);
    });
  });

  describe('upsertReceipt', () => {
    const receiptId = 'a123b456-c789-0123-4567-89abcdef0123';
    const ownerId = 'user-owner-1';
    const validDto: UpsertReceiptDto = {
      title: 'Tacos Dinner',
      date: '2026-11-11T12:00:00.000Z',
      currency: 'MXN',
      subtotalCents: 2000,
      taxCents: 320,
      tipCents: 200,
      totalCents: 2520,
      version: 1,
      clientCreatedAt: '2026-11-11T12:00:00.000Z',
      clientUpdatedAt: '2026-11-11T12:00:00.000Z',
      items: [
        {
          id: 'b149b1a0-1234-4567-89ab-cdef01234567',
          name: 'Pastor',
          quantity: 2,
          priceCents: 1000,
        },
      ],
      participants: [
        {
          id: 'c149b1a0-1234-4567-89ab-cdef01234567',
          name: 'Juan',
        },
      ],
    };

    it('creates new receipt when not existing', async () => {
      mockPrisma.receipt.findUnique.mockResolvedValue(null);
      mockPrisma.receipt.create.mockResolvedValue({ id: receiptId, ...validDto });

      const result = await service.upsertReceipt(receiptId, ownerId, validDto);

      expect(mockPrisma.receipt.findUnique).toHaveBeenCalledWith({
        where: { id: receiptId },
        include: { items: true, participants: true },
      });
      expect(mockPrisma.receipt.create).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    it('returns existing without overwrite if incoming clientUpdatedAt <= existing (LWW conflict resolution)', async () => {
      const existingReceipt = {
        id: receiptId,
        ownerId,
        clientUpdatedAt: new Date('2026-11-11T12:10:00.000Z'), // newer
        version: 2,
      };
      mockPrisma.receipt.findUnique.mockResolvedValue(existingReceipt);

      // Incoming DTO has older timestamp (12:00:00)
      const result = await service.upsertReceipt(receiptId, ownerId, validDto);

      expect(result).toBe(existingReceipt);
      expect(mockPrisma.receipt.update).not.toHaveBeenCalled();
    });

    it('updates receipt transactionally when incoming clientUpdatedAt > existing', async () => {
      const existingReceipt = {
        id: receiptId,
        ownerId,
        clientUpdatedAt: new Date('2026-11-11T11:50:00.000Z'), // older
        version: 1,
      };
      mockPrisma.receipt.findUnique.mockResolvedValue(existingReceipt);
      mockPrisma.receipt.update.mockResolvedValue({
        id: receiptId,
        ...validDto,
        version: 2,
      });

      const result = await service.upsertReceipt(receiptId, ownerId, validDto);

      expect(mockPrisma.receiptItem.deleteMany).toHaveBeenCalledWith({
        where: { receiptId },
      });
      expect(mockPrisma.receiptParticipant.deleteMany).toHaveBeenCalledWith({
        where: { receiptId },
      });
      expect(mockPrisma.receipt.update).toHaveBeenCalled();
      expect(result.version).toBe(2);
    });
  });

  describe('listReceipts, getReceipt & deleteReceipt', () => {
    it('lists receipts by owner and optionally filters by since date', async () => {
      mockPrisma.receipt.findMany.mockResolvedValue([]);
      await service.listReceipts('owner-1', '2026-11-10T00:00:00Z');

      expect(mockPrisma.receipt.findMany).toHaveBeenCalledWith({
        where: {
          ownerId: 'owner-1',
          clientUpdatedAt: { gt: new Date('2026-11-10T00:00:00Z') },
        },
        orderBy: { clientUpdatedAt: 'desc' },
        include: { items: true, participants: true },
      });
    });

    it('gets a single receipt or throws NotFoundException', async () => {
      mockPrisma.receipt.findFirst.mockResolvedValue(null);
      await expect(service.getReceipt('non-existent', 'owner-1')).rejects.toThrow(
        NotFoundException,
      );

      mockPrisma.receipt.findFirst.mockResolvedValue({ id: 'exists' });
      const found = await service.getReceipt('exists', 'owner-1');
      expect(found).toEqual({ id: 'exists' });
    });

    it('deletes receipt if owner matches or throws NotFoundException', async () => {
      mockPrisma.receipt.findFirst.mockResolvedValue(null);
      await expect(service.deleteReceipt('receipt-1', 'owner-1')).rejects.toThrow(
        NotFoundException,
      );

      mockPrisma.receipt.findFirst.mockResolvedValue({ id: 'receipt-1' });
      mockPrisma.receipt.delete.mockResolvedValue({ id: 'receipt-1' });

      const res = await service.deleteReceipt('receipt-1', 'owner-1');
      expect(res).toEqual({ deleted: true, id: 'receipt-1' });
      expect(mockPrisma.receipt.delete).toHaveBeenCalledWith({
        where: { id: 'receipt-1' },
      });
    });
  });
});
