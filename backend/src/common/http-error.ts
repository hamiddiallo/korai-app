export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown
  ) {
    super(message);
  }
}

export const unauthorized = (message = 'Authentification requise') =>
  new HttpError(401, 'UNAUTHORIZED', message);

export const forbidden = (message = 'Role insuffisant pour cette action') =>
  new HttpError(403, 'FORBIDDEN', message);

export const notFound = (message = 'Ressource introuvable') =>
  new HttpError(404, 'NOT_FOUND', message);
