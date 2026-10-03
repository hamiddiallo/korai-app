import React from 'react';
import { COLORS } from '../shared';
import { Card, Button, StatusBadge, PageHeader, ConfidenceBar } from './UI';
import Icon from './Icon';
import type { Consultation } from '../shared';

const useIsMobile = () => {
  const [v, setV] = React.useState(window.innerWidth < 768);
  React.useEffect(() => {
    const h = () => setV(window.innerWidth < 768);
    window.addEventListener('resize', h);
    return () => window.removeEventListener('resize', h);
  }, []);
  return v;
};

interface DashboardProps {
  consultations: Consultation[];
  onNavigate: (route: string) => void;
}

const Dashboard: React.FC<DashboardProps> = ({ consultations, onNavigate }) => {
  const isMobile = useIsMobile();

  const total = consultations.length;
  const validated = consultations.filter(c => c.status === 'Validée').length;
  const corrected = consultations.filter(c => c.status === 'Corrigée').length;
  const uniquePatients = new Set(consultations.map(c => c.patient.nom + c.patient.prenom)).size;

  const pathoCounts: Record<string, number> = {};
  consultations.forEach(c => {
    const p = c.vision?.prediction || c.expertDiagnosis?.toLowerCase() || null;
    if (p) pathoCounts[p] = (pathoCounts[p] || 0) + 1;
  });
  const pathoSorted = Object.entries(pathoCounts).sort((a, b) => b[1] - a[1]).slice(0, 5);
  const maxPatho = pathoSorted[0]?.[1] || 1;

  const weekData = [3, 5, 2, 7, 4, 6, Math.max(total - 27, 1)];
  const maxWeek = Math.max(...weekData, 1);

  const withImage = consultations.filter(c => c.hasImage && c.vision);
  const visionAcc = withImage.length > 0
    ? Math.round((withImage.filter(c => c.visionValidated).length / withImage.length) * 100)
    : 78;

  const recent5 = consultations.slice(-5).reverse();
  const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  const chartH = 110;

  const kpis = [
    { label: 'Patients uniques',      value: uniquePatients, icon: 'users',       color: COLORS.primary,   bg: COLORS.primary   + '12', trend: '+3 ce mois' },
    { label: 'Consultations totales', value: total,          icon: 'clipboard',   color: COLORS.secondary, bg: COLORS.secondary + '12', trend: `${corrected} corrigées` },
    { label: 'Validées par expert',   value: validated,      icon: 'checkcircle', color: COLORS.success,   bg: COLORS.success   + '12', trend: `${total > 0 ? Math.round((validated / total) * 100) : 0}% du total` },
    { label: 'Corrigées IA',          value: corrected,      icon: 'edit',        color: COLORS.warning,   bg: COLORS.warning   + '12', trend: `${total > 0 ? Math.round((corrected / total) * 100) : 0}% correction IA` },
  ];

  const pad = isMobile ? '12px 14px' : '28px 32px';

  return (
    <div style={{ fontFamily: "'Outfit', sans-serif" }}>
      <PageHeader
        title="Tableau de bord"
        subtitle={`Bonjour · ${new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}`}
        actions={
          !isMobile ? (
            <Button variant="primary" icon="stethoscope" onClick={() => onNavigate('new-consultation')}>
              Nouvelle consultation
            </Button>
          ) : undefined
        }
      />

      {/* Mobile CTA */}
      {isMobile && (
        <div style={{ padding: '10px 14px 0' }}>
          <Button variant="primary" icon="stethoscope" onClick={() => onNavigate('new-consultation')}>
            Nouvelle consultation
          </Button>
        </div>
      )}

      <div style={{ padding: pad }}>
        {/* ── KPIs ──────────────────────────────────────────────────────── */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: isMobile ? 'repeat(2, 1fr)' : 'repeat(4, 1fr)',
          gap: isMobile ? 10 : 18,
          marginBottom: isMobile ? 14 : 28,
        }}>
          {kpis.map(k => (
            <Card key={k.label} padding={isMobile ? 14 : 22}
              style={{ display: 'flex', alignItems: 'center', gap: isMobile ? 10 : 16 }}>
              <div style={{
                width: isMobile ? 38 : 52, height: isMobile ? 38 : 52,
                borderRadius: 12, background: k.bg,
                display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              }}>
                <Icon name={k.icon} size={isMobile ? 18 : 24} color={k.color} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: isMobile ? 22 : 32, fontWeight: 800, color: COLORS.textPrimary, lineHeight: 1, letterSpacing: '-0.5px' }}>
                  {k.value}
                </div>
                <div style={{ fontSize: isMobile ? 10 : 12, color: COLORS.textSecondary, marginTop: 3, fontWeight: 500, lineHeight: 1.3 }}>
                  {k.label}
                </div>
                {!isMobile && (
                  <div style={{ fontSize: 11, color: k.color, marginTop: 3, fontWeight: 600 }}>{k.trend}</div>
                )}
              </div>
            </Card>
          ))}
        </div>

        {/* ── Charts ────────────────────────────────────────────────────── */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr 220px',
          gap: isMobile ? 12 : 18,
          marginBottom: isMobile ? 14 : 28,
        }}>
          {/* Pathologies fréquentes */}
          <Card padding={isMobile ? 18 : 26}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
              <h3 style={{ margin: 0, fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                Pathologies fréquentes
              </h3>
              <span style={{ fontSize: 11, color: COLORS.textSecondary, background: COLORS.background, padding: '4px 10px', borderRadius: 99, fontWeight: 600 }}>
                {pathoSorted.length} types
              </span>
            </div>
            {pathoSorted.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '24px 0', color: COLORS.textSecondary, fontSize: 13 }}>
                <Icon name="bar-chart" size={28} color={COLORS.border} />
                <p style={{ marginTop: 8, marginBottom: 0 }}>Aucune donnée disponible</p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {pathoSorted.map(([name, count], i) => (
                  <div key={name}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 5, alignItems: 'center' }}>
                      <span style={{ fontSize: 12, color: COLORS.textPrimary, fontWeight: 600, textTransform: 'capitalize', display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ width: 6, height: 6, borderRadius: '50%', flexShrink: 0, background: i === 0 ? COLORS.primary : i === 1 ? COLORS.secondary : COLORS.success, display: 'inline-block' }} />
                        {name}
                      </span>
                      <span style={{ fontSize: 12, fontWeight: 700, color: COLORS.primary, background: COLORS.primary + '10', padding: '2px 8px', borderRadius: 99 }}>
                        {count} cas
                      </span>
                    </div>
                    <div style={{ height: 7, background: COLORS.border, borderRadius: 99, overflow: 'hidden' }}>
                      <div style={{
                        height: '100%', width: `${(count / maxPatho) * 100}%`,
                        background: i === 0
                          ? `linear-gradient(90deg, ${COLORS.primary}70, ${COLORS.primary})`
                          : i === 1
                          ? `linear-gradient(90deg, ${COLORS.secondary}70, ${COLORS.secondary})`
                          : `linear-gradient(90deg, ${COLORS.success}70, ${COLORS.success})`,
                        borderRadius: 99, transition: 'width 0.8s ease',
                      }} />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Card>

          {/* Activité hebdomadaire */}
          <Card padding={isMobile ? 18 : 26}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
              <h3 style={{ margin: 0, fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                Activité hebdomadaire
              </h3>
              <span style={{ fontSize: 11, color: COLORS.success, background: COLORS.success + '12', padding: '4px 10px', borderRadius: 99, fontWeight: 700 }}>
                +12%
              </span>
            </div>
            <svg width="100%" height={chartH + 30} viewBox={`0 0 280 ${chartH + 30}`} style={{ overflow: 'visible' }}>
              {[0, 1, 2, 3].map(i => (
                <line key={i} x1="0" y1={i * (chartH / 3)} x2="280" y2={i * (chartH / 3)}
                  stroke={COLORS.border} strokeWidth="1" strokeDasharray="4 3" />
              ))}
              <defs>
                <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={COLORS.primary} stopOpacity="0.18" />
                  <stop offset="100%" stopColor={COLORS.primary} stopOpacity="0" />
                </linearGradient>
              </defs>
              <polygon
                points={[
                  ...weekData.map((v, i) => `${i * 44},${chartH - (v / maxWeek) * chartH}`),
                  `${6 * 44},${chartH}`, `0,${chartH}`,
                ].join(' ')}
                fill="url(#areaGrad)"
              />
              <polyline
                points={weekData.map((v, i) => `${i * 44},${chartH - (v / maxWeek) * chartH}`).join(' ')}
                fill="none" stroke={COLORS.primary} strokeWidth="2.5"
                strokeLinejoin="round" strokeLinecap="round"
              />
              {weekData.map((v, i) => (
                <circle key={i} cx={i * 44} cy={chartH - (v / maxWeek) * chartH} r="4.5"
                  fill="white" stroke={COLORS.primary} strokeWidth="2.5" />
              ))}
              {days.map((d, i) => (
                <text key={i} x={i * 44} y={chartH + 20} textAnchor="middle"
                  fontSize="11" fill={COLORS.textSecondary} fontFamily="'Outfit',sans-serif">{d}</text>
              ))}
            </svg>
          </Card>

          {/* Jauge de précision — visible sur desktop uniquement */}
          {!isMobile && (
            <Card padding={22} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <h3 style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 700, color: COLORS.textPrimary, textAlign: 'center' }}>
                Précision analyse image
              </h3>
              <p style={{ margin: '0 0 14px', fontSize: 11, color: COLORS.textSecondary, textAlign: 'center' }}>
                Concordance expert
              </p>
              <svg width="150" height="95" viewBox="0 0 150 95">
                <defs>
                  <linearGradient id="gaugeGrad" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stopColor={COLORS.warning} />
                    <stop offset="50%" stopColor={COLORS.secondary} />
                    <stop offset="100%" stopColor={COLORS.success} />
                  </linearGradient>
                </defs>
                <path d="M 18 82 A 57 57 0 0 1 132 82" fill="none" stroke={COLORS.border} strokeWidth="12" strokeLinecap="round" />
                <path d="M 18 82 A 57 57 0 0 1 132 82" fill="none" stroke="url(#gaugeGrad)" strokeWidth="12"
                  strokeLinecap="round" strokeDasharray={`${(visionAcc / 100) * 179} 179`} />
                <text x="75" y="78" textAnchor="middle" fontSize="26" fontWeight="800"
                  fill={COLORS.textPrimary} fontFamily="'Outfit',sans-serif">{visionAcc}%</text>
              </svg>
              <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                <div style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 18, fontWeight: 800, color: COLORS.success }}>{withImage.length}</div>
                  <div style={{ fontSize: 10, color: COLORS.textSecondary }}>avec image</div>
                </div>
                <div style={{ width: 1, background: COLORS.border }} />
                <div style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 18, fontWeight: 800, color: COLORS.primary }}>{total - withImage.length}</div>
                  <div style={{ fontSize: 10, color: COLORS.textSecondary }}>sans image</div>
                </div>
              </div>
            </Card>
          )}
        </div>

        {/* Précision IA — résumé rapide sur mobile */}
        {isMobile && (
          <div style={{
            display: 'flex', gap: 10, marginBottom: 14,
            padding: '14px 16px', background: COLORS.cardBg,
            borderRadius: 14, border: `1px solid ${COLORS.border}`,
          }}>
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: COLORS.success }}>{visionAcc}%</div>
              <div style={{ fontSize: 11, color: COLORS.textSecondary }}>Précision IA image</div>
            </div>
            <div style={{ width: 1, background: COLORS.border }} />
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: COLORS.primary }}>{withImage.length}</div>
              <div style={{ fontSize: 11, color: COLORS.textSecondary }}>Avec image</div>
            </div>
            <div style={{ width: 1, background: COLORS.border }} />
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: COLORS.secondary }}>{total - withImage.length}</div>
              <div style={{ fontSize: 11, color: COLORS.textSecondary }}>Sans image</div>
            </div>
          </div>
        )}

        {/* ── Alerte consultations validées ─────────────────────────────── */}
        {validated > 0 && (
          <div style={{
            background: `linear-gradient(135deg, ${COLORS.success}08, ${COLORS.primary}08)`,
            border: `1px solid ${COLORS.success}25`,
            borderRadius: 16,
            padding: isMobile ? '14px 16px' : '16px 24px',
            marginBottom: isMobile ? 14 : 28,
            display: 'flex',
            flexDirection: isMobile ? 'column' : 'row',
            alignItems: isMobile ? 'flex-start' : 'center',
            justifyContent: 'space-between',
            gap: isMobile ? 12 : 0,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: COLORS.success + '15', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon name="checkcircle" size={20} color={COLORS.success} />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                  {validated} consultation{validated > 1 ? 's' : ''} validée{validated > 1 ? 's' : ''}
                </div>
                <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 2 }}>
                  Ces dossiers ont été validés par l'expert
                </div>
              </div>
            </div>
            <Button variant="primary" size="sm" icon="arrowright" onClick={() => onNavigate('reports')}>
              Voir les rapports
            </Button>
          </div>
        )}

        {/* ── Consultations récentes ─────────────────────────────────────── */}
        <Card padding={0}>
          <div style={{
            padding: isMobile ? '16px' : '20px 26px',
            borderBottom: `1px solid ${COLORS.border}`,
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          }}>
            <div>
              <h3 style={{ margin: 0, fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>
                Consultations récentes
              </h3>
              {!isMobile && (
                <p style={{ margin: '3px 0 0', fontSize: 12, color: COLORS.textSecondary }}>
                  Analyse image · documentaire · diagnostic expert
                </p>
              )}
            </div>
            <Button variant="ghost" size="sm" iconRight="arrowright" onClick={() => onNavigate('reports')}>
              Voir tout
            </Button>
          </div>

          {/* Mobile: card list */}
          {isMobile ? (
            <div style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
              {recent5.length === 0 ? (
                <div style={{ padding: '28px 16px', textAlign: 'center', color: COLORS.textSecondary, fontSize: 14 }}>
                  Aucune consultation.{' '}
                  <button
                    style={{ color: COLORS.primary, background: 'none', border: 'none', cursor: 'pointer', fontWeight: 700, fontFamily: "'Outfit', sans-serif", fontSize: 14 }}
                    onClick={() => onNavigate('new-consultation')}
                  >
                    Créer la première →
                  </button>
                </div>
              ) : (
                recent5.map(c => <ConsultationCard key={c.id} c={c} onNavigate={onNavigate} />)
              )}
            </div>
          ) : (
            /* Desktop: table */
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: COLORS.background }}>
                    {([
                      { label: 'N° Dossier', icon: null },
                      { label: 'Patient', icon: 'user' },
                      { label: 'Date', icon: 'calendar' },
                      { label: 'Analyse image', icon: 'image' },
                      { label: 'Analyse documentaire', icon: 'filetext' },
                      { label: 'Diagnostic expert', icon: 'stethoscope' },
                      { label: 'Statut', icon: null },
                      { label: 'Action', icon: null },
                    ] as { label: string; icon: string | null }[]).map(h => (
                      <th key={h.label} style={{
                        padding: '12px 18px', textAlign: 'left',
                        fontSize: 11, fontWeight: 700, color: COLORS.textSecondary,
                        letterSpacing: '0.04em', textTransform: 'uppercase', whiteSpace: 'nowrap',
                      }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                          {h.icon && <Icon name={h.icon} size={12} color={COLORS.textSecondary} />}
                          {h.label}
                        </div>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {recent5.map(c => <ConsultationRow key={c.id} c={c} onNavigate={onNavigate} />)}
                  {recent5.length === 0 && (
                    <tr>
                      <td colSpan={8} style={{ padding: 40, textAlign: 'center', color: COLORS.textSecondary, fontSize: 14 }}>
                        Aucune consultation.{' '}
                        <button
                          style={{ color: COLORS.primary, background: 'none', border: 'none', cursor: 'pointer', fontWeight: 700, fontFamily: "'Outfit', sans-serif", fontSize: 14 }}
                          onClick={() => onNavigate('new-consultation')}
                        >
                          Créer la première →
                        </button>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
};

// Mobile card view for a single consultation
const ConsultationCard: React.FC<{ c: Consultation; onNavigate: (r: string) => void }> = ({ c, onNavigate }) => (
  <div style={{
    padding: '14px 16px',
    background: COLORS.background,
    borderRadius: 12,
    border: `1px solid ${COLORS.border}`,
  }}>
    {/* Header row */}
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
      <div>
        <span style={{ fontSize: 11, fontWeight: 700, color: COLORS.primary, fontFamily: "'JetBrains Mono', monospace", background: COLORS.primary + '10', padding: '2px 7px', borderRadius: 6 }}>
          {c.id}
        </span>
        <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary, marginTop: 6 }}>
          {c.patient.prenom} {c.patient.nom}
        </div>
        <div style={{ fontSize: 12, color: COLORS.textSecondary }}>
          {c.patient.age} ans · {c.patient.sexe} · {c.date}
        </div>
      </div>
      <StatusBadge status={c.status} />
    </div>

    {/* Vision result */}
    {c.vision && (
      <div style={{ marginBottom: 8 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>
          Analyse image
        </div>
        <div style={{ fontSize: 13, fontWeight: 600, color: COLORS.textPrimary, textTransform: 'capitalize', marginBottom: 4 }}>
          {c.vision.prediction}
        </div>
        <ConfidenceBar value={c.vision.confidence} color={c.vision.confidence > 80 ? COLORS.success : COLORS.warning} />
      </div>
    )}

    {/* Expert diagnosis */}
    {c.expertDiagnosis && (
      <div style={{ marginBottom: 10 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>
          Diagnostic expert
        </div>
        <div style={{ fontSize: 13, fontWeight: 600, color: COLORS.textPrimary, background: COLORS.success + '12', padding: '5px 10px', borderRadius: 8, display: 'inline-block' }}>
          {c.expertDiagnosis}
        </div>
      </div>
    )}

    <Button variant="ghost" size="sm" icon="filetext" onClick={() => onNavigate('reports')}>
      Voir le détail
    </Button>
  </div>
);

// Desktop table row
const ConsultationRow: React.FC<{ c: Consultation; onNavigate: (r: string) => void }> = ({ c, onNavigate }) => {
  const [hovered, setHovered] = React.useState(false);
  return (
    <tr
      style={{ borderTop: `1px solid ${COLORS.border}`, background: hovered ? COLORS.background : 'transparent', transition: 'background 0.15s' }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <td style={{ padding: '14px 18px' }}>
        <span style={{ fontSize: 12, fontWeight: 700, color: COLORS.primary, fontFamily: "'JetBrains Mono', monospace", background: COLORS.primary + '10', padding: '3px 8px', borderRadius: 6 }}>
          {c.id}
        </span>
      </td>
      <td style={{ padding: '14px 18px' }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary }}>{c.patient.prenom} {c.patient.nom}</div>
        <div style={{ fontSize: 11, color: COLORS.textSecondary, marginTop: 2 }}>{c.patient.age} ans · {c.patient.sexe}</div>
      </td>
      <td style={{ padding: '14px 18px', fontSize: 12, color: COLORS.textSecondary, whiteSpace: 'nowrap' }}>{c.date}</td>
      <td style={{ padding: '14px 18px', minWidth: 140 }}>
        {c.vision ? (
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, color: COLORS.textPrimary, textTransform: 'capitalize', marginBottom: 4 }}>
              {c.vision.prediction}
            </div>
            <ConfidenceBar value={c.vision.confidence} color={c.vision.confidence > 80 ? COLORS.success : COLORS.warning} />
          </div>
        ) : (
          <span style={{ fontSize: 11, color: COLORS.textSecondary, fontStyle: 'italic', background: COLORS.background, padding: '4px 8px', borderRadius: 6 }}>
            Pas d'image
          </span>
        )}
      </td>
      <td style={{ padding: '14px 18px', minWidth: 160 }}>
        {c.rag ? (
          <div style={{ fontSize: 12, color: COLORS.textPrimary, lineHeight: 1.5 }}>
            <div style={{ fontWeight: 600, marginBottom: 2 }}>
              {(c.rag.causes || '').slice(0, 60)}{(c.rag.causes || '').length > 60 ? '…' : ''}
            </div>
            <div style={{ fontSize: 11, color: COLORS.textSecondary }}>
              {(c.rag.conduite || '').slice(0, 50)}{(c.rag.conduite || '').length > 50 ? '…' : ''}
            </div>
          </div>
        ) : (
          <span style={{ fontSize: 11, color: COLORS.textSecondary, fontStyle: 'italic' }}>—</span>
        )}
      </td>
      <td style={{ padding: '14px 18px', minWidth: 150 }}>
        {c.expertDiagnosis ? (
          <div style={{ fontSize: 12, fontWeight: 600, color: COLORS.textPrimary, background: COLORS.success + '12', padding: '5px 10px', borderRadius: 8, border: `1px solid ${COLORS.success}25` }}>
            {c.expertDiagnosis}
          </div>
        ) : (
          <span style={{ fontSize: 11, color: COLORS.warning, fontWeight: 600, background: COLORS.warning + '12', padding: '4px 10px', borderRadius: 8 }}>
            Non renseigné
          </span>
        )}
      </td>
      <td style={{ padding: '14px 18px' }}><StatusBadge status={c.status} /></td>
      <td style={{ padding: '14px 18px' }}>
        {c.status === 'Corrigée' ? (
          <Button variant="primary" size="sm" icon="check" onClick={() => onNavigate('new-consultation')}>
            Valider
          </Button>
        ) : (
          <Button variant="ghost" size="sm" icon="filetext" onClick={() => onNavigate('reports')}>
            Détail
          </Button>
        )}
      </td>
    </tr>
  );
};

export default Dashboard;