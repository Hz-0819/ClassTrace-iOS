export interface AuthenticatedUser {
  id: string;
  roles: string[];
  sessionId: string;
}
