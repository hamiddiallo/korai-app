import { createCipheriv, createDecipheriv, randomBytes, randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../../config/env.js';
import { HttpError } from '../../common/errors/http-error.js';

/**
 * Coffre des photos du tympan : chaque photo est chiffrée (AES-256-GCM) dans
 * son propre fichier, nommé par un identifiant aléatoire (aucune information
 * sur le patient). L'identifiant sert aussi de donnée authentifiée : un
 * fichier déplacé ou modifié ne se déchiffre plus.
 *
 * Format : [1 octet version][12 octets IV][16 octets tag][photo chiffrée]
 */
const FORMAT_VERSION = 1;
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const STORAGE_KEY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const key = () => Buffer.from(env.IMAGE_ENCRYPTION_KEY, 'base64');
const directory = () => path.resolve(env.IMAGE_STORAGE_DIR);

/** Chemin d'un fichier du coffre ; refuse tout identifiant qui ne serait pas un UUID (pas de « ../ »). */
const fileFor = (storageKey: string) => {
  if (!STORAGE_KEY.test(storageKey)) {
    throw new HttpError(500, 'IMAGE_STORAGE_ERROR', 'Identifiant de photo invalide.');
  }
  return path.join(directory(), `${storageKey}.enc`);
};

export const encryptImage = (bytes: Buffer, storageKey: string, secret = key()) => {
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv('aes-256-gcm', secret, iv);
  cipher.setAAD(Buffer.from(storageKey));
  const encrypted = Buffer.concat([cipher.update(bytes), cipher.final()]);
  return Buffer.concat([Buffer.from([FORMAT_VERSION]), iv, cipher.getAuthTag(), encrypted]);
};

export const decryptImage = (stored: Buffer, storageKey: string, secret = key()) => {
  if (stored.length < 1 + IV_LENGTH + TAG_LENGTH || stored[0] !== FORMAT_VERSION) {
    throw new HttpError(500, 'IMAGE_STORAGE_ERROR', 'Photo stockée illisible.');
  }
  const iv = stored.subarray(1, 1 + IV_LENGTH);
  const tag = stored.subarray(1 + IV_LENGTH, 1 + IV_LENGTH + TAG_LENGTH);
  const decipher = createDecipheriv('aes-256-gcm', secret, iv);
  decipher.setAAD(Buffer.from(storageKey));
  decipher.setAuthTag(tag);
  try {
    return Buffer.concat([decipher.update(stored.subarray(1 + IV_LENGTH + TAG_LENGTH)), decipher.final()]);
  } catch {
    // Mauvaise clé, fichier modifié ou échangé avec un autre.
    throw new HttpError(500, 'IMAGE_STORAGE_ERROR', 'Photo stockée illisible.');
  }
};

export const imageVault = {
  /** Chiffre et enregistre une photo ; renvoie son identifiant de stockage. */
  async save(bytes: Buffer): Promise<string> {
    const storageKey = randomUUID();
    const target = fileFor(storageKey);
    await mkdir(directory(), { recursive: true, mode: 0o700 });
    // Écriture atomique : jamais de fichier à moitié écrit sous le nom final.
    const temporary = `${target}.${process.pid}.tmp`;
    await writeFile(temporary, encryptImage(bytes, storageKey), { mode: 0o600 });
    await rename(temporary, target);
    return storageKey;
  },

  async read(storageKey: string): Promise<Buffer> {
    let stored: Buffer;
    try {
      stored = await readFile(fileFor(storageKey));
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(404, 'IMAGE_NOT_FOUND', 'Photo introuvable sur le serveur.');
    }
    return decryptImage(stored, storageKey);
  }
};

/** Vérifie la signature du fichier : une photo JPEG, PNG ou WebP, pas un autre contenu renommé. */
export const looksLikeImage = (bytes: Buffer, mimetype: string) => {
  if (mimetype === 'image/jpeg') return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (mimetype === 'image/png') {
    return bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  }
  if (mimetype === 'image/webp') {
    return bytes.length > 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP';
  }
  return false;
};
