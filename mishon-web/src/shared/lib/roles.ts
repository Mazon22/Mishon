export function roleRank(role?: string | null) {
  switch (role) {
    case 'Admin':
      return 2;
    case 'Moderator':
      return 1;
    default:
      return 0;
  }
}

export function hasMinimumRole(role: string | null | undefined, minimum: string) {
  return roleRank(role) >= roleRank(minimum);
}
