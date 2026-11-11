import { NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('UsersService', () => {
  let service: UsersService;
  let mockPrisma: any;

  beforeEach(() => {
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
    };
    service = new UsersService(mockPrisma as unknown as PrismaService);
  });

  describe('deleteAccount', () => {
    it('deletes user successfully when user exists', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-123' });
      mockPrisma.user.delete.mockResolvedValue({ id: 'user-123' });

      const result = await service.deleteAccount('user-123');
      expect(result.deleted).toBe(true);
      expect(mockPrisma.user.delete).toHaveBeenCalledWith({
        where: { id: 'user-123' },
      });
    });

    it('throws NotFoundException when user does not exist', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(service.deleteAccount('user-missing')).rejects.toThrow(
        NotFoundException,
      );
      expect(mockPrisma.user.delete).not.toHaveBeenCalled();
    });
  });
});
