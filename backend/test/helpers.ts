/**
 * Outils de test : application Express réelle (routes, validation, erreurs)
 * sur un port libre, sans base de données — les accès Prisma et les services
 * sont remplacés par `stub()` (ou `mock.method`) dans chaque test.
 */
import { once } from 'node:events';
import { rmSync } from 'node:fs';
import type { AddressInfo } from 'node:net';
import { mock } from 'node:test';
import type { AuthenticatedUser } from '../src/common/types.js';

// Avant tout import de l'application : env.ts lit ces variables au chargement.
process.env.NODE_ENV ??= 'test';
// Aucune base réelle dans les tests : tout accès non simulé échoue aussitôt
// (port fermé) au lieu de lire ou d'écrire dans la base de développement.
process.env.DATABASE_URL = 'postgresql://test:test@127.0.0.1:1/korai_tests_sans_base';
process.env.AI_SERVICE_BASE_URL ??= 'http://ai.test';
// Jeton propre aux tests : jamais celui du .env de développement.
process.env.AI_SERVICE_API_KEY = 'jeton-ia-de-test';
process.env.JWT_ACCESS_SECRET ??= 'test_access_secret_0123456789abcdef';
process.env.JWT_REFRESH_SECRET ??= 'test_refresh_secret_0123456789abcdef';
// Clé et dossier propres aux tests : jamais le coffre de développement.
process.env.IMAGE_ENCRYPTION_KEY = Buffer.alloc(32, 7).toString('base64');
process.env.IMAGE_STORAGE_DIR = `${process.env.TMPDIR ?? '/tmp'}/korai-tests-images-${process.pid}`;
process.on('exit', () => rmSync(process.env.IMAGE_STORAGE_DIR!, { recursive: true, force: true }));

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

/** Accès aux dossiers accordé (ou refusé) sans interroger la base. */
export const allowAccess = async (allowed = true) => {
  const { access } = await import('../src/common/access/access-policy.js');
  stub(access, 'canSeePatient', (async () => allowed) as typeof access.canSeePatient);
  stub(access, 'canSeeConsultation', (async () => allowed) as typeof access.canSeeConsultation);
};

/** Journal d'audit en mémoire : renvoie les entrées enregistrées pendant le test. */
export const captureAudit = async () => {
  const { audit, auditDao } = await import('../src/modules/audit/audit.service.js');
  audit.resetCoalescing();
  const entries: any[] = [];
  stub(auditDao, 'create', (async (entry: any) => {
    entries.push(entry);
  }) as typeof auditDao.create);
  return entries;
};
