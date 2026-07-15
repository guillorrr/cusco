import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Role } from '@prisma/client';

/** Shape that JwtStrategy.validate() puts on the request. */
export interface AuthenticatedUser {
  id: number;
  email: string;
  role: Role;
}

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext) => {
  const { user } = ctx.switchToHttp().getRequest<{ user: AuthenticatedUser }>();
  return user;
});
