import { Controller, Delete, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthGuard, AuthenticatedUser } from '../../common/guards/auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from './users.service';

@Controller('v1/users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Delete('me')
  @HttpCode(HttpStatus.OK)
  async deleteMe(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.deleteAccount(user.id);
  }
}
