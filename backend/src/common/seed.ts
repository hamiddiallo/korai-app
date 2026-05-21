import { userDao } from '../modules/users/user.dao.js';
import { clinicalReferenceDao } from '../modules/clinical-reference/clinical-reference.dao.js';

const CLINICAL_ITEMS_TO_SEED = [
  { type: 'SYMPTOM' as const, label: 'Otalgie', description: "Douleur à l'oreille, pouvant être d'origine interne ou irradiée.", sortOrder: 10 },
  { type: 'SYMPTOM' as const, label: 'Otorrhée', description: "Écoulement de liquide (clair, purulent ou sanguin) provenant du conduit auditif.", sortOrder: 20 },
  { type: 'SYMPTOM' as const, label: 'Hypoacousie', description: "Baisse partielle de l'acuité auditive.", sortOrder: 30 },
  { type: 'SYMPTOM' as const, label: 'Acouphènes', description: "Perception de bruits parasites (sifflements, bourdonnements) sans source externe.", sortOrder: 40 },
  { type: 'SYMPTOM' as const, label: 'Fièvre', description: "Élévation de la température corporelle, souvent associée à une infection.", sortOrder: 50 },
  { type: 'SYMPTOM' as const, label: 'Vertiges', description: "Sensation de rotation ou de perte d'équilibre, souvent liée à l'oreille interne.", sortOrder: 60 },
  { type: 'SYMPTOM' as const, label: 'Prurit auriculaire', description: "Démangeaisons à l'intérieur ou autour du conduit auditif.", sortOrder: 70 },
  { type: 'SYMPTOM' as const, label: 'Sensation de plénitude', description: "Sensation désagréable d'oreille pleine ou bouchée.", sortOrder: 80 },
  { type: 'SYMPTOM' as const, label: 'Écoulement purulent', description: "Sécrétion épaisse et jaunâtre/verdâtre, signe d'une surinfection.", sortOrder: 90 },
  { type: 'SYMPTOM' as const, label: 'Perforation tympanique', description: "Rupture ou trou dans la membrane du tympan.", sortOrder: 100 },
  { type: 'SYMPTOM' as const, label: 'Rhinorrhée', description: "Écoulement nasal, pouvant aggraver les troubles ORL via la trompe d'Eustache.", sortOrder: 110 },
  { type: 'SYMPTOM' as const, label: 'Obstruction nasale', description: "Nez bouché, gênant la respiration et la ventilation de l'oreille.", sortOrder: 120 },
  { type: 'SYMPTOM' as const, label: 'Douleur mastoïdienne', description: "Douleur derrière l'oreille, au niveau de l'os mastoïde.", sortOrder: 130 },
  { type: 'SYMPTOM' as const, label: 'Paralysie faciale', description: "Perte de mobilité d'une moitié du visage, complication grave possible.", sortOrder: 140 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Otites récurrentes', description: "Antécédent d'otites moyennes aiguës à répétition (au moins 3 épisodes en 6 mois ou 4 en un an).", sortOrder: 10 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Chirurgie ORL', description: "Antécédent d'intervention chirurgicale de la sphère ORL (tympanoplastie, aérateurs transtympaniques, etc.).", sortOrder: 20 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Traumatisme auriculaire', description: "Antécédent de choc physique, d'agression sonore, d'introduction d'objet ou d'accident barométrique sur l'oreille.", sortOrder: 30 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Perforation tympanique ancienne', description: "Présence connue d'une brèche non cicatrisée ou d'une séquelle de perforation de la membrane du tympan.", sortOrder: 40 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Cholestéatome', description: "Antécédent de cholestéatome de l'oreille moyenne, nécessitant une surveillance régulière.", sortOrder: 50 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Diabète', description: "Diabète de type 1 ou 2, facteur favorisant les infections ORL sévères.", sortOrder: 60 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Immunodépression', description: "Déficit immunitaire congénital ou acquis (VIH, chimiothérapie, traitement immunosuppresseur).", sortOrder: 70 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Allergie', description: "Terrain allergique (rhinite allergique, asthme) pouvant provoquer un dysfonctionnement tubaire.", sortOrder: 80 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Tabagisme', description: "Consommation de tabac (active ou passive), irritant les muqueuses respiratoires.", sortOrder: 90 },
  { type: 'MEDICAL_HISTORY' as const, label: 'Barotraumatisme', description: "Lésion de l'oreille causée par des variations rapides de pression (plongée, avion).", sortOrder: 100 },
  { type: 'MEDICAL_HISTORY' as const, label: 'HTA', description: "Hypertension artérielle, pouvant être liée à des acouphènes ou des troubles vasculaires.", sortOrder: 110 },
  { type: 'TOUCH_CHECK' as const, label: 'Douleur à la traction du pavillon', description: "Douleur provoquée par la mobilisation du pavillon de l'oreille, évocatrice d'une otite externe.", sortOrder: 10 },
  { type: 'TOUCH_CHECK' as const, label: 'Douleur à la pression du tragus', description: "Signe du tragus positif, douleur lors de la pression sur le tragus.", sortOrder: 20 },
  { type: 'TOUCH_CHECK' as const, label: 'Sensibilité mastoïdienne', description: "Douleur provoquée par la palpation de la zone osseuse située derrière l'oreille (mastoïde).", sortOrder: 30 },
  { type: 'TOUCH_CHECK' as const, label: 'Ganglions cervicaux palpables', description: "Présence d'adénopathies cervicales sensibles ou non dans le territoire de drainage de l'oreille.", sortOrder: 40 }
];

export async function runSeed() {
  if ((await userDao.count()) === 0) {
    await userDao.create({
      fullName: 'Infirmier Demo',
      email: 'nurse@korai.local',
      password: 'Password123!',
      role: 'NURSE'
    });
    await userDao.create({
      fullName: 'ORL Demo',
      email: 'orl@korai.local',
      password: 'Password123!',
      role: 'SPECIALIST'
    });
    await userDao.create({
      fullName: 'Admin Demo',
      email: 'admin@korai.local',
      password: 'Password123!',
      role: 'ADMIN'
    });
  }

  for (const item of CLINICAL_ITEMS_TO_SEED) {
    await clinicalReferenceDao.upsertByTypeAndLabel(item);
  }
}
