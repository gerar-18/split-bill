import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    // Prisma schema defines onDelete: Cascade on user -> receipts -> items/participants
    await this.prisma.user.delete({
      where: { id: userId },
    });

    return {
      deleted: true,
      userId,
      message: 'User account and all associated data deleted successfully',
    };
  }
}
