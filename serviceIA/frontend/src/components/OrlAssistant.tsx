import React from 'react';
import { COLORS, API } from '../shared';
import { Spinner } from './UI';
import Icon from './Icon';

interface Source {
  source: string;
  page?: number;
  content?: string;
}

interface Message {
  role: 'user' | 'assistant';
  content: string;
  sources?: Source[];
}

const QUICK_QUESTIONS = [
  "Qu'est-ce que l'otite moyenne aiguë ?",
  "Signes d'un cholestéatome",
  "Traitement de l'otomycose",
  "Causes d'acouphènes chroniques",
  "Perforation tympanique : conduite à tenir",
];

const ORL_INFO_TOPICS = [
  {
    q: "Qu'est-ce que l'otite moyenne aiguë ?",
    a: "L'otite moyenne aiguë (OMA) est une infection de l'oreille moyenne, fréquente chez l'enfant. Elle se manifeste par une otalgie intense, une fièvre, parfois une otorrhée en cas de perforation. Le traitement repose sur l'amoxicilline chez les jeunes enfants, avec analgésiques. Une réévaluation à 48h est recommandée si pas d'amélioration."
  },
  {
    q: "Signes d'un cholestéatome",
    a: "Le cholestéatome est une accumulation épidermique dans l'oreille moyenne. Signes évocateurs : otorrhée chronique fétide unilatérale, hypoacousie progressive, présence d'une poche de rétraction ou d'une perlacée visible à l'otoscopie. C'est une urgence chirurgicale relative car il peut éroder les osselets et les structures adjacentes."
  },
  {
    q: "Traitement de l'otomycose",
    a: "L'otomycose (infection fongique du CAE) est traitée par un nettoyage soigneux au microscope, des antifongiques topiques (clotrimazole, nystatine) pendant 2 à 3 semaines, et une acidification du milieu. Il faut éviter l'humidité et les coton-tiges. Les récidives sont fréquentes chez les baigneurs et les diabétiques."
  },
  {
    q: "Causes d'acouphènes chroniques",
    a: "Les acouphènes chroniques ont de multiples causes : exposition au bruit, traumatisme acoustique, presbyacousie, maladie de Ménière, névrome acoustique, otospongiose, bouchon de cérumen, hypertension artérielle, médicaments ototoxiques (aminosides, aspirine à haute dose). Un bilan audiométrique complet est nécessaire."
  },
  {
    q: "Perforation tympanique : conduite à tenir",
    a: "Face à une perforation tympanique, il faut protéger l'oreille de l'eau, envisager une antibiothérapie locale si otorrhée, et éviter les mouchages violents. Si la perforation ne se ferme pas spontanément en 3 mois, une tympanoplastie chirurgicale peut être indiquée. Les perforations centrales guérissent mieux que les perforations marginales."
  },
];

function useIsMobile() {
  const [isMobile, setIsMobile] = React.useState(() => window.innerWidth < 768);
  React.useEffect(() => {
    const handler = () => setIsMobile(window.innerWidth < 768);
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  }, []);
  return isMobile;
}

