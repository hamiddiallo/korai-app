import React from 'react';
import { COLORS } from '../shared';
import { Card, Button, StatusBadge, PageHeader, Modal, ConfidenceBar } from './UI';
import Icon from './Icon';
import type { Consultation } from '../shared';

interface ReportsProps {
  consultations: Consultation[];
}

const Reports: React.FC<ReportsProps> = ({ consultations }) => {
  const [search, setSearch] = React.useState('');
  const [filterStatus, setFilterStatus] = React.useState('Tous');
  const [selected, setSelected] = React.useState<Consultation | null>(null);

  const filtered = consultations.filter(c => {
    const matchSearch = !search || `${c.patient.prenom} ${c.patient.nom} ${c.id}`.toLowerCase().includes(search.toLowerCase());
    const matchStatus = filterStatus === 'Tous' || c.status === filterStatus;
    return matchSearch && matchStatus;
  });

  const generatePDF = (c: Consultation) => {
    const statusClass = c.status === 'Validée' ? 'validee' : 'corrigee';
    const zoneLabel = c.zone === 'ear' ? 'Oreille' : c.zone === 'nose' ? 'Nez' : 'Gorge';
    const dateGen = new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
    const tag = (s: string) => `<span class="tag">${s}</span>`;
    const section = (title: string, body: string) => `<section><h2>${title}</h2>${body}</section>`;
    const infoItem = (label: string, value: string) => `<div class="info-item"><label>${label}</label><span>${value}</span></div>`;

    // confidence bar
    const confFill = (conf: number) =>
      `<div class="conf-bar"><div class="conf-fill" style="width:${Math.min(conf,100)}%;background:${conf>80?'#10B981':conf>60?'#F59E0B':'#EF4444'}"></div></div>` +
      `<div class="conf-txt" style="color:${conf>80?'#10B981':conf>60?'#B45309':'#DC2626'}">${Number(conf).toFixed(1)}% de confiance</div>`;

    // ear examination findings
    const earExamHtml = (ear?: { conduit?: string; tympan?: string[]; notes?: string } | null) => {
      if (!ear || (!ear.conduit && !ear.tympan?.length && !ear.notes)) return '';
      return `<div class="ear-exam">${ear.conduit?`<div class="ear-exam-row"><span>Conduit</span><span>${ear.conduit}</span></div>`:''}${ear.tympan?.length?`<div class="ear-exam-row"><span>Tympan</span><span>${ear.tympan.join(', ')}</span></div>`:''}${ear.notes?`<div class="ear-exam-row"><span>Notes</span><span>${ear.notes}</span></div>`:''}</div>`;
    };

    // single vision box (per ear)
    const visionBox = (
      label: string,
      v: { prediction: string; confidence: number; top3?: [string, number][] } | null | undefined,
      ear?: { conduit?: string; tympan?: string[]; notes?: string } | null,
      showValidation = false,
      validated: boolean | null = null
    ) => {
      if (!v) return `<div class="box box-blue" style="opacity:.5"><span class="box-label">${label}</span><p style="font-size:11px;color:#64748B;margin-top:6px">Aucune image analysée</p></div>`;
      const alts = v.top3?.slice(1).map(([n, conf]) => `<div class="alt-row"><span>${n}</span><span>${Number(conf).toFixed(1)}%</span></div>`).join('') ?? '';
      const validHtml = showValidation
        ? `<div class="valid-note">${validated===true?'✓ Confirmé par l\'expert':validated===false?'✗ Infirmé — voir diagnostic final':'⏳ En attente de validation'}</div>`
        : '';
      return `<div class="box box-blue"><span class="box-label">${label}</span><div class="pred">${v.prediction}</div>${confFill(v.confidence)}${alts?`<div class="alts-label">Hypothèses alternatives</div>${alts}`:''}${earExamHtml(ear)}${validHtml}</div>`;
    };

    // vision layout
    const hasBothEars = !!(c.leftVision && c.rightVision);
    const hasAnyVision = !!(c.leftVision || c.rightVision || c.vision);
    let visionBoxesHtml = '';
    if (hasBothEars) {
      const bannerClass = c.visionValidated===true?'val-ok':c.visionValidated===false?'val-ko':'val-pending';
      const expertCorrection = c.visionValidated===false && c.expertDiagnosis
        ? `<span style="font-weight:800">${c.expertDiagnosis}</span>${c.expertComment ? `<br><span style="font-weight:400;font-style:italic">${c.expertComment}</span>` : ''}`
        : null;
      const bannerText = c.visionValidated===true
        ? '✓ Diagnostics IA confirmés par l\'expert'
        : c.visionValidated===false
          ? `✗ Diagnostic corrigé par l'expert${expertCorrection ? ' : ' + expertCorrection : ''}`
          : '⏳ Validation expert en attente';
      visionBoxesHtml =
        visionBox('Oreille gauche — IA otoscopique', c.leftVision, c.leftEar) +
        visionBox('Oreille droite — IA otoscopique', c.rightVision, c.rightEar) +
        `<div class="validation-banner ${bannerClass}" style="grid-column:1/-1">${bannerText}</div>`;
    } else if (hasAnyVision) {
      const v = c.leftVision || c.rightVision || c.vision;
      const side = c.leftVision ? 'gauche' : c.rightVision ? 'droite' : '';
      const ear = c.leftVision ? c.leftEar : c.rightVision ? c.rightEar : null;
      const label = side ? `Oreille ${side} — IA otoscopique` : 'Analyse image otoscopique';
      visionBoxesHtml = visionBox(label, v, ear, true, c.visionValidated);
    } else {
      visionBoxesHtml = `<div class="box box-blue" style="opacity:.5"><span class="box-label">Analyse image otoscopique</span><p style="font-size:11px;color:#64748B;margin-top:6px">Aucune image fournie</p></div>`;
    }

    // sources documentaires
    const sources = c.rag?.sources ?? [];
    let sourcesHtml = '';
    if (sources.length > 0) {
      const cards = sources.map((s) => {
        const pageRef = s.page != null ? ' · p. ' + s.page : '';
        const excerpt = s.content ? `<div class="source-excerpt">"${s.content}"</div>` : '';
        return `<div class="source-card"><div class="source-ref">${s.source}${pageRef}</div>${excerpt}</div>`;
      }).join('');
      sourcesHtml = `<div class="sources-block"><div class="sources-title">Sources documentaires utilisées par l'IA</div>${cards}</div>`;
    }

    // RAG box (full width)
    const ragBoxHtml = c.rag
      ? `<div class="box box-green full-col"><span class="box-label">Analyse documentaire RAG</span>${c.rag.causes?`<div class="rag-block"><h4>Causes probables</h4><p>${c.rag.causes}</p></div>`:''}${c.rag.signes?`<div class="rag-block"><h4>Signes associés</h4><p>${c.rag.signes}</p></div>`:''}${c.rag.conduite?`<div class="rag-block"><h4>Conduite à tenir</h4><p>${c.rag.conduite}</p></div>`:''}${sourcesHtml}<div class="valid-note">${c.ragValidated===true?'✓ Analyse pertinente':c.ragValidated===false?'✗ Non pertinente — voir commentaire expert':'⏳ En attente de validation'}</div></div>`
      : `<div class="box box-green full-col" style="opacity:.5"><span class="box-label">Analyse documentaire RAG</span><p style="font-size:11px;color:#64748B;margin-top:6px">Analyse documentaire non disponible</p></div>`;

    const content = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8"/>
  <title>KORAI ORL – ${c.id}</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    html,body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,Arial,sans-serif;color:#1A2332;background:#fff;-webkit-print-color-adjust:exact;print-color-adjust:exact}
    body{padding:36px 44px}
    .header{display:flex;align-items:center;justify-content:space-between;padding-bottom:22px;margin-bottom:30px;border-bottom:3px solid #1D6AE5}
    .logo-wrap{display:flex;align-items:center;gap:14px}
    .logo-box{width:56px;height:56px;border-radius:14px;background:linear-gradient(135deg,#0F172A,#1E3A8A);display:flex;align-items:center;justify-content:center;flex-shrink:0}
    .logo-box svg{width:32px;height:32px}
    .logo-name{font-size:26px;font-weight:800;color:#0F172A;letter-spacing:-0.5px}
    .logo-sub{font-size:9px;color:#64748B;text-transform:uppercase;letter-spacing:.14em;font-weight:600;margin-top:3px}
    .header-right{text-align:right}
    .dossier{font-family:'Courier New',Courier,monospace;font-size:20px;font-weight:700;color:#1D6AE5;background:#EFF6FF;padding:7px 14px;border-radius:8px;display:inline-block}
    .meta{font-size:11px;color:#64748B;margin-top:6px}
    .badge{display:inline-block;padding:4px 12px;border-radius:99px;font-size:10px;font-weight:700;margin-top:7px}
    .validee{background:#D1FAE5;color:#065F46}.corrigee{background:#FEF3C7;color:#92400E}
    section{margin-bottom:26px;page-break-inside:avoid}
    h2{font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:.1em;color:#64748B;padding-bottom:8px;border-bottom:1.5px solid #E2E8F0;margin-bottom:14px}
    .info-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
    .info-item{display:flex;flex-direction:column}
    .info-item label{font-size:9px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.08em;margin-bottom:3px}
    .info-item span{font-size:13px;font-weight:600;color:#1A2332}
    .tags{display:flex;flex-wrap:wrap;gap:5px;margin-top:6px}
    .tag{padding:4px 11px;background:#EFF6FF;border:1px solid #BFDBFE;border-radius:99px;font-size:11px;color:#1E40AF;font-weight:500}
    .results{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:4px}
    .box{padding:16px;border-radius:12px;border-left:4px solid;break-inside:avoid}
    .full-col{grid-column:1/-1}
    .box-blue{background:#EFF6FF;border-color:#1D6AE5}
    .box-green{background:#F0FDF4;border-color:#10B981}
    .box-expert{background:linear-gradient(135deg,#FFFBEB,#FEF9C3);border-color:#F59E0B;grid-column:1/-1}
    .box-label{font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:.1em;margin-bottom:8px;display:block}
    .box-blue .box-label{color:#1D6AE5}.box-green .box-label{color:#10B981}
    .pred{font-size:15px;font-weight:700;color:#1A2332;text-transform:capitalize;margin-bottom:8px}
    .conf-bar{height:6px;background:#E5E7EB;border-radius:99px;overflow:hidden;margin:4px 0}
    .conf-fill{height:100%;border-radius:99px}
    .conf-txt{font-size:11px;font-weight:600;margin-top:4px}
    .alts-label{margin-top:8px;font-size:9px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px}
    .alt-row{display:flex;justify-content:space-between;font-size:11px;color:#64748B;padding:3px 0;border-bottom:1px solid #F1F5F9}
    .alt-row span:last-child{font-weight:600}
    .ear-exam{margin-top:10px;padding-top:8px;border-top:1px solid rgba(29,106,229,.15)}
    .ear-exam-row{display:flex;justify-content:space-between;font-size:10px;padding:2px 0;border-bottom:1px solid #EEF2FF}
    .ear-exam-row span:first-child{color:#94A3B8;font-weight:700;text-transform:uppercase;font-size:9px;flex-shrink:0;width:70px}
    .ear-exam-row span:last-child{color:#1A2332;font-weight:600;text-align:right}
    .validation-banner{padding:8px 12px;border-radius:8px;font-size:10px;font-weight:600;margin-top:0}
    .val-ok{background:#D1FAE5;color:#065F46;border-left:3px solid #10B981}
    .val-ko{background:#FEF3C7;color:#92400E;border-left:3px solid #F59E0B}
    .val-pending{background:#F1F5F9;color:#64748B;border-left:3px solid #94A3B8}
    .rag-block{margin-bottom:10px}
    .rag-block h4{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;margin-bottom:4px;color:#10B981}
    .rag-block p{font-size:11px;color:#374151;line-height:1.55}
    .sources-block{margin-top:12px;padding-top:10px;border-top:1px solid rgba(16,185,129,.3)}
    .sources-title{font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:.1em;color:#10B981;margin-bottom:8px}
    .source-card{background:rgba(255,255,255,.7);border:1px solid #D1FAE5;border-radius:8px;padding:8px 10px;margin-bottom:6px;break-inside:avoid}
    .source-ref{font-size:10px;font-weight:700;color:#065F46;margin-bottom:3px}
    .source-excerpt{font-size:10px;color:#374151;line-height:1.5;font-style:italic}
    .valid-note{font-size:10px;color:#6B7280;margin-top:8px;font-style:italic;padding-top:6px;border-top:1px solid rgba(0,0,0,.07)}
    .expert-diag{font-size:17px;font-weight:800;color:#1A2332;text-transform:capitalize;margin:6px 0 10px}
    .expert-comment{font-size:12px;color:#4B5563;line-height:1.6}
    .sig-section{margin-top:44px;padding-top:28px;border-top:2px solid #E2E8F0;display:grid;grid-template-columns:1fr 1fr;gap:32px;page-break-inside:avoid}
    .sig-block{display:flex;flex-direction:column;gap:10px}
    .sig-label{font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:.12em;color:#94A3B8}
    .sig-name{font-size:14px;font-weight:800;color:#1A2332}
    .sig-role{font-size:11px;color:#64748B;margin-top:1px}
    .sig-line{margin-top:14px;border-top:1.5px solid #1A2332;padding-top:6px;font-size:10px;color:#94A3B8;font-style:italic}
    .cachet-box{border:2px dashed #CBD5E1;border-radius:12px;min-height:100px;display:flex;align-items:center;justify-content:center;color:#CBD5E1;font-size:11px;font-weight:600;letter-spacing:.08em;text-transform:uppercase}
    .footer{margin-top:36px;padding-top:16px;border-top:1px solid #E2E8F0;display:flex;justify-content:space-between;font-size:9px;color:#94A3B8}
    @media print{body{padding:18px 24px}.box{break-inside:avoid}section{break-inside:avoid}.sig-section{break-inside:avoid}.source-card{break-inside:avoid}}
  </style>
</head>
<body>

<div class="header">
  <div class="logo-wrap">
    <div class="logo-box">
      <svg viewBox="0 0 40 40" fill="none">
        <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white" opacity="0.93"/>
        <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.95)" stroke-width="1.8" stroke-linecap="round" fill="none"/>
        <circle cx="20" cy="15" r="2.5" fill="rgba(96,165,250,0.95)"/>
        <circle cx="20" cy="15" r="4.5" fill="none" stroke="rgba(147,197,253,0.5)" stroke-width="1.2"/>
      </svg>
    </div>
    <div>
      <div class="logo-name">KORAI ORL</div>
      <div class="logo-sub">Aide au diagnostic intelligent · Sénégal</div>
    </div>
  </div>
  <div class="header-right">
    <div class="dossier">${c.id}</div>
    <div class="meta">${c.date} à ${c.time || '—'}</div>
    <div><span class="badge ${statusClass}">${c.status}</span></div>
  </div>
</div>

${section('Informations patient', `
  <div class="info-grid">
    ${infoItem('Nom complet', `${c.patient.prenom} ${c.patient.nom}`)}
    ${infoItem('Âge · Sexe', `${c.patient.age} ans · ${c.patient.sexe}`)}
    ${infoItem('Téléphone', c.patient.telephone || '—')}
    ${infoItem('Adresse', c.patient.adresse || '—')}
  </div>
`)}

${section('Motif de consultation · Examen clinique', `
  <div class="info-grid" style="margin-bottom:14px">
    ${infoItem('Zone anatomique', zoneLabel)}
    ${infoItem('Date · Heure', `${c.date} à ${c.time || '—'}`)}
  </div>
  <label style="font-size:9px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.08em">Symptômes rapportés</label>
  <div class="tags">${(c.symptoms || []).map(tag).join('')}</div>
  ${c.physicalExam?.length ? `
    <label style="font-size:9px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.08em;display:block;margin-top:12px">Examen otoscopique</label>
    <div class="tags">${c.physicalExam.map(tag).join('')}</div>
  ` : ''}
  ${c.antecedents?.length ? `
    <label style="font-size:9px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.08em;display:block;margin-top:12px">Antécédents médicaux</label>
    <div class="tags">${c.antecedents.map(tag).join('')}</div>
  ` : ''}
`)}

${section('Résultats de l\'analyse IA', `
  <div class="results">
    ${visionBoxesHtml}
    ${ragBoxHtml}
    <div class="box box-expert">
      <span class="box-label" style="color:#B45309">Diagnostic final de l'expert</span>
      ${c.expertDiagnosis
        ? `<div class="expert-diag">${c.expertDiagnosis}</div>${c.expertComment ? `<div class="expert-comment">${c.expertComment}</div>` : ''}`
        : `<p style="font-size:12px;color:#64748B;margin-top:6px;font-style:italic">Diagnostic expert en attente de validation</p>`
      }
    </div>
  </div>
`)}

${c.expertDiagnosis ? `
<div class="sig-section">
  <div class="sig-block">
    <div class="sig-label">Expert ORL validateur</div>
    <div class="sig-name">${c.expertName || 'Nom non renseigné'}</div>
    <div class="sig-role">${c.expertRole || ''}</div>
    <div class="sig-line">Signature</div>
  </div>
  <div class="sig-block">
    <div class="sig-label">Cachet officiel</div>
    <div class="cachet-box">Cachet du service</div>
  </div>
</div>
` : ''}

<div class="footer">
  <span>KORAI ORL · Généré le ${dateGen}</span>
  <span>${c.id} · Confidentiel · Usage médical uniquement</span>
</div>

<script>setTimeout(()=>window.print(),600);</script>
</body>
</html>`;

    const blob = new Blob([content], { type: 'text/html;charset=utf-8' });
    const blobUrl = URL.createObjectURL(blob);
    const win = window.open(blobUrl, '_blank');
    if (!win) alert('Popup bloqué — autorisez les popups pour ce site.');
    setTimeout(() => URL.revokeObjectURL(blobUrl), 60000);
  };

  return (
    <div style={{ fontFamily: "'Outfit', sans-serif" }}>
      <PageHeader
        title="Consultations"
        subtitle={`${consultations.length} dossier${consultations.length > 1 ? 's' : ''} au total`}
        actions={
          <Button variant="primary" icon="stethoscope" onClick={() => {}}>
            Nouvelle consultation
          </Button>
        }
      />

      <div style={{ padding: '28px 32px' }}>
        {/* Filters */}
        <Card padding={18} style={{ marginBottom: 24, display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: 220, display: 'flex', alignItems: 'center', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, background: '#fff', overflow: 'hidden' }}>
            <div style={{ padding: '0 12px' }}><Icon name="search" size={16} color={COLORS.textSecondary} /></div>
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Rechercher par nom, prénom ou N° dossier…"
              style={{ flex: 1, border: 'none', outline: 'none', padding: '11px 12px 11px 0', fontSize: 14, fontFamily: "'Outfit', sans-serif", color: COLORS.textPrimary }}
            />
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {['Tous', 'Validée', 'Corrigée'].map(s => (
              <button key={s} onClick={() => setFilterStatus(s)} style={{
                padding: '8px 16px', borderRadius: 10, cursor: 'pointer',
                fontFamily: "'Outfit', sans-serif", fontSize: 13, fontWeight: 600,
                border: `1.5px solid ${filterStatus === s ? COLORS.primary : COLORS.border}`,
                background: filterStatus === s ? COLORS.primary + '10' : '#fff',
                color: filterStatus === s ? COLORS.primary : COLORS.textSecondary,
              }}>
                {s}
              </button>
            ))}
          </div>
        </Card>

        {/* Table */}
        <Card padding={0}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: COLORS.background }}>
                  {['N° Dossier', 'Patient', 'Date', 'Analyse image', 'Diagnostic expert', 'Statut', 'Actions'].map(h => (
                    <th key={h} style={{ padding: '13px 20px', textAlign: 'left', fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, letterSpacing: '0.05em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map(c => (
                  <ReportRow key={c.id} c={c} onSelect={() => setSelected(c)} onDownload={() => generatePDF(c)} />
                ))}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={7} style={{ padding: 44, textAlign: 'center', color: COLORS.textSecondary, fontSize: 14 }}>
                      <Icon name="search" size={36} color={COLORS.border} />
                      <p style={{ marginTop: 12, marginBottom: 0 }}>Aucun résultat trouvé</p>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      {/* Detail Modal */}
      <Modal open={!!selected} onClose={() => setSelected(null)} title={`Dossier ${selected?.id || ''}`} width={700}>
        {selected && (
          <div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 22 }}>
              {[
                { label: 'Patient', value: `${selected.patient.prenom} ${selected.patient.nom}` },
                { label: 'Âge / Sexe', value: `${selected.patient.age} ans · ${selected.patient.sexe}` },
                { label: 'Date', value: selected.date },
                { label: 'Statut', value: <StatusBadge status={selected.status} /> },
              ].map(({ label, value }) => (
                <div key={label} style={{ background: COLORS.background, borderRadius: 10, padding: '12px 16px' }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 5 }}>{label}</div>
                  <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary }}>{value}</div>
                </div>
              ))}
            </div>

            {/* Symptoms & exam */}
            <div style={{ marginBottom: 18 }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8 }}>Symptômes</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {(selected.symptoms || []).map(s => <span key={s} style={{ padding: '4px 12px', background: COLORS.background, borderRadius: 99, fontSize: 12, color: COLORS.textSecondary, fontWeight: 500 }}>{s}</span>)}
              </div>
            </div>

            {/* Three-column result */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 22 }}>
              {/* Vision */}
              <div style={{ background: COLORS.primary + '06', border: `1px solid ${COLORS.primary}20`, borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.primary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8 }}>Analyse image</div>
                {selected.vision ? (
                  <>
                    <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary, textTransform: 'capitalize', marginBottom: 6 }}>{selected.vision.prediction}</div>
                    <ConfidenceBar value={selected.vision.confidence} color={selected.vision.confidence > 80 ? COLORS.success : COLORS.warning} />
                  </>
                ) : <p style={{ fontSize: 12, color: COLORS.textSecondary, fontStyle: 'italic', margin: 0 }}>Pas d'image</p>}
              </div>
              {/* RAG */}
              <div style={{ background: COLORS.success + '06', border: `1px solid ${COLORS.success}20`, borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.success, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8 }}>Analyse documentaire</div>
                {selected.rag ? (
                  <p style={{ fontSize: 12, color: COLORS.textPrimary, margin: 0, lineHeight: 1.5 }}>
                    {(selected.rag.causes || selected.rag.conduite || '').slice(0, 100)}…
                  </p>
                ) : <p style={{ fontSize: 12, color: COLORS.textSecondary, fontStyle: 'italic', margin: 0 }}>—</p>}
              </div>
              {/* Expert */}
              <div style={{ background: COLORS.warning + '08', border: `1px solid ${COLORS.warning}25`, borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.warning, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8 }}>Diagnostic expert</div>
                {selected.expertDiagnosis ? (
                  <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary }}>{selected.expertDiagnosis}</div>
                ) : <p style={{ fontSize: 12, color: COLORS.textSecondary, fontStyle: 'italic', margin: 0 }}>Non renseigné</p>}
              </div>
            </div>

            <div style={{ display: 'flex', gap: 12 }}>
              <Button variant="secondary" icon="download" onClick={() => generatePDF(selected)} fullWidth>
                Télécharger le rapport PDF
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

const ReportRow: React.FC<{ c: Consultation; onSelect: () => void; onDownload: () => void }> = ({ c, onSelect, onDownload }) => {
  const [hovered, setHovered] = React.useState(false);
  return (
    <tr
      style={{ borderTop: `1px solid ${COLORS.border}`, background: hovered ? COLORS.background : 'transparent', transition: 'background 0.15s' }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <td style={{ padding: '14px 20px' }}>
        <span style={{ fontSize: 12, fontWeight: 700, color: COLORS.primary, fontFamily: "'JetBrains Mono', monospace", background: COLORS.primary + '10', padding: '3px 8px', borderRadius: 6 }}>
          {c.id}
        </span>
      </td>
      <td style={{ padding: '14px 20px' }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary }}>{c.patient.prenom} {c.patient.nom}</div>
        <div style={{ fontSize: 11, color: COLORS.textSecondary, marginTop: 2 }}>{c.patient.age} ans · {c.patient.sexe}</div>
      </td>
      <td style={{ padding: '14px 20px', fontSize: 13, color: COLORS.textSecondary }}>{c.date}</td>
      <td style={{ padding: '14px 20px', minWidth: 130 }}>
        {c.vision ? (
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, color: COLORS.textPrimary, textTransform: 'capitalize', marginBottom: 4 }}>{c.vision.prediction}</div>
            <ConfidenceBar value={c.vision.confidence} color={c.vision.confidence > 80 ? COLORS.success : COLORS.warning} />
          </div>
        ) : (
          <span style={{ fontSize: 11, color: COLORS.textSecondary, fontStyle: 'italic' }}>Pas d'image</span>
        )}
      </td>
      <td style={{ padding: '14px 20px' }}>
        {c.expertDiagnosis ? (
          <div style={{ fontSize: 13, fontWeight: 600, color: COLORS.textPrimary, maxWidth: 180 }}>{c.expertDiagnosis}</div>
        ) : (
          <span style={{ fontSize: 12, color: COLORS.textSecondary, fontWeight: 600 }}>Non renseigné</span>
        )}
      </td>
      <td style={{ padding: '14px 20px' }}><StatusBadge status={c.status} /></td>
      <td style={{ padding: '14px 20px' }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button variant="ghost" size="sm" icon="eye" onClick={onSelect}>Détail</Button>
          <Button variant="secondary" size="sm" icon="download" onClick={onDownload}>Télécharger PDF</Button>
        </div>
      </td>
    </tr>
  );
};

export default Reports;

