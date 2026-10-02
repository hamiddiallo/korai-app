/**
 * Outils de test : application Express réelle (routes, validation, erreurs)
 * sur un port libre, sans base de données — les accès Prisma et les services
 * sont remplacés par `mock.method` dans chaque test.
 */
import { once } from 'node:events';
import type { AddressInfo } from 'node:net';
import { mock } from 'node:test';
import type { AuthenticatedUser } from '../src/common/types.js';

// Avant tout import de l'application : env.ts lit ces variables au chargement.
process.env.NODE_ENV ??= 'test';
process.env.AI_SERVICE_BASE_URL ??= 'http://ai.test';
process.env.JWT_ACCESS_SECRET ??= 'test_access_secret_0123456789abcdef';
process.env.JWT_REFRESH_SECRET ??= 'test_refresh_secret_0123456789abcdef';

export type TestApp = {
  url: string;
  request: (method: string, path: string, body?: unknown, token?: string) => Promise<{ status: number; body: any }>;
  close: () => Promise<void>;
};

export const startTestApp = async (): Promise<TestApp> => {
  const { createApp } = await import('../src/app.js');
  const server = createApp().listen(0);
  await once(server, 'listening');
  const { port } = server.address() as AddressInfo;
  const url = `http://127.0.0.1:${port}`;
  return {
    url,
    async request(method, path, body, token = 'jeton-de-test') {
      const res = await fetch(`${url}${path}`, {
        method,
        headers: {
          'content-type': 'application/json',
          ...(token ? { authorization: `Bearer ${token}` } : {})
        },
        body: body === undefined ? undefined : JSON.stringify(body)
      });
      const text = await res.text();
      return { status: res.status, body: text ? JSON.parse(text) : undefined };
    },
    close: () => new Promise<void>((resolve) => server.close(() => resolve()))
  };
};

export const makeUser = (overrides: Partial<AuthenticatedUser> = {}): AuthenticatedUser => ({
  id: 'user-1',
  fullName: 'Utilisateur Test',
  email: 'test@korai.test',
  role: 'NURSE',
  accountStatus: 'ACTIVE',
  createdAt: new Date(0).toISOString(),
  ...overrides
});

/** Toute requête authentifiée est faite au nom de `user`. */
export const signInAs = async (user: AuthenticatedUser) => {
  const { authService } = await import('../src/modules/auth/auth.service.js');
  mock.method(authService, 'resolveAuthenticatedUser', async () => user);
};

const stubs: Array<() => void> = [];

/**
 * Remplace une méthode (délégués Prisma compris, que `mock.method` gère mal)
 * et la restaure avec `restoreStubs()`.
 */
export const stub = <T extends object, K extends keyof T>(target: T, key: K, impl: T[K]) => {
  const original = target[key];
  (target as any)[key] = impl;
  stubs.push(() => {
    (target as any)[key] = original;
  });
};

export const restoreStubs = () => {
  while (stubs.length) stubs.pop()!();
  mock.restoreAll();
};
