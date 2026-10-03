import React from 'react';
import { COLORS, API } from '../shared';
import Icon from './Icon';

const PATHOLOGIES = [
  'aspect post tympanoplastie',
  'bouchon de cerumen',
  'cholestéatome',
  'corps étranger oreille',
  'myringosclerose',
  'otite moyenne aigue',
  'otite séromuqueuse',
  'otomycose',
  'perforation tympanique',
  'tympan normal',
] as const;

type Pathology = typeof PATHOLOGIES[number];

interface ImageEntry {
  id: string;
  file: File;
  preview: string;
  pathology: Pathology | '';
  status: 'pending' | 'uploading' | 'success' | 'error';
  driveUrl?: string | null;
  storage?: 'drive' | 'local';
  error?: string;
}

function useIsMobile() {
  const [v, setV] = React.useState(() => window.innerWidth < 768);
  React.useEffect(() => {
    const h = () => setV(window.innerWidth < 768);
    window.addEventListener('resize', h);
    return () => window.removeEventListener('resize', h);
  }, []);
  return v;
}

// ── ImageCard ──────────────────────────────────────────────────────────────────
const ImageCard: React.FC<{
  entry: ImageEntry;
  onPathologyChange: (p: Pathology) => void;
  onRemove: () => void;
}> = ({ entry, onPathologyChange, onRemove }) => {
  const statusColor: Record<ImageEntry['status'], string> = {
    pending: COLORS.textSecondary,
    uploading: COLORS.warning,
    success: COLORS.success,
    error: COLORS.danger,
  };
  const statusLabel: Record<ImageEntry['status'], string> = {
    pending: entry.pathology ? 'Prêt' : 'Pathologie manquante',
    uploading: 'Envoi…',
    success: 'Envoyé',
    error: 'Erreur',
  };

  return (
    <div style={{
      background: COLORS.cardBg,
      border: `1.5px solid ${
        entry.status === 'success' ? COLORS.success + '50'
        : entry.status === 'error' ? COLORS.danger + '50'
        : COLORS.border
      }`,
      borderRadius: 14,
      overflow: 'hidden',
      boxShadow: '0 1px 6px rgba(0,0,0,0.06)',
      transition: 'border-color 0.2s',
    }}>
      {/* Thumbnail */}
      <div style={{ position: 'relative', height: 150, background: COLORS.background }}>
        <img src={entry.preview} alt="preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />

        {entry.status === 'uploading' && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ color: 'white', fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 16, height: 16, border: '2px solid white', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
              Envoi…
            </div>
          </div>
        )}

        {entry.status === 'success' && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(16,185,129,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ background: COLORS.success, borderRadius: '50%', width: 34, height: 34, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="check" size={17} color="white" />
            </div>
          </div>
        )}

        {entry.status !== 'uploading' && (
          <button
            onClick={onRemove}
            style={{
              position: 'absolute', top: 7, right: 7,
              width: 24, height: 24, borderRadius: '50%',
              background: 'rgba(0,0,0,0.5)', border: 'none',
              cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            <Icon name="x" size={12} color="white" />
          </button>
        )}

        <div style={{
          position: 'absolute', bottom: 7, left: 7,
          background: statusColor[entry.status] + 'DD',
          color: 'white', padding: '2px 8px', borderRadius: 99,
          fontSize: 11, fontWeight: 600, backdropFilter: 'blur(4px)',
        }}>
          {statusLabel[entry.status]}
        </div>
      </div>

      {/* Controls */}
      <div style={{ padding: '10px 12px' }}>
        <div style={{ fontSize: 11, color: COLORS.textSecondary, marginBottom: 7, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {entry.file.name}
        </div>

        {(entry.status === 'pending' || entry.status === 'error') && (
          <select
            value={entry.pathology}
            onChange={e => onPathologyChange(e.target.value as Pathology)}
            style={{
              width: '100%',
              border: `1.5px solid ${entry.pathology ? COLORS.border : COLORS.warning + '90'}`,
              borderRadius: 8, padding: '6px 8px', fontSize: 11,
              fontFamily: "'Outfit', sans-serif",
              color: entry.pathology ? COLORS.textPrimary : COLORS.textSecondary,
              background: COLORS.background, outline: 'none', cursor: 'pointer',
            }}
          >
            <option value="">— Sélectionner la pathologie —</option>
            {PATHOLOGIES.map(p => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
        )}

        {entry.status === 'success' && (
          <div style={{ fontSize: 11, color: COLORS.success, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 5 }}>
            <Icon name="checkcircle" size={12} color={COLORS.success} />
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>{entry.pathology}</span>
            {entry.storage === 'local' && (
              <span title="Sauvegardé localement (Drive désactivé)" style={{ fontSize: 10, color: COLORS.textSecondary, background: COLORS.background, borderRadius: 4, padding: '1px 5px', border: `1px solid ${COLORS.border}` }}>local</span>
            )}
            {entry.driveUrl && (
              <a href={entry.driveUrl} target="_blank" rel="noopener noreferrer" style={{ flexShrink: 0 }}>
                <Icon name="eye" size={13} color={COLORS.primary} />
              </a>
            )}
          </div>
        )}

        {entry.status === 'uploading' && (
          <div style={{ fontSize: 11, color: COLORS.textSecondary }}>{entry.pathology}</div>
        )}

        {entry.status === 'error' && entry.error && (
          <div style={{ marginTop: 5, fontSize: 11, color: COLORS.danger, lineHeight: 1.4 }}>{entry.error}</div>
        )}
      </div>
    </div>
  );
};

// ── DatasetCollection (main page) ─────────────────────────────────────────────
const DatasetCollection: React.FC = () => {
  const isMobile = useIsMobile();
  const [entries, setEntries] = React.useState<ImageEntry[]>([]);
  const [dragOver, setDragOver] = React.useState(false);
  const [uploading, setUploading] = React.useState(false);
  const fileRef = React.useRef<HTMLInputElement>(null);

  const addFiles = (files: FileList | File[]) => {
    const next: ImageEntry[] = Array.from(files)
      .filter(f => f.type.startsWith('image/'))
      .map(f => ({
        id: Math.random().toString(36).slice(2),
        file: f,
        preview: URL.createObjectURL(f),
        pathology: '',
        status: 'pending',
      }));
    setEntries(prev => [...prev, ...next]);
  };

  const setPathology = (id: string, pathology: Pathology) =>
    setEntries(prev => prev.map(e => e.id === id ? { ...e, pathology } : e));

  const removeEntry = (id: string) => {
    setEntries(prev => {
      const entry = prev.find(e => e.id === id);
      if (entry) URL.revokeObjectURL(entry.preview);
      return prev.filter(e => e.id !== id);
    });
  };

  const clearAll = () => {
    entries.forEach(e => URL.revokeObjectURL(e.preview));
    setEntries([]);
  };

  const pendingReady = entries.filter(e => e.status === 'pending' && e.pathology !== '');
  const successCount = entries.filter(e => e.status === 'success').length;
  const errorCount = entries.filter(e => e.status === 'error').length;

  const uploadAll = async () => {
    if (pendingReady.length === 0) return;
    setUploading(true);
    for (const entry of pendingReady) {
      setEntries(prev => prev.map(e => e.id === entry.id ? { ...e, status: 'uploading' } : e));
      try {
        const res = await API.uploadDatasetImage(entry.file, entry.pathology);
        setEntries(prev => prev.map(e =>
          e.id === entry.id
            ? { ...e, status: 'success' as const, driveUrl: res.drive_url, storage: (res as { storage?: 'drive' | 'local' }).storage }
            : e
        ));
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Erreur inconnue';
        setEntries(prev => prev.map(e =>
          e.id === entry.id ? { ...e, status: 'error', error: msg } : e
        ));
      }
    }
    setUploading(false);
  };

  return (
    <div style={{ padding: isMobile ? '12px 10px' : '28px 32px', maxWidth: 1000, margin: '0 auto' }}>

      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div style={{ marginBottom: 22 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
          <div style={{
            width: 42, height: 42, borderRadius: 12,
            background: COLORS.primary + '15',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <Icon name="upload" size={20} color={COLORS.primary} />
          </div>
          <div>
            <h1 style={{ margin: 0, fontSize: isMobile ? 19 : 24, fontWeight: 800, color: COLORS.textPrimary, letterSpacing: '-0.4px' }}>
              Collecte de données
            </h1>
            <p style={{ margin: 0, fontSize: 13, color: COLORS.textSecondary }}>
              Enrichissement du dataset otoscopique — 10 pathologies
            </p>
          </div>
        </div>

        <div style={{
          background: COLORS.primary + '08',
          border: `1px solid ${COLORS.primary}22`,
          borderRadius: 10, padding: '10px 14px',
          fontSize: 13, color: COLORS.textSecondary,
          display: 'flex', gap: 8, alignItems: 'flex-start',
        }}>
          <Icon name="info" size={15} color={COLORS.primary} style={{ flexShrink: 0, marginTop: 1 }} />
          <span>
            Les images sont enregistrées dans Google Drive sous{' '}
            <strong style={{ color: COLORS.textPrimary }}>KORAI-Medical/dataset/{'{'}{'{'}pathologie{'}'}{'}'}/</strong>.
            Sélectionnez la pathologie pour chaque image avant l'envoi.
            {' '}Google Drive doit être activé sur le serveur (<code>GOOGLE_DRIVE_ENABLED=true</code>).
          </span>
        </div>
      </div>

      {/* ── Drop zone ──────────────────────────────────────────────────────── */}
      <div
        onDrop={e => { e.preventDefault(); setDragOver(false); addFiles(e.dataTransfer.files); }}
        onDragOver={e => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onClick={() => fileRef.current?.click()}
        style={{
          border: `2px dashed ${dragOver ? COLORS.primary : COLORS.border}`,
          borderRadius: 16,
          padding: isMobile ? '28px 16px' : '44px 32px',
          textAlign: 'center',
          cursor: 'pointer',
          background: dragOver ? COLORS.primary + '06' : COLORS.cardBg,
          transition: 'all 0.18s',
          marginBottom: 22,
        }}
      >
        <input ref={fileRef} type="file" accept="image/*" multiple style={{ display: 'none' }}
          onChange={e => { if (e.target.files) addFiles(e.target.files); e.target.value = ''; }} />
        <Icon name="upload" size={30} color={dragOver ? COLORS.primary : COLORS.textSecondary} />
        <p style={{ margin: '10px 0 3px', fontWeight: 700, color: dragOver ? COLORS.primary : COLORS.textPrimary, fontSize: 15 }}>
          {dragOver ? 'Relâchez pour ajouter les images' : 'Déposez vos images otoscopiques ici'}
        </p>
        <p style={{ margin: 0, fontSize: 13, color: COLORS.textSecondary }}>
          ou cliquez pour sélectionner &mdash; JPG, PNG, WEBP &mdash; plusieurs fichiers acceptés
        </p>
      </div>

      {/* ── Toolbar ────────────────────────────────────────────────────────── */}
      {entries.length > 0 && (
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          flexWrap: 'wrap', gap: 10, marginBottom: 18,
        }}>
          <div style={{ fontSize: 13, color: COLORS.textSecondary, lineHeight: 1.6 }}>
            <strong style={{ color: COLORS.textPrimary }}>{entries.length}</strong> image{entries.length > 1 ? 's' : ''}
            {pendingReady.length > 0 && (
              <> · <strong style={{ color: COLORS.primary }}>{pendingReady.length}</strong> prête{pendingReady.length > 1 ? 's' : ''}</>
            )}
            {entries.filter(e => e.status === 'pending' && !e.pathology).length > 0 && (
              <> · <strong style={{ color: COLORS.warning }}>{entries.filter(e => e.status === 'pending' && !e.pathology).length}</strong> sans pathologie</>
            )}
            {successCount > 0 && (
              <> · <strong style={{ color: COLORS.success }}>{successCount}</strong> envoyée{successCount > 1 ? 's' : ''}</>
            )}
            {errorCount > 0 && (
              <> · <strong style={{ color: COLORS.danger }}>{errorCount}</strong> erreur{errorCount > 1 ? 's' : ''}</>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button
              onClick={clearAll}
              disabled={uploading}
              style={{
                padding: '8px 14px', borderRadius: 8,
                border: `1px solid ${COLORS.border}`,
                background: 'white', color: COLORS.textSecondary,
                cursor: uploading ? 'not-allowed' : 'pointer',
                fontSize: 13, fontFamily: "'Outfit', sans-serif",
              }}
            >
              Tout effacer
            </button>
            <button
              onClick={uploadAll}
              disabled={pendingReady.length === 0 || uploading}
              style={{
                padding: '8px 18px', borderRadius: 8, border: 'none',
                background: pendingReady.length > 0 && !uploading ? COLORS.primary : COLORS.border,
                color: 'white',
                cursor: pendingReady.length > 0 && !uploading ? 'pointer' : 'not-allowed',
                fontSize: 13, fontWeight: 600, fontFamily: "'Outfit', sans-serif",
                display: 'flex', alignItems: 'center', gap: 7,
                transition: 'background 0.15s',
              }}
            >
              <Icon name="upload" size={14} color="white" />
              Envoyer sur Drive ({pendingReady.length})
            </button>
          </div>
        </div>
      )}

      {/* ── Image grid ─────────────────────────────────────────────────────── */}
      {entries.length > 0 && (
        <div style={{
          display: 'grid',
          gridTemplateColumns: isMobile ? '1fr 1fr' : 'repeat(auto-fill, minmax(230px, 1fr))',
          gap: 14,
        }}>
          {entries.map(entry => (
            <ImageCard
              key={entry.id}
              entry={entry}
              onPathologyChange={p => setPathology(entry.id, p)}
              onRemove={() => removeEntry(entry.id)}
            />
          ))}
        </div>
      )}

      {/* ── Empty state ─────────────────────────────────────────────────────── */}
      {entries.length === 0 && (
        <div style={{ textAlign: 'center', padding: '48px 0', color: COLORS.textSecondary }}>
          <Icon name="image" size={44} color={COLORS.border} />
          <p style={{ marginTop: 14, fontSize: 15, fontWeight: 600, color: COLORS.textSecondary }}>
            Aucune image sélectionnée
          </p>
          <p style={{ margin: '4px 0 0', fontSize: 13 }}>
            Déposez des photos otoscopiques pour enrichir le modèle de vision
          </p>

          {/* Pathologie chips — aide visuelle */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, justifyContent: 'center', marginTop: 20, maxWidth: 560, margin: '20px auto 0' }}>
            {PATHOLOGIES.map(p => (
              <span key={p} style={{
                padding: '4px 10px', borderRadius: 99, fontSize: 11, fontWeight: 500,
                background: COLORS.primary + '10', color: COLORS.primary,
                border: `1px solid ${COLORS.primary}20`,
              }}>
                {p}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default DatasetCollection;