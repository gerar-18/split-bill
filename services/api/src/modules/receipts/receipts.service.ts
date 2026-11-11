import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpsertReceiptDto } from './dto/receipt.dto';

@Injectable()
export class ReceiptsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Reconciles monetary balance:
   * sum(item.priceCents * item.quantity) + taxCents + tipCents must equal totalCents.
   * Allows subtotal check: sum(item.priceCents * item.quantity) == subtotalCents.
   */
  validateMoneyInvariants(dto: UpsertReceiptDto): void {
    const calculatedSubtotal = dto.items.reduce(
      (sum, item) => sum + BigInt(item.priceCents) * BigInt(item.quantity),
      BigInt(0),
    );

    const expectedSubtotal = BigInt(dto.subtotalCents);
    const tax = BigInt(dto.taxCents);
    const tip = BigInt(dto.tipCents);
    const total = BigInt(dto.totalCents);

    // If receipt has items, check subtotal matches items
    if (dto.items.length > 0 && calculatedSubtotal !== expectedSubtotal) {
      throw new BadRequestException(
        `Subtotal mismatch: sum of items (${calculatedSubtotal}) does not match subtotalCents (${expectedSubtotal})`,
      );
    }

    if (expectedSubtotal + tax + tip !== total) {
      throw new BadRequestException(
        `Total mismatch: subtotal (${expectedSubtotal}) + tax (${tax}) + tip (${tip}) = ${
          expectedSubtotal + tax + tip
        }, but totalCents is ${total}`,
      );
    }
  }

  /**
   * Upsert idempotent receipt sync.
   * If the receipt already exists and incoming clientUpdatedAt <= existing clientUpdatedAt,
   * returns existing record without overwriting (Last-Write-Wins based on client timestamp).
   */
  async upsertReceipt(id: string, ownerId: string, dto: UpsertReceiptDto) {
    this.validateMoneyInvariants(dto);

    const incomingUpdatedAt = new Date(dto.clientUpdatedAt);
    const incomingCreatedAt = new Date(dto.clientCreatedAt);
    const incomingDate = new Date(dto.date);

    const existing = await this.prisma.receipt.findUnique({
      where: { id },
      include: {
        items: true,
        participants: true,
      },
    });

    if (existing) {
      if (existing.ownerId && existing.ownerId !== ownerId) {
        throw new ForbiddenException(
          'You are not authorized to update this receipt',
        );
      }

      // Guard against client overwriting an equal or newer version
      if (existing.clientUpdatedAt >= incomingUpdatedAt) {
        return existing;
      }

      // Reconcile / replace child entities transactionally
      return this.prisma.$transaction(async (tx) => {
        // Delete previous items & participants
        await tx.receiptItem.deleteMany({ where: { receiptId: id } });
        await tx.receiptParticipant.deleteMany({ where: { receiptId: id } });

        const updated = await tx.receipt.update({
          where: { id },
          data: {
            title: dto.title,
            date: incomingDate,
            currency: dto.currency,
            subtotalCents: BigInt(dto.subtotalCents),
            taxCents: BigInt(dto.taxCents),
            tipCents: BigInt(dto.tipCents),
            totalCents: BigInt(dto.totalCents),
            version: (existing.version || 1) + 1,
            clientCreatedAt: incomingCreatedAt,
            clientUpdatedAt: incomingUpdatedAt,
            syncedAt: new Date(),
            items: {
              create: dto.items.map((item) => ({
                id: item.id,
                name: item.name,
                quantity: item.quantity,
                priceCents: BigInt(item.priceCents),
              })),
            },
            participants: {
              create: dto.participants.map((p) => ({
                id: p.id,
                name: p.name,
              })),
            },
          },
          include: {
            items: true,
            participants: true,
          },
        });

        return updated;
      });
    }

    // Create new receipt
    return this.prisma.receipt.create({
      data: {
        id,
        ownerId,
        title: dto.title,
        date: incomingDate,
        currency: dto.currency,
        subtotalCents: BigInt(dto.subtotalCents),
        taxCents: BigInt(dto.taxCents),
        tipCents: BigInt(dto.tipCents),
        totalCents: BigInt(dto.totalCents),
        version: dto.version || 1,
        clientCreatedAt: incomingCreatedAt,
        clientUpdatedAt: incomingUpdatedAt,
        syncedAt: new Date(),
        items: {
          create: dto.items.map((item) => ({
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            priceCents: BigInt(item.priceCents),
          })),
        },
        participants: {
          create: dto.participants.map((p) => ({
            id: p.id,
            name: p.name,
          })),
        },
      },
      include: {
        items: true,
        participants: true,
      },
    });
  }

  async listReceipts(ownerId: string, since?: string) {
    const where: { ownerId: string; clientUpdatedAt?: { gt: Date } } = {
      ownerId,
    };

    if (since) {
      where.clientUpdatedAt = { gt: new Date(since) };
    }

    return this.prisma.receipt.findMany({
      where,
      orderBy: { clientUpdatedAt: 'desc' },
      include: {
        items: true,
        participants: true,
      },
    });
  }

  async getReceipt(id: string, ownerId: string) {
    const receipt = await this.prisma.receipt.findFirst({
      where: { id, ownerId },
      include: {
        items: true,
        participants: true,
      },
    });

    if (!receipt) {
      throw new NotFoundException(`Receipt ${id} not found`);
    }

    return receipt;
  }

  async deleteReceipt(id: string, ownerId: string) {
    const receipt = await this.prisma.receipt.findFirst({
      where: { id, ownerId },
    });

    if (!receipt) {
      throw new NotFoundException(`Receipt ${id} not found`);
    }

    await this.prisma.receipt.delete({
      where: { id },
    });

    return {
      deleted: true,
      id,
    };
  }
}