function AssistantBubble({ content, sources }: { content: string; sources?: Source[] }) {
  const paragraphs = content.split(/\n\n+/).filter(p => p.trim());
  return (
    <div style={{
      maxWidth: '85%',
      padding: '12px 14px',
      borderRadius: '14px 14px 14px 4px',
      background: COLORS.background,
      color: COLORS.textPrimary,
      fontSize: 13, lineHeight: 1.7, fontWeight: 400,
      border: `1px solid ${COLORS.border}`,
    }}>
      {paragraphs.length > 1 ? (
        paragraphs.map((p, i) => (
          <p key={i} style={{ margin: i === 0 ? '0 0 10px 0' : '0 0 10px 0', ...(i === paragraphs.length - 1 ? { marginBottom: 0 } : {}) }}>
            {p.trim()}
          </p>
        ))
      ) : (
        <span>{content}</span>
      )}
      {sources && sources.length > 0 && (
        <div style={{
          marginTop: 12,
          paddingTop: 10,
          borderTop: `1px solid ${COLORS.border}`,
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: COLORS.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 6 }}>
            Sources documentaires
          </div>
          {sources.map((s, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'flex-start', gap: 6,
              padding: '5px 8px', borderRadius: 6,
              background: COLORS.primary + '08',
              border: `1px solid ${COLORS.primary}18`,
              marginBottom: i < sources.length - 1 ? 4 : 0,
            }}>
              <Icon name="file-text" size={11} color={COLORS.primary} style={{ marginTop: 2, flexShrink: 0 }} />
              <div>
                <span style={{ fontSize: 11, fontWeight: 600, color: COLORS.primary }}>
                  {s.source || 'Document ORL'}
                </span>
                {s.page != null && (
                  <span style={{ fontSize: 10, color: COLORS.textSecondary, marginLeft: 4 }}>
                    p. {s.page}
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const OrlAssistant: React.FC = () => {
  const isMobile = useIsMobile();
  const [open, setOpen] = React.useState(false);
  const [minimized, setMinimized] = React.useState(false);
  const [messages, setMessages] = React.useState<Message[]>([
    {
      role: 'assistant',
      content: "Bonjour ! Je suis votre assistant médical ORL. Posez-moi vos questions sur les pathologies de l'oreille, les traitements ou les protocoles cliniques.",
    },
  ]);
  const [input, setInput] = React.useState('');
  const [loading, setLoading] = React.useState(false);
  const [pulse, setPulse] = React.useState(false);
  const msgEnd = React.useRef<HTMLDivElement>(null);
  const inputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => {
    msgEnd.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  React.useEffect(() => {
    const interval = setInterval(() => {
      setPulse(true);
      setTimeout(() => setPulse(false), 600);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

  React.useEffect(() => {
    if (open && isMobile) {
      setTimeout(() => inputRef.current?.focus(), 300);
    }
  }, [open, isMobile]);

  const sendMessage = async (text?: string) => {
    const msg = text || input;
    if (!msg.trim()) return;
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: msg }]);
    setLoading(true);

    const localInfo = ORL_INFO_TOPICS.find(
      t => t.q.toLowerCase() === msg.toLowerCase() || msg.toLowerCase().includes(t.q.toLowerCase().slice(0, 20))
    );
    if (localInfo) {
      setTimeout(() => {
        setMessages(prev => [...prev, { role: 'assistant', content: localInfo.a }]);
        setLoading(false);
      }, 500);
      return;
    }

    // Placeholder vide qui sera rempli token par token
    setMessages(prev => [...prev, { role: 'assistant', content: '', sources: [] }]);

    API.chatStream(
      msg,
      (token) => {
        setMessages(prev => {
          const updated = [...prev];
          const last = updated[updated.length - 1];
          if (last?.role === 'assistant') {
            updated[updated.length - 1] = { ...last, content: last.content + token };
          }
          return updated;
        });
      },
      (sources) => {
        setMessages(prev => {
          const updated = [...prev];
          const last = updated[updated.length - 1];
          if (last?.role === 'assistant') {
            updated[updated.length - 1] = { ...last, sources };
          }
          return updated;
        });
        setLoading(false);
      },
      (err) => {
        const isTimeout = err.name === 'AbortError';
        setMessages(prev => {
          const updated = [...prev];
          const last = updated[updated.length - 1];
          if (last?.role === 'assistant') {
            updated[updated.length - 1] = {
              ...last,
              content: isTimeout
                ? 'Le serveur met trop de temps à répondre. Réessayez dans un instant.'
                : 'Je suis actuellement hors ligne. Vérifiez que le backend est démarré sur http://localhost:8000.',
            };
          }
          return updated;
        });
        setLoading(false);
      },
    );
  };

  if (!open) {
    const fabBottom = isMobile ? 16 : 28;
    const fabRight = isMobile ? 16 : 28;
    return (
      <div style={{ position: 'fixed', bottom: fabBottom, right: fabRight, zIndex: 999 }}>
        <button
          onClick={() => setOpen(true)}
          style={{
            width: 56, height: 56, borderRadius: '50%',
            background: `linear-gradient(135deg, ${COLORS.primary}, #1558CC)`,
            border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 8px 24px ${COLORS.primary}50`,
            transition: 'transform 0.2s, box-shadow 0.2s',
            transform: pulse ? 'scale(1.08)' : 'scale(1)',
            position: 'relative',
          }}
          title="Assistant médical ORL"
        >
          <svg width="28" height="28" viewBox="0 0 40 40" fill="none">
            <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white"/>
            <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.9)" strokeWidth="1.8" strokeLinecap="round" fill="none"/>
            <circle cx="20" cy="15" r="2.5" fill="rgba(147,197,253,0.95)"/>
            <circle cx="20" cy="15" r="4.5" fill="none" stroke="rgba(147,197,253,0.5)" strokeWidth="1.2"/>
          </svg>
          <div style={{
            position: 'absolute', inset: -4, borderRadius: '50%',
            border: `2px solid ${COLORS.primary}`,
            animation: 'pulse-ring 2.5s ease-out infinite',
            opacity: 0.5,
          }} />
          <div style={{
            position: 'absolute', top: -4, right: -4,
            width: 18, height: 18, borderRadius: '50%',
            background: COLORS.success, border: '2px solid white',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name="help-circle" size={10} color="white" />
          </div>
        </button>
        {!isMobile && (
          <div style={{
            position: 'absolute', bottom: 66, right: 0,
            background: COLORS.textPrimary, color: 'white',
            padding: '6px 12px', borderRadius: 8, fontSize: 12, fontWeight: 600,
            whiteSpace: 'nowrap', fontFamily: "'Outfit', sans-serif",
            boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
            opacity: pulse ? 1 : 0, transition: 'opacity 0.3s',
            pointerEvents: 'none',
          }}>
            Assistant médical ORL
          </div>
        )}
      </div>
    );
  }

  const mobileSheet = isMobile;

  const containerStyle: React.CSSProperties = mobileSheet ? {
    position: 'fixed',
    bottom: 0, left: 0, right: 0,
    zIndex: 999,
    width: 'auto',
    height: '85dvh',
    background: COLORS.cardBg,
    borderRadius: '20px 20px 0 0',
    boxShadow: '0 -8px 40px rgba(0,0,0,0.22)',
    display: 'flex', flexDirection: 'column',
    border: `1px solid ${COLORS.border}`,
    borderBottom: 'none',
    overflow: 'hidden',
    animation: 'slideUp 0.28s cubic-bezier(0.32,0.72,0,1)',
    fontFamily: "'Outfit', sans-serif",
  } : {
    position: 'fixed', bottom: 28, right: 28, zIndex: 999,
    width: minimized ? 320 : 420,
    background: COLORS.cardBg,
    borderRadius: 20,
    boxShadow: '0 20px 60px rgba(0,0,0,0.22)',
    display: 'flex', flexDirection: 'column',
    border: `1px solid ${COLORS.border}`,
    overflow: 'hidden',
    animation: 'fadeIn 0.25s ease-out',
    fontFamily: "'Outfit', sans-serif",
  };

  return (
    <>
      {mobileSheet && (
        <div
          onClick={() => setOpen(false)}
          style={{
            position: 'fixed', inset: 0, zIndex: 998,
            background: 'rgba(0,0,0,0.35)',
            animation: 'fadeIn 0.2s ease',
          }}
        />
      )}

      <div style={containerStyle}>
        {mobileSheet && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '10px 0 4px' }}>
            <div style={{ width: 40, height: 4, borderRadius: 2, background: COLORS.border }} />
          </div>
        )}

        {/* Header */}
        <div style={{
          background: 'linear-gradient(167deg, rgb(16, 39, 93) 0%, #4f6dff 100%)',
          padding: mobileSheet ? '12px 16px' : '16px 20px',
          display: 'flex', alignItems: 'center', gap: 12,
          flexShrink: 0,
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10,
            background: 'rgba(255,255,255,0.12)',
            border: '1px solid rgba(255,255,255,0.2)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <svg width="20" height="20" viewBox="0 0 40 40" fill="none">
              <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white"/>
              <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.9)" strokeWidth="1.8" strokeLinecap="round" fill="none"/>
              <circle cx="20" cy="15" r="2.5" fill="rgba(147,197,253,0.95)"/>
            </svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: mobileSheet ? 13 : 14, fontWeight: 700, color: 'white' }}>Assistant médical ORL</div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', marginTop: 1 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <span style={{ width: 6, height: 6, background: COLORS.success, borderRadius: '50%', display: 'inline-block' }} />
                Disponible · Pathologies auriculaires
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {!mobileSheet && (
              <button
                onClick={() => setMinimized(m => !m)}
                style={{ width: 28, height: 28, borderRadius: 8, background: 'rgba(255,255,255,0.1)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
              >
                <Icon name={minimized ? 'maximize' : 'minimize'} size={13} color="rgba(255,255,255,0.7)" />
              </button>
            )}
            <button
              onClick={() => setOpen(false)}
              style={{ width: 28, height: 28, borderRadius: 8, background: 'rgba(255,255,255,0.1)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
            >
              <Icon name="x" size={13} color="rgba(255,255,255,0.7)" />
            </button>
          </div>
        </div>

        {(!minimized || mobileSheet) && (
          <>
            {/* Messages */}
            <div style={{
              flex: 1,
              overflowY: 'auto',
              padding: '16px',
              display: 'flex', flexDirection: 'column', gap: 12,
              ...(mobileSheet ? {} : { maxHeight: 420, minHeight: 200 }),
            }}>
              {messages.map((m, i) => (
                <div key={i} style={{ display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start' }}>
                  {m.role === 'assistant' && (
                    <div style={{ width: 28, height: 28, borderRadius: '50%', background: COLORS.primary + '15', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginRight: 8, alignSelf: 'flex-start', marginTop: 2 }}>
                      <Icon name="brain" size={14} color={COLORS.primary} />
                    </div>
                  )}
                  {m.role === 'assistant' ? (
                    <AssistantBubble content={m.content} sources={m.sources} />
                  ) : (
                    <div style={{
                      maxWidth: '80%',
                      padding: '10px 14px',
                      borderRadius: '14px 14px 4px 14px',
                      background: COLORS.primary,
                      color: 'white',
                      fontSize: 13, lineHeight: 1.6, fontWeight: 400,
                    }}>
                      {m.content}
                    </div>
                  )}
                </div>
              ))}
              {loading && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0' }}>
                  <div style={{ width: 28, height: 28, borderRadius: '50%', background: COLORS.primary + '15', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Icon name="brain" size={14} color={COLORS.primary} />
                  </div>
                  <div style={{ background: COLORS.background, border: `1px solid ${COLORS.border}`, borderRadius: '14px 14px 14px 4px', padding: '10px 14px', display: 'flex', gap: 5 }}>
                    {[0, 1, 2].map(i => (
                      <div key={i} style={{ width: 6, height: 6, borderRadius: '50%', background: COLORS.textSecondary, animation: `spin 1.2s ease-in-out infinite`, animationDelay: `${i * 0.15}s`, opacity: 0.5 }} />
                    ))}
                  </div>
                </div>
              )}
              <div ref={msgEnd} />
            </div>

            {/* Quick questions */}
            {messages.length <= 1 && (
              <div style={{
                padding: '0 14px 10px',
                display: 'flex',
                gap: 6,
                overflowX: mobileSheet ? 'auto' : 'visible',
                flexWrap: mobileSheet ? 'nowrap' : 'wrap',
                WebkitOverflowScrolling: 'touch',
              }}>
                {QUICK_QUESTIONS.map(q => (
                  <button
                    key={q}
                    onClick={() => sendMessage(q)}
                    style={{
                      padding: '6px 12px', borderRadius: 99,
                      background: COLORS.primary + '10', color: COLORS.primary,
                      border: `1px solid ${COLORS.primary}25`,
                      fontSize: 11, fontWeight: 600, cursor: 'pointer',
                      fontFamily: "'Outfit', sans-serif",
                      transition: 'all 0.15s',
                      flexShrink: 0,
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {q.length > 32 ? q.slice(0, 32) + '…' : q}
                  </button>
                ))}
              </div>
            )}

            {/* Input */}
            <div style={{
              padding: mobileSheet ? '10px 12px 16px' : '12px 14px',
              borderTop: `1px solid ${COLORS.border}`,
              display: 'flex', gap: 8, flexShrink: 0,
            }}>
              <input
                ref={inputRef}
                value={input}
                onChange={e => setInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && !loading && sendMessage()}
                placeholder="Posez votre question médicale…"
                style={{
                  flex: 1, border: `1.5px solid ${COLORS.border}`, borderRadius: 10,
                  padding: '10px 14px', fontSize: 13, fontFamily: "'Outfit', sans-serif",
                  outline: 'none', color: COLORS.textPrimary, background: COLORS.background,
                }}
              />
              <button
                onClick={() => sendMessage()}
                disabled={loading || !input.trim()}
                style={{
                  width: 42, height: 42, borderRadius: 10, flexShrink: 0,
                  background: input.trim() ? COLORS.primary : COLORS.border,
                  border: 'none', cursor: input.trim() ? 'pointer' : 'not-allowed',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  transition: 'all 0.15s',
                }}
              >
                {loading ? <Spinner size={16} color="white" /> : <Icon name="send" size={16} color="white" />}
              </button>
            </div>
          </>
        )}
      </div>
    </>
  );
};

export default OrlAssistant;