import React from 'react';
import { COLORS, SYMPTOMS_LIST, ANTECEDENTS_LIST, PHYSICAL_EXAM_LIST, CONDUIT_AUDITIF_OPTIONS, TYMPAN_OPTIONS, ORL_ZONES, Storage, API } from '../shared';
import { Card, Button, Modal, Spinner, ConfidenceBar, PageHeader } from './UI';
import Icon from './Icon';
import { DB } from '../supabase';
import type { Consultation, User } from '../shared';

const useIsMobile = () => {
  const [v, setV] = React.useState(window.innerWidth < 768);
  React.useEffect(() => {
    const h = () => setV(window.innerWidth < 768);
    window.addEventListener('resize', h);
    return () => window.removeEventListener('resize', h);
  }, []);
  return v;
};

const STEPS = ['Zone ORL', 'Patient', 'Symptômes', 'Examen physique', 'Antécédents', 'Confirmation', 'Analyse', 'Validation'];

interface NewConsultationProps {
  consultations: Consultation[];
  setConsultations: (c: Consultation[]) => void;
  onDone: () => void;
  user: User;
}

// Module-level to preserve component identity across re-renders
const toggleTag = (list: string[], setList: (l: string[]) => void, tag: string) => {
  if (list.includes(tag)) setList(list.filter(t => t !== tag));
  else setList([...list, tag]);
};

const TagGrid: React.FC<{
  items: string[];
  selected: string[];
  onToggle: (t: string) => void;
  otherVal: string;
  onOtherChange: (v: string) => void;
}> = ({ items, selected, onToggle, otherVal, onOtherChange }) => (
  <div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      {items.map(tag => {
        const active = selected.includes(tag);
        return (
          <button key={tag} onClick={() => onToggle(tag)} style={{
            padding: '8px 16px', borderRadius: 20,
            border: `1.5px solid ${active ? COLORS.primary : COLORS.border}`,
            background: active ? COLORS.primary + '12' : '#fff',
            color: active ? COLORS.primary : COLORS.textSecondary,
            fontSize: 13, fontWeight: active ? 600 : 400,
            fontFamily: "'Outfit', sans-serif", cursor: 'pointer',
            transition: 'all 0.15s',
          }}>
            {tag === 'Autre' ? '+ Autre' : tag}
          </button>
        );
      })}
    </div>
    {selected.includes('Autre') && (
      <input
        value={otherVal} onChange={e => onOtherChange(e.target.value)}
        placeholder="Précisez…"
        style={{
          marginTop: 12, width: '100%', padding: '10px 14px',
          border: `1.5px solid ${COLORS.primary}`, borderRadius: 8,
          fontSize: 14, fontFamily: "'Outfit', sans-serif",
          outline: 'none', boxSizing: 'border-box',
        }}
      />
    )}
  </div>
);

interface EarExamCardProps {
  label: string;
  accentColor: string;
  imgPreview: string | null;
  imgFile: File | null;
  fileInputRef: React.RefObject<HTMLInputElement>;
  conduit: string;
  setConduit: (v: string) => void;
  tympan: string[];
  setTympan: (v: string[]) => void;
  notes: string;
  setNotes: (v: string) => void;
  onFileChange: (f: File | undefined) => void;
  onImageDelete: () => void;
}

const EarExamCard: React.FC<EarExamCardProps> = ({
  label, accentColor,
  imgPreview, imgFile, fileInputRef,
  conduit, setConduit,
  tympan, setTympan,
  notes, setNotes,
  onFileChange, onImageDelete,
}) => (
  <div style={{ padding: '14px 16px', border: `1.5px solid ${accentColor}30`, borderRadius: 12, background: accentColor + '04' }}>
    <div style={{ fontSize: 12, fontWeight: 700, color: accentColor, marginBottom: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
      <span style={{ display: 'inline-block', width: 3, height: 12, background: accentColor, borderRadius: 2 }} />
      {label}
    </div>

    {/* Image */}
    <div style={{ marginBottom: 12 }}>
      {!imgPreview ? (
        <button
          onClick={() => fileInputRef.current?.click()}
          style={{
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            width: '100%', padding: '10px', borderRadius: 8, cursor: 'pointer',
            border: `1.5px dashed ${COLORS.border}`, background: COLORS.background,
            color: COLORS.textSecondary, fontSize: 12, fontWeight: 500,
            fontFamily: "'Outfit', sans-serif",
          }}
        >
          <Icon name="upload" size={13} color={COLORS.primary} />
          Téléverser une image (Optionnel)
        </button>
      ) : (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', background: '#fff', borderRadius: 8, border: `1px solid ${COLORS.border}` }}>
          <img src={imgPreview} alt="otoscope" style={{ width: 52, height: 52, objectFit: 'cover', borderRadius: 6, border: `1.5px solid ${COLORS.border}`, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ margin: '0 0 1px', fontWeight: 700, color: COLORS.textPrimary, fontSize: 12, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{imgFile?.name}</p>
            <p style={{ margin: 0, color: COLORS.textSecondary, fontSize: 11 }}>{imgFile ? (imgFile.size / 1024).toFixed(0) : 0} Ko</p>
            <button onClick={onImageDelete} style={{ marginTop: 4, background: COLORS.danger + '12', border: 'none', color: COLORS.danger, padding: '2px 10px', borderRadius: 5, cursor: 'pointer', fontSize: 10, fontWeight: 700, fontFamily: "'Outfit', sans-serif" }}>
              Supprimer
            </button>
          </div>
        </div>
      )}
      <input ref={fileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={e => onFileChange(e.target.files?.[0])} />
    </div>

    {/* Conduit */}
    <div style={{ marginBottom: 10 }}>
      <label style={{ display: 'block', marginBottom: 5, fontSize: 11, fontWeight: 600, color: COLORS.textSecondary }}>
        Conduit Auditif <span style={{ color: COLORS.danger }}>*</span>
      </label>
      <div style={{ position: 'relative' }}>
        <select
          value={conduit}
          onChange={e => setConduit(e.target.value)}
          style={{
            width: '100%', padding: '8px 30px 8px 10px',
            border: `1.5px solid ${conduit ? accentColor : COLORS.border}`,
            borderRadius: 8, fontSize: 12, fontFamily: "'Outfit', sans-serif",
            outline: 'none', appearance: 'none', background: '#fff',
            color: conduit ? COLORS.textPrimary : COLORS.textSecondary, cursor: 'pointer',
          }}
        >
          <option value="">Sélectionner…</option>
          {CONDUIT_AUDITIF_OPTIONS.map(opt => <option key={opt} value={opt}>{opt}</option>)}
        </select>
        <div style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}>
          <Icon name="chevrondown" size={11} color={COLORS.textSecondary} />
        </div>
      </div>
    </div>

    {/* Tympan */}
    <div style={{ marginBottom: 10 }}>
      <label style={{ display: 'block', marginBottom: 6, fontSize: 11, fontWeight: 600, color: COLORS.textSecondary }}>
        Tympan <span style={{ color: COLORS.danger }}>*</span>
        <span style={{ fontWeight: 400, marginLeft: 4 }}>(multi)</span>
      </label>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
        {TYMPAN_OPTIONS.map(opt => {
          const active = tympan.includes(opt);
          return (
            <button key={opt} onClick={() => toggleTag(tympan, setTympan, opt)} style={{
              padding: '4px 10px', borderRadius: 20,
              border: `1.5px solid ${active ? accentColor : COLORS.border}`,
              background: active ? accentColor + '15' : '#fff',
              color: active ? accentColor : COLORS.textSecondary,
              fontSize: 11, fontWeight: active ? 700 : 400,
              fontFamily: "'Outfit', sans-serif", cursor: 'pointer', transition: 'all 0.15s',
            }}>
              {opt}
            </button>
          );
        })}
      </div>
    </div>

    {/* Notes */}
    <div>
      <label style={{ display: 'block', marginBottom: 5, fontSize: 11, fontWeight: 600, color: COLORS.textSecondary }}>
        Notes (optionnel)
      </label>
      <textarea
        value={notes}
        onChange={e => setNotes(e.target.value)}
        placeholder="Observations complémentaires…"
        rows={2}
        style={{
          width: '100%', padding: '8px 10px',
          border: `1.5px solid ${COLORS.border}`, borderRadius: 8,
          fontSize: 12, fontFamily: "'Outfit', sans-serif",
          outline: 'none', resize: 'vertical', boxSizing: 'border-box',
        }}
      />
    </div>
  </div>
);

type VisionResult = { prediction: string; confidence: number; top3: [string, number][] };

const NewConsultation: React.FC<NewConsultationProps> = ({ consultations, setConsultations, onDone, user }) => {
  const isMobile = useIsMobile();
  const [step, setStep] = React.useState(0);

  // Step 0
  const [zone, setZone] = React.useState('');

  // Step 1
  const dossierId = React.useMemo(() => Storage.nextDossierId(consultations), [consultations.length]);
  const [patient, setPatient] = React.useState({ nom: '', prenom: '', telephone: '+221 ', adresse: '', age: '', sexe: 'Masculin' });

  // Step 2
  const [symptoms, setSymptoms] = React.useState<string[]>([]);
  const [symptomOther, setSymptomOther] = React.useState('');

  // Step 3 – Physical exam
  const [physicalExam, setPhysicalExam] = React.useState<string[]>([]);
  const [physOther, setPhysOther] = React.useState('');
  // Oreille Gauche (OG)
  const [leftConduit, setLeftConduit] = React.useState('');
  const [leftTympan, setLeftTympan] = React.useState<string[]>([]);
  const [leftNotes, setLeftNotes] = React.useState('');
  const [leftImageFile, setLeftImageFile] = React.useState<File | null>(null);
  const [leftImagePreview, setLeftImagePreview] = React.useState<string | null>(null);
  const leftFileRef = React.useRef<HTMLInputElement>(null);
  // Oreille Droite (OD)
  const [rightConduit, setRightConduit] = React.useState('');
  const [rightTympan, setRightTympan] = React.useState<string[]>([]);
  const [rightNotes, setRightNotes] = React.useState('');
  const [rightImageFile, setRightImageFile] = React.useState<File | null>(null);
  const [rightImagePreview, setRightImagePreview] = React.useState<string | null>(null);
  const rightFileRef = React.useRef<HTMLInputElement>(null);

  // Step 4
  const [antecedents, setAntecedents] = React.useState<string[]>([]);
  const [anteOther, setAnteOther] = React.useState('');

  // Step 5 – Confirmation
  const [skipAnalysis, setSkipAnalysis] = React.useState(false);

  // Step 6 – Analysis
  const [diagLoading, setDiagLoading] = React.useState(false);
  const [leftVisionResult, setLeftVisionResult] = React.useState<VisionResult | null>(null);
  const [rightVisionResult, setRightVisionResult] = React.useState<VisionResult | null>(null);
  const [ragResult, setRagResult] = React.useState<{ fullText: string; causes: string; signes: string; conduite: string; sources: { source: string; page?: number; content: string }[] } | null>(null);
  const [showRagSources, setShowRagSources] = React.useState(false);
  const [caseId, setCaseId] = React.useState<string | null>(null);
  const [driveImageUrl, setDriveImageUrl] = React.useState<string | null>(null);

  // Step 7 – Validation
  const [showModal, setShowModal] = React.useState(false);
  const [visionValidated, setVisionValidated] = React.useState<boolean | null>(null);
  const [ragValidated, setRagValidated] = React.useState<boolean | null>(null);
  const [visionComment, setVisionComment] = React.useState('');
  const [ragComment, setRagComment] = React.useState('');
  const [expertDiagnosis, setExpertDiagnosis] = React.useState('');
  const [expertComment, setExpertComment] = React.useState('');
  const [saving, setSaving] = React.useState(false);
  const [saved, setSaved] = React.useState(false);

  // Derived
  const hasAnyImage = leftImageFile !== null || rightImageFile !== null;
  const wantsAnalysis = hasAnyImage && !skipAnalysis;
  const anyVisionResult = leftVisionResult || rightVisionResult;

  const allSymptoms = symptoms.includes('Autre') && symptomOther
    ? [...symptoms.filter(s => s !== 'Autre'), symptomOther]
    : symptoms.filter(s => s !== 'Autre');
  const allPhysExam = [
    ...(physicalExam.includes('Autre') && physOther
      ? [...physicalExam.filter(s => s !== 'Autre'), physOther]
      : physicalExam.filter(s => s !== 'Autre')),
    ...(leftConduit ? [`OG - Conduit : ${leftConduit}`] : []),
    ...(leftTympan.length > 0 ? [`OG - Tympan : ${leftTympan.join(', ')}`] : []),
    ...(leftNotes ? [`OG - Notes : ${leftNotes}`] : []),
    ...(rightConduit ? [`OD - Conduit : ${rightConduit}`] : []),
    ...(rightTympan.length > 0 ? [`OD - Tympan : ${rightTympan.join(', ')}`] : []),
    ...(rightNotes ? [`OD - Notes : ${rightNotes}`] : []),
  ];
  const allAntecedents = antecedents.includes('Autre') && anteOther
    ? [...antecedents.filter(a => a !== 'Autre'), anteOther]
    : antecedents.filter(a => a !== 'Autre');

  const handleEarImageFile = (
    file: File | undefined,
    setFile: (f: File | null) => void,
    setPreview: (p: string | null) => void,
  ) => {
    if (!file || !file.type.startsWith('image/')) return;
    setFile(file);
    const reader = new FileReader();
    reader.onload = e => setPreview(e.target?.result as string);
    reader.readAsDataURL(file);
  };

  const parseRagSections = (raw: string) => {
    if (!raw) return { causes: '', signes: '', conduite: '' };
    const cleaned = raw.replace(/\*\*/g, '').replace(/^#+\s*/gm, '').trim();
    const sections = { causes: '', signes: '', conduite: '' };
    const blocks = cleaned.split(/\n(?=\s*[1-9][.)]\s)/);
    for (const block of blocks) {
      // Capture everything after the number — works for both single-line and multi-line formats
      const m = block.match(/^\s*([1-9])[.)]\s*([\s\S]+)/);
      if (!m) continue;
      const num = m[1];
      const rawContent = m[2].trim();
      const firstLine = rawContent.split('\n')[0].toLowerCase();
      // Strip "Section label : " prefix (e.g. "Causes probables : ..." → "...")
      const content = rawContent.replace(/^[^:\n]+:\s*/, '') || rawContent;
      if (num === '1' || firstLine.includes('cause')) sections.causes = content;
      else if (num === '2' || firstLine.includes('signe') || firstLine.includes('symptôme')) sections.signes = content;
      else if (num === '3' || firstLine.includes('conduite') || firstLine.includes('traitement')) sections.conduite = content;
    }
    return sections;
  };

  const parseVision = (result: { vision: { prediction: string; confidence: number; top3?: { class: string; confidence: number }[] } }): VisionResult => {
    const top3: [string, number][] = (result.vision.top3 || []).map(
      (item: { class: string; confidence: number }) => [item.class, item.confidence] as [string, number]
    );
    return { prediction: result.vision.prediction, confidence: result.vision.confidence, top3 };
  };

  const runDiagnosis = async () => {
    setDiagLoading(true);
    const symptomsText =
      `Patient de ${patient.age || '?'} ans, sexe ${patient.sexe || 'non précisé'}. ` +
      `Symptômes : ${allSymptoms.join(', ') || 'non précisés'}. ` +
      `Examen physique : ${allPhysExam.join(', ') || 'non précisé'}. ` +
      `Antécédents : ${allAntecedents.join(', ') || 'aucun'}. ` +
      `Quel est le diagnostic ORL probable et la conduite à tenir ?`;
    try {
      if (wantsAnalysis) {
        if (leftImageFile && rightImageFile) {
          // Both images → two parallel vision analyses, RAG from the first response
          const [leftRes, rightRes] = await Promise.all([
            API.diagnoseSeparate(symptomsText, leftImageFile, true, dossierId),
            API.visionPredict(rightImageFile),
          ]);
          setLeftVisionResult(parseVision(leftRes));
          setRightVisionResult(parseVision({ vision: rightRes }));
          setCaseId(leftRes.case_id);
          setDriveImageUrl(leftRes.drive_image_url || null);
          const text = leftRes.rag.summary || '';
          const parsed = parseRagSections(text);
          setRagResult({ fullText: text, causes: parsed.causes || text, signes: parsed.signes || '', conduite: parsed.conduite || '', sources: leftRes.rag.sources || [] });
        } else {
          // Single image
          const file = leftImageFile ?? rightImageFile!;
          const isLeft = leftImageFile !== null;
          const result = await API.diagnoseSeparate(symptomsText, file, true, dossierId);
          if (isLeft) setLeftVisionResult(parseVision(result));
          else setRightVisionResult(parseVision(result));
          setCaseId(result.case_id);
          setDriveImageUrl(result.drive_image_url || null);
          const text = result.rag.summary || '';
          const parsed = parseRagSections(text);
          setRagResult({ fullText: text, causes: parsed.causes || text, signes: parsed.signes || '', conduite: parsed.conduite || '', sources: result.rag.sources || [] });
        }
      } else {
        // RAG only, no image
        const rRes = await API.ragAnalyze(symptomsText, true);
        const text = rRes.summary || '';
        const parsed = parseRagSections(text);
        setRagResult({ fullText: text, causes: parsed.causes || text, signes: parsed.signes || '', conduite: parsed.conduite || '', sources: (rRes.sources || []).map(s => ({ source: s.source, page: s.page, content: s.content || '' })) });
      }
    } catch (err) {
      // Backend injoignable ou en erreur : aucun résultat simulé n'est affiché.
      // La consultation peut être enregistrée avec le seul diagnostic de l'expert.
      console.error('Analyse IA indisponible', err);
      setLeftVisionResult(null);
      setRightVisionResult(null);
      setRagResult({ fullText: '', causes: "ANALYSE IA INDISPONIBLE — le serveur n'a pas répondu. Aucun résultat automatique n'est affiché ; relancez l'analyse ou concluez avec votre seul diagnostic.", signes: '', conduite: '', sources: [] });
    }
    setDiagLoading(false);
  };

  React.useEffect(() => {
    if (step === 6 && !diagLoading && !ragResult && !leftVisionResult && !rightVisionResult) runDiagnosis();
  }, [step]);

  // Going back from step 6 resets results so the analysis reruns on next visit
  const handleBack = () => {
    if (step === 6) {
      setLeftVisionResult(null);
      setRightVisionResult(null);
      setRagResult(null);
      setCaseId(null);
      setDriveImageUrl(null);
    }
    setStep(s => s - 1);
  };

  const handleSave = async () => {
    if (!expertDiagnosis.trim()) return;
    setSaving(true);
    const status: 'Validée' | 'Corrigée' = (visionValidated === false || ragValidated === false) ? 'Corrigée' : 'Validée';
    let driveExportUrl = null;
    if (caseId) {
      try {
        const res = await API.validate({
          case_id: caseId,
          expert_diagnosis: expertDiagnosis,
          expert_comment: expertComment || '',
          expert_id: user.username,
          validation_source: 'expert',
          vision_validated: visionValidated,
          rag_validated: ragValidated,
          vision_comment: visionValidated === false ? visionComment : null,
          rag_comment: ragValidated === false ? ragComment : null,
        });
        driveExportUrl = res.drive_export_url || null;
      } catch { /* continue */ }
    }
    const newCase: Consultation = {
      id: dossierId, caseId, driveImageUrl, driveExportUrl,
      date: new Date().toISOString().slice(0, 10),
      time: new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }),
      patient: { ...patient, age: parseInt(patient.age) },
      zone,
      symptoms: allSymptoms,
      physicalExam: allPhysExam,
      antecedents: allAntecedents,
      hasImage: wantsAnalysis,
      leftEar: (leftConduit || leftTympan.length > 0 || leftNotes) ? { conduit: leftConduit, tympan: leftTympan, notes: leftNotes } : undefined,
      rightEar: (rightConduit || rightTympan.length > 0 || rightNotes) ? { conduit: rightConduit, tympan: rightTympan, notes: rightNotes } : undefined,
      vision: anyVisionResult ?? null,
      leftVision: leftVisionResult,
      rightVision: rightVisionResult,
      rag: ragResult ? { causes: ragResult.causes, signes: ragResult.signes, conduite: ragResult.conduite, sources: ragResult.sources } : null,
      expertDiagnosis, expertComment,
      expertName: user.username, expertRole: user.role,
      status,
      visionValidated, ragValidated,
      visionComment: visionValidated === false ? visionComment : null,
      ragComment: ragValidated === false ? ragComment : null,
    };
    const updated = [...consultations, newCase];
    setConsultations(updated);
    Storage.saveConsultations(updated);
    DB.saveConsultation(newCase).catch(console.warn); // persist to Supabase (fire-and-forget)
    setSaving(false);
    setSaved(true);
    setTimeout(() => { setShowModal(false); onDone(); }, 1500);
  };

  const canNext = () => {
    if (step === 0) return zone !== '';
    if (step === 1) return !!(patient.nom && patient.prenom && patient.telephone && patient.adresse && patient.age);
    if (step === 2) return symptoms.length > 0;
    if (step === 3) return (leftConduit !== '' && leftTympan.length > 0) || (rightConduit !== '' && rightTympan.length > 0);
    return true;
  };

  const renderVisionCard = (result: VisionResult, preview: string | null, earLabel: string, accentColor: string) => (
    <Card padding={22} style={{ border: `2px solid ${accentColor}20` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
        <div style={{ width: 36, height: 36, borderRadius: 10, background: accentColor + '12', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="image" size={18} color={accentColor} />
        </div>
        <div>
          <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>Analyse image · {earLabel}</div>
          <div style={{ fontSize: 11, color: COLORS.textSecondary }}>Reconnaissance visuelle automatique</div>
        </div>
      </div>
      {preview && <img src={preview} alt="otoscope" style={{ width: '100%', height: 130, objectFit: 'cover', borderRadius: 10, marginBottom: 14, border: `1px solid ${COLORS.border}` }} />}
      <div style={{ fontSize: 15, fontWeight: 700, color: COLORS.textPrimary, textTransform: 'capitalize', marginBottom: 12 }}>
        {result.prediction}
      </div>
      <ConfidenceBar value={result.confidence} color={result.confidence > 80 ? COLORS.success : COLORS.warning} label="Score de confiance" />
      {result.top3 && result.top3.length > 1 && (
        <div style={{ marginTop: 14, paddingTop: 14, borderTop: `1px solid ${COLORS.border}` }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 8 }}>Hypothèses alternatives</div>
          {result.top3.map(([name, conf], i) => (
            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontSize: 12, color: i === 0 ? COLORS.textPrimary : COLORS.textSecondary }}>
              <span style={{ textTransform: 'capitalize', fontWeight: i === 0 ? 600 : 400 }}>{name}</span>
              <span style={{ fontWeight: 600 }}>{parseFloat(String(conf)).toFixed(1)}%</span>
            </div>
          ))}
        </div>
      )}
    </Card>
  );

  const renderStep = () => {
    // Step 0 – Zone
    if (step === 0) return (
      <div>
        <p style={{ color: COLORS.textSecondary, fontSize: 15, marginTop: 0, marginBottom: 28 }}>
          Sélectionnez la zone anatomique concernée par la consultation.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: isMobile ? '1fr' : 'repeat(3, 1fr)', gap: 16 }}>
          {ORL_ZONES.map(z => (
            <button
              key={z.key}
              onClick={() => z.available && setZone(z.key)}
              disabled={!z.available}
              style={{
                padding: '28px 20px', borderRadius: 16, cursor: z.available ? 'pointer' : 'not-allowed',
                fontFamily: "'Outfit', sans-serif",
                border: `2px solid ${zone === z.key ? COLORS.primary : COLORS.border}`,
                background: zone === z.key ? COLORS.primary + '08' : z.available ? '#fff' : COLORS.background,
                opacity: z.available ? 1 : 0.5,
                textAlign: 'center', transition: 'all 0.15s', position: 'relative',
              }}
            >
              {!z.available && (
                <div style={{
                  position: 'absolute', top: 10, right: 10,
                  background: COLORS.border, color: COLORS.textSecondary,
                  fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 99,
                  letterSpacing: '0.06em',
                }}>
                  BIENTÔT
                </div>
              )}
              <div style={{ marginBottom: 12, display: 'flex', justifyContent: 'center' }}>
                <Icon name={z.icon} size={44} color={zone === z.key ? COLORS.primary : z.available ? COLORS.textSecondary : COLORS.border} />
              </div>
              <div style={{ fontSize: 18, fontWeight: 700, color: zone === z.key ? COLORS.primary : COLORS.textPrimary, marginBottom: 6 }}>{z.label}</div>
              <div style={{ fontSize: 12, color: COLORS.textSecondary, lineHeight: 1.5 }}>{z.desc}</div>
              {zone === z.key && (
                <div style={{
                  position: 'absolute', top: 10, left: 10,
                  width: 24, height: 24, borderRadius: '50%',
                  background: COLORS.primary, display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Icon name="check" size={13} color="white" />
                </div>
              )}
            </button>
          ))}
        </div>
      </div>
    );

    // Step 1 – Patient
    if (step === 1) return (
      <div>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          background: COLORS.primary + '10', borderRadius: 8, padding: '8px 14px', marginBottom: 24,
        }}>
          <Icon name="clipboard" size={15} color={COLORS.primary} />
          <span style={{ fontSize: 13, fontWeight: 700, color: COLORS.primary, fontFamily: "'JetBrains Mono', monospace" }}>
            N° Dossier : {dossierId}
          </span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr', gap: '0 20px' }}>
          {[
            { label: 'Nom', key: 'nom', placeholder: 'Diallo', required: true },
            { label: 'Prénom', key: 'prenom', placeholder: 'Aïssatou', required: true },
            { label: 'Téléphone', key: 'telephone', placeholder: '+221 77 …', required: true },
            { label: 'Adresse', key: 'adresse', placeholder: 'Sacré-Cœur 3, Dakar', required: true, span: 2 },
            { label: 'Âge (ans)', key: 'age', placeholder: '28', type: 'number', required: true },
          ].map(f => (
            <div key={f.key} style={{ gridColumn: f.span ? `span ${f.span}` : undefined }}>
              <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
                {f.label}{f.required && <span style={{ color: COLORS.danger }}> *</span>}
              </label>
              <input
                type={f.type || 'text'}
                value={(patient as Record<string, string>)[f.key]}
                onChange={e => setPatient(p => ({ ...p, [f.key]: e.target.value }))}
                placeholder={f.placeholder}
                style={{ width: '100%', padding: '11px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', marginBottom: 16, boxSizing: 'border-box' }}
              />
            </div>
          ))}
          <div>
            <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
              Sexe <span style={{ color: COLORS.danger }}>*</span>
            </label>
            <div style={{ display: 'flex', gap: 10 }}>
              {['Masculin', 'Féminin'].map(s => (
                <button key={s} onClick={() => setPatient(p => ({ ...p, sexe: s }))} style={{
                  flex: 1, padding: '11px', borderRadius: 10, cursor: 'pointer',
                  fontFamily: "'Outfit', sans-serif",
                  border: `1.5px solid ${patient.sexe === s ? COLORS.primary : COLORS.border}`,
                  background: patient.sexe === s ? COLORS.primary + '10' : '#fff',
                  color: patient.sexe === s ? COLORS.primary : COLORS.textSecondary,
                  fontWeight: patient.sexe === s ? 600 : 400, fontSize: 14,
                }}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    );

    // Step 2 – Symptoms
    if (step === 2) return (
      <div>
        <p style={{ color: COLORS.textSecondary, fontSize: 14, marginTop: 0, marginBottom: 20 }}>
          Sélectionnez tous les symptômes rapportés par le patient.
        </p>
        <TagGrid items={SYMPTOMS_LIST} selected={symptoms} onToggle={t => toggleTag(symptoms, setSymptoms, t)} otherVal={symptomOther} onOtherChange={setSymptomOther} />
      </div>
    );

    // Step 3 – Physical exam
    if (step === 3) return (
      <div>
        <div style={{
          background: COLORS.secondary + '10', border: `1px solid ${COLORS.secondary}25`,
          borderRadius: 12, padding: '12px 16px', marginBottom: 20,
          display: 'flex', gap: 10, alignItems: 'flex-start',
        }}>
          <Icon name="stethoscope" size={18} color={COLORS.secondary} />
          <p style={{ margin: 0, fontSize: 13, color: COLORS.textPrimary, fontWeight: 500 }}>
            Notez les constatations cliniques après l'examen du patient. Renseignez au moins une oreille.
          </p>
        </div>

        {/* Inspection & Palpation */}
        <div style={{ marginBottom: 20, padding: '16px 18px', border: `1px solid ${COLORS.border}`, borderRadius: 14 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ display: 'inline-block', width: 3, height: 12, background: COLORS.secondary, borderRadius: 2 }} />
            Inspection &amp; Palpation
          </div>
          <TagGrid items={PHYSICAL_EXAM_LIST} selected={physicalExam} onToggle={t => toggleTag(physicalExam, setPhysicalExam, t)} otherVal={physOther} onOtherChange={setPhysOther} />
        </div>

        {/* Examen Otoscopique – deux oreilles */}
        <div style={{ border: `1.5px solid ${COLORS.primary}25`, borderRadius: 14, padding: '16px 18px', background: COLORS.primary + '02' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ display: 'inline-block', width: 3, height: 12, background: COLORS.primary, borderRadius: 2 }} />
            Examen Otoscopique Numérique
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr', gap: 14 }}>
            <EarExamCard
              label="Oreille Gauche (OG)" accentColor={COLORS.primary}
              imgPreview={leftImagePreview} imgFile={leftImageFile} fileInputRef={leftFileRef}
              conduit={leftConduit} setConduit={setLeftConduit}
              tympan={leftTympan} setTympan={setLeftTympan}
              notes={leftNotes} setNotes={setLeftNotes}
              onFileChange={f => handleEarImageFile(f, setLeftImageFile, setLeftImagePreview)}
              onImageDelete={() => { setLeftImageFile(null); setLeftImagePreview(null); }}
            />
            <EarExamCard
              label="Oreille Droite (OD)" accentColor={COLORS.secondary}
              imgPreview={rightImagePreview} imgFile={rightImageFile} fileInputRef={rightFileRef}
              conduit={rightConduit} setConduit={setRightConduit}
              tympan={rightTympan} setTympan={setRightTympan}
              notes={rightNotes} setNotes={setRightNotes}
              onFileChange={f => handleEarImageFile(f, setRightImageFile, setRightImagePreview)}
              onImageDelete={() => { setRightImageFile(null); setRightImagePreview(null); }}
            />
          </div>
        </div>
      </div>
    );

    // Step 4 – Antecedents
    if (step === 4) return (
      <div>
        <p style={{ color: COLORS.textSecondary, fontSize: 14, marginTop: 0, marginBottom: 20 }}>
          Sélectionnez les antécédents médicaux du patient.
        </p>
        <TagGrid items={ANTECEDENTS_LIST} selected={antecedents} onToggle={t => toggleTag(antecedents, setAntecedents, t)} otherVal={anteOther} onOtherChange={setAnteOther} />
      </div>
    );

    // Step 5 – Confirmation avant analyse
    if (step === 5) return (
      <div>
        <p style={{ color: COLORS.textSecondary, fontSize: 14, marginTop: 0, marginBottom: 20 }}>
          Vérifiez les images otoscopiques qui seront soumises à l'IA, puis confirmez.
        </p>

        {!hasAnyImage ? (
          <div style={{
            background: COLORS.background, borderRadius: 12, padding: '28px 24px',
            textAlign: 'center', border: `1.5px dashed ${COLORS.border}`,
          }}>
            <Icon name="filetext" size={34} color={COLORS.textSecondary} />
            <p style={{ color: COLORS.textSecondary, fontSize: 14, marginTop: 12, marginBottom: 0 }}>
              Aucune image otoscopique chargée — l'analyse sera documentaire uniquement.
            </p>
          </div>
        ) : (
          <div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16 }}>
              {leftImagePreview && (
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px',
                  border: `1.5px solid ${skipAnalysis ? COLORS.border : COLORS.primary + '40'}`,
                  borderRadius: 12, background: skipAnalysis ? COLORS.background : COLORS.primary + '04',
                  opacity: skipAnalysis ? 0.55 : 1, transition: 'all 0.2s',
                }}>
                  <img src={leftImagePreview} alt="OG" style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 8, flexShrink: 0, border: `1.5px solid ${COLORS.border}` }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 700, color: COLORS.primary, fontSize: 13 }}>Oreille Gauche (OG)</div>
                    <div style={{ color: COLORS.textSecondary, fontSize: 12, marginTop: 2 }}>
                      {leftConduit || '—'} · {leftTympan.length > 0 ? leftTympan.join(', ') : '—'}
                    </div>
                  </div>
                  <Icon name="checkcircle" size={20} color={skipAnalysis ? COLORS.border : COLORS.primary} />
                </div>
              )}
              {rightImagePreview && (
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px',
                  border: `1.5px solid ${skipAnalysis ? COLORS.border : COLORS.secondary + '40'}`,
                  borderRadius: 12, background: skipAnalysis ? COLORS.background : COLORS.secondary + '04',
                  opacity: skipAnalysis ? 0.55 : 1, transition: 'all 0.2s',
                }}>
                  <img src={rightImagePreview} alt="OD" style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 8, flexShrink: 0, border: `1.5px solid ${COLORS.border}` }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 700, color: COLORS.secondary, fontSize: 13 }}>Oreille Droite (OD)</div>
                    <div style={{ color: COLORS.textSecondary, fontSize: 12, marginTop: 2 }}>
                      {rightConduit || '—'} · {rightTympan.length > 0 ? rightTympan.join(', ') : '—'}
                    </div>
                  </div>
                  <Icon name="checkcircle" size={20} color={skipAnalysis ? COLORS.border : COLORS.secondary} />
                </div>
              )}
            </div>

            <button
              onClick={() => setSkipAnalysis(v => !v)}
              style={{
                display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', width: '100%',
                border: `1.5px solid ${skipAnalysis ? COLORS.danger : COLORS.border}`,
                borderRadius: 10, background: skipAnalysis ? COLORS.danger + '08' : '#fff',
                cursor: 'pointer', fontFamily: "'Outfit', sans-serif", fontSize: 13,
                color: skipAnalysis ? COLORS.danger : COLORS.textSecondary,
                transition: 'all 0.15s',
              }}
            >
              <Icon name={skipAnalysis ? 'checkcircle' : 'x'} size={15} color={skipAnalysis ? COLORS.danger : COLORS.textSecondary} />
              {skipAnalysis ? 'Réactiver l\'analyse IA des images' : 'Passer sans analyse IA (documentaire uniquement)'}
            </button>
          </div>
        )}
      </div>
    );

    // Step 6 – Analysis results
    if (step === 6) return (
      <div>
        {diagLoading && (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '64px 0', gap: 18 }}>
            <Spinner size={44} color={COLORS.primary} />
            <p style={{ color: COLORS.textPrimary, fontSize: 16, margin: 0, fontWeight: 600 }}>Analyse en cours…</p>
            <p style={{ color: COLORS.textSecondary, fontSize: 13, margin: 0 }}>
              {wantsAnalysis
                ? `Analyse ${leftImageFile && rightImageFile ? 'des 2 images otoscopiques' : 'de l\'image otoscopique'} + consultation de la base documentaire`
                : 'Consultation de la base documentaire médicale'}
            </p>
          </div>
        )}
        {!diagLoading && (
          <div>
            {/* Vision results: OG and/or OD side by side */}
            {(leftVisionResult || rightVisionResult) && (
              <div style={{
                display: 'grid',
                gridTemplateColumns: (!isMobile && leftVisionResult && rightVisionResult) ? '1fr 1fr' : '1fr',
                gap: 18, marginBottom: 18,
              }}>
                {leftVisionResult && renderVisionCard(leftVisionResult, leftImagePreview, 'Oreille Gauche (OG)', COLORS.primary)}
                {rightVisionResult && renderVisionCard(rightVisionResult, rightImagePreview, 'Oreille Droite (OD)', COLORS.secondary)}
              </div>
            )}

            {/* RAG result: full width below vision cards */}
            {ragResult && (
              <Card padding={22} style={{ border: `2px solid ${COLORS.success}20` }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: COLORS.success + '12', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="filetext" size={18} color={COLORS.success} />
                  </div>
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary }}>Analyse documentaire</div>
                    <div style={{ fontSize: 11, color: COLORS.textSecondary }}>Consultation de la base médicale ORL</div>
                  </div>
                </div>
                {[
                  { label: 'Causes probables', value: ragResult.causes, color: COLORS.primary },
                  { label: 'Signes associés', value: ragResult.signes, color: COLORS.secondary },
                  { label: 'Conduite à tenir', value: ragResult.conduite, color: COLORS.success },
                ].map((s, i) => s.value && (
                  <div key={i} style={{ marginBottom: 14, paddingBottom: 14, borderBottom: i < 2 ? `1px solid ${COLORS.border}` : 'none' }}>
                    <div style={{ fontSize: 11, fontWeight: 700, color: s.color, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 5, display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ display: 'inline-block', width: 3, height: 11, background: s.color, borderRadius: 2 }} />
                      {s.label}
                    </div>
                    <p style={{ margin: 0, fontSize: 13, color: COLORS.textPrimary, lineHeight: 1.6, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                      {s.value}
                    </p>
                  </div>
                ))}
                {ragResult.sources?.length > 0 && (
                  <div>
                    <button onClick={() => setShowRagSources(v => !v)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.secondary, fontSize: 12, fontWeight: 600, fontFamily: "'Outfit', sans-serif", padding: 0, display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Icon name={showRagSources ? 'chevrondown' : 'chevronright'} size={13} color={COLORS.secondary} />
                      {showRagSources ? 'Masquer' : 'Afficher'} les sources ({ragResult.sources.length})
                    </button>
                    {showRagSources && ragResult.sources.map((s, i) => (
                      <div key={i} style={{ padding: '8px 12px', background: COLORS.background, borderRadius: 8, marginTop: 8, fontSize: 12 }}>
                        <div style={{ fontWeight: 600, color: COLORS.textPrimary }}>{s.source}{s.page ? ` · p.${s.page}` : ''}</div>
                        <div style={{ color: COLORS.textSecondary, marginTop: 2 }}>{s.content}</div>
                      </div>
                    ))}
                  </div>
                )}
              </Card>
            )}
          </div>
        )}
      </div>
    );

    return null;
  };

  const validationModal = (
    <Modal open={showModal} onClose={() => !saving && setShowModal(false)} title="Validation par l'expert" width={640}>
      {saved ? (
        <div style={{ textAlign: 'center', padding: '44px 0' }}>
          <div style={{ width: 68, height: 68, borderRadius: '50%', background: COLORS.success + '15', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 18px' }}>
            <Icon name="checkcircle" size={38} color={COLORS.success} />
          </div>
          <h3 style={{ color: COLORS.textPrimary, margin: '0 0 8px', fontSize: 20, fontWeight: 800 }}>Consultation enregistrée</h3>
          <p style={{ color: COLORS.textSecondary, margin: 0 }}>Redirection en cours…</p>
        </div>
      ) : (
        <div>
          <div style={{ background: COLORS.background, borderRadius: 12, padding: '14px 18px', marginBottom: 22 }}>
            <div style={{ fontSize: 11, color: COLORS.textSecondary, marginBottom: 6, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em' }}>Récapitulatif</div>
            <div style={{ fontSize: 15, fontWeight: 700, color: COLORS.textPrimary }}>{patient.prenom} {patient.nom} · {patient.age} ans · {patient.sexe}</div>
            <div style={{ fontSize: 13, color: COLORS.textSecondary, marginTop: 4 }}>
              Symptômes : {allSymptoms.join(', ') || '—'}&nbsp;&nbsp;·&nbsp;&nbsp;Antécédents : {allAntecedents.join(', ') || 'aucun'}
            </div>
            {(leftImagePreview || rightImagePreview) && (
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                {leftImagePreview && <img src={leftImagePreview} alt="OG" style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 8, border: `1.5px solid ${COLORS.primary}40` }} />}
                {rightImagePreview && <img src={rightImagePreview} alt="OD" style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 8, border: `1.5px solid ${COLORS.secondary}40` }} />}
              </div>
            )}
          </div>

          {anyVisionResult && (
            <div style={{ marginBottom: 22 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary, marginBottom: 10 }}>
                Évaluation de l'analyse image
              </div>
              {leftVisionResult && (
                <div style={{ padding: '8px 12px', background: COLORS.primary + '08', borderRadius: 8, marginBottom: 6, fontSize: 13 }}>
                  <span style={{ fontWeight: 700, color: COLORS.primary }}>OG :</span>{' '}
                  <span style={{ textTransform: 'capitalize' }}>{leftVisionResult.prediction}</span>{' '}
                  <span style={{ color: COLORS.textSecondary }}>({leftVisionResult.confidence.toFixed(1)}%)</span>
                </div>
              )}
              {rightVisionResult && (
                <div style={{ padding: '8px 12px', background: COLORS.secondary + '08', borderRadius: 8, marginBottom: 10, fontSize: 13 }}>
                  <span style={{ fontWeight: 700, color: COLORS.secondary }}>OD :</span>{' '}
                  <span style={{ textTransform: 'capitalize' }}>{rightVisionResult.prediction}</span>{' '}
                  <span style={{ color: COLORS.textSecondary }}>({rightVisionResult.confidence.toFixed(1)}%)</span>
                </div>
              )}
              <div style={{ display: 'flex', gap: 10 }}>
                {[{ val: true, label: '✓ Confirmer', col: COLORS.success }, { val: false, label: '✗ Infirmer', col: COLORS.danger }].map(opt => (
                  <button key={String(opt.val)} onClick={() => setVisionValidated(opt.val)} style={{
                    flex: 1, padding: '11px', borderRadius: 10, cursor: 'pointer',
                    fontFamily: "'Outfit', sans-serif", fontSize: 14, fontWeight: 600,
                    border: `2px solid ${visionValidated === opt.val ? opt.col : COLORS.border}`,
                    background: visionValidated === opt.val ? opt.col + '10' : '#fff',
                    color: visionValidated === opt.val ? opt.col : COLORS.textSecondary,
                  }}>{opt.label}</button>
                ))}
              </div>
              {visionValidated === false && (
                <textarea value={visionComment} onChange={e => setVisionComment(e.target.value)} placeholder="Motif de désaccord avec l'analyse image…" rows={2}
                  style={{ width: '100%', marginTop: 8, padding: '10px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 8, fontSize: 13, fontFamily: "'Outfit', sans-serif", outline: 'none', resize: 'vertical', boxSizing: 'border-box' }} />
              )}
            </div>
          )}

          {ragResult && (
            <div style={{ marginBottom: 22 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.textPrimary, marginBottom: 8 }}>
                Évaluation de l'analyse documentaire
              </div>
              <div style={{ fontSize: 12, color: COLORS.textSecondary, marginBottom: 10, padding: '10px 14px', background: COLORS.background, borderRadius: 10, fontStyle: 'italic', lineHeight: 1.5 }}>
                {(ragResult.causes || ragResult.fullText || '').slice(0, 130)}…
              </div>
              <div style={{ display: 'flex', gap: 10 }}>
                {[{ val: true, label: '✓ Pertinente', col: COLORS.success }, { val: false, label: '✗ Non pertinente', col: COLORS.danger }].map(opt => (
                  <button key={String(opt.val)} onClick={() => setRagValidated(opt.val)} style={{
                    flex: 1, padding: '11px', borderRadius: 10, cursor: 'pointer',
                    fontFamily: "'Outfit', sans-serif", fontSize: 14, fontWeight: 600,
                    border: `2px solid ${ragValidated === opt.val ? opt.col : COLORS.border}`,
                    background: ragValidated === opt.val ? opt.col + '10' : '#fff',
                    color: ragValidated === opt.val ? opt.col : COLORS.textSecondary,
                  }}>{opt.label}</button>
                ))}
              </div>
              {ragValidated === false && (
                <textarea value={ragComment} onChange={e => setRagComment(e.target.value)} placeholder="Motif de désaccord avec l'analyse documentaire…" rows={2}
                  style={{ width: '100%', marginTop: 8, padding: '10px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 8, fontSize: 13, fontFamily: "'Outfit', sans-serif", outline: 'none', resize: 'vertical', boxSizing: 'border-box' }} />
              )}
            </div>
          )}

          <div style={{ marginBottom: 18 }}>
            <label style={{ display: 'block', marginBottom: 7, fontSize: 13, fontWeight: 700, color: COLORS.textSecondary }}>
              Diagnostic final de l'expert <span style={{ color: COLORS.danger }}>*</span>
            </label>
            <input value={expertDiagnosis} onChange={e => setExpertDiagnosis(e.target.value)}
              placeholder="Ex : Otite moyenne aiguë purulente"
              style={{ width: '100%', padding: '12px 16px', border: `2px solid ${expertDiagnosis ? COLORS.primary : COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', boxSizing: 'border-box', fontWeight: 500 }} />
          </div>
          <div style={{ marginBottom: 26 }}>
            <label style={{ display: 'block', marginBottom: 7, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
              Commentaire clinique (optionnel)
            </label>
            <textarea value={expertComment} onChange={e => setExpertComment(e.target.value)}
              placeholder="Observations, remarques cliniques, plan de suivi…" rows={3}
              style={{ width: '100%', padding: '12px 16px', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', resize: 'vertical', boxSizing: 'border-box' }} />
          </div>

          <button onClick={handleSave} disabled={!expertDiagnosis || saving} style={{
            width: '100%', padding: '15px', borderRadius: 12,
            background: expertDiagnosis ? COLORS.primary : COLORS.border,
            color: 'white', border: 'none', fontFamily: "'Outfit', sans-serif",
            fontSize: 15, fontWeight: 700, cursor: expertDiagnosis ? 'pointer' : 'not-allowed',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            boxShadow: expertDiagnosis ? `0 4px 14px ${COLORS.primary}35` : 'none',
          }}>
            {saving ? <><Spinner size={18} color="white" /> Enregistrement…</> : <><Icon name="checkcircle" size={18} color="white" /> Enregistrer la consultation</>}
          </button>
        </div>
      )}
    </Modal>
  );

  return (
    <div style={{ fontFamily: "'Outfit', sans-serif" }}>
      <PageHeader
        title="Nouvelle consultation"
        subtitle={`Étape ${step + 1} sur ${STEPS.length} · ${STEPS[step]}`}
      />
      <div style={{ padding: isMobile ? '12px 10px' : '28px 32px' }}>
        {/* Step indicator */}
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 32, overflowX: 'auto', paddingBottom: 4 }}>
          {STEPS.map((s, i) => (
            <React.Fragment key={s}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, flexShrink: 0 }}>
                <div style={{
                  width: 34, height: 34, borderRadius: '50%',
                  background: i < step ? COLORS.success : i === step ? COLORS.primary : COLORS.background,
                  border: `2px solid ${i < step ? COLORS.success : i === step ? COLORS.primary : COLORS.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: i <= step ? 'white' : COLORS.textSecondary,
                  fontSize: 12, fontWeight: 700, transition: 'all 0.3s',
                  boxShadow: i === step ? `0 0 0 4px ${COLORS.primary}18` : 'none',
                }}>
                  {i < step ? <Icon name="check" size={15} color="white" /> : i + 1}
                </div>
                <span style={{ fontSize: 12, fontWeight: i === step ? 700 : 500, color: i === step ? COLORS.primary : COLORS.textSecondary, whiteSpace: 'nowrap' }}>
                  {s}
                </span>
              </div>
              {i < STEPS.length - 1 && (
                <div style={{ flex: 1, height: 2, background: i < step ? COLORS.success : COLORS.border, marginBottom: 20, minWidth: 12, transition: 'background 0.3s' }} />
              )}
            </React.Fragment>
          ))}
        </div>

        {/* Main card — widened to 960 px, full-width on mobile */}
        <Card padding={isMobile ? 16 : 34} style={{ maxWidth: 960 }}>
          <h2 style={{ margin: '0 0 24px', fontSize: 19, fontWeight: 800, color: COLORS.textPrimary, letterSpacing: '-0.2px' }}>
            {STEPS[step]}
          </h2>
          {renderStep()}

          {/* Navigation — always visible on steps 0-6 */}
          {step <= 6 && (
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 34, paddingTop: 24, borderTop: `1px solid ${COLORS.border}` }}>
              <Button
                variant="ghost"
                icon="chevronleft"
                onClick={handleBack}
                disabled={step === 0 || (step === 6 && diagLoading)}
              >
                Précédent
              </Button>

              {step < 6 && (
                <Button variant="primary" iconRight="chevronright" onClick={() => setStep(s => s + 1)} disabled={!canNext()}>
                  Suivant
                </Button>
              )}

              {step === 6 && !diagLoading && (
                <div style={{ display: 'flex', gap: 10 }}>
                  <Button variant="ghost" icon="refresh" onClick={() => {
                    setLeftVisionResult(null);
                    setRightVisionResult(null);
                    setRagResult(null);
                    runDiagnosis();
                  }}>
                    Relancer l'analyse
                  </Button>
                  <Button variant="primary" icon="checkcircle" onClick={() => setShowModal(true)} disabled={!ragResult}>
                    Valider et conclure
                  </Button>
                </div>
              )}

              {step === 6 && diagLoading && <div />}
            </div>
          )}
        </Card>
      </div>
      {validationModal}
    </div>
  );
};

export default NewConsultation;