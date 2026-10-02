import { HttpError } from '../errors/http-error.js';
import type { Role } from '../types.js';

type PatientConsents = { consentForAi: boolean; consentForTeleExpertise: boolean };

/**
 * Accords du patient, vérifiés par le serveur avant tout envoi de ses données :
 *   - AI : analyse par le service d'IA externe ;
 *   - TELE_EXPERTISE : partage du dossier avec les spécialistes.
 */
export const assertConsent = (patient: PatientConsents, kind: 'AI' | 'TELE_EXPERTISE', viewerRole: Role) => {
  const self = viewerRole === 'PATIENT';
  if (kind === 'AI' && !patient.consentForAi) {
    throw new HttpError(
      403,
      'CONSENT_AI_REQUIRED',
      self
        ? 'Vous n’avez pas autorisé l’analyse par l’IA. Activez cet accord dans votre profil pour envoyer votre pré-consultation.'
        : 'Le patient n’a pas donné son accord pour l’analyse par l’IA. Recueillez son accord et enregistrez-le dans son dossier avant de lancer l’analyse.'
    );
  }
  if (kind === 'TELE_EXPERTISE' && !patient.consentForTeleExpertise) {
    throw new HttpError(
      403,
      'CONSENT_TELEEXPERTISE_REQUIRED',
      self
        ? 'Vous n’avez pas autorisé le partage de votre dossier avec un spécialiste. Activez cet accord dans votre profil.'
        : 'Le patient n’a pas donné son accord pour la télé-expertise. Recueillez son accord et enregistrez-le dans son dossier avant de demander l’avis d’un spécialiste.'
    );
  }
};
