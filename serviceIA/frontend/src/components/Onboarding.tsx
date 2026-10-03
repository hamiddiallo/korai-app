import React from 'react';
import { Button } from './UI';

interface OnboardingProps {
  onSkip: () => void;
}

const SLIDES = [
  {
    step: 1,
    title: 'Analyse otoscopique instantanée',
    desc: 'Le modèle de vision classifie les pathologies ORL avec un score de confiance et un top-3 des diagnostics probables.',
    visual: 'ear-analysis',
  },
  {
    step: 2,
    title: 'Base de connaissances ORL',
    desc: 'L\'assistant RAG génère un résumé structuré à partir des symptômes saisis, ancré dans la littérature médicale ORL.',
    visual: 'rag-docs',
  },
  {
    step: 3,
    title: 'Validation en un clic',
    desc: 'Consultez vision IA et RAG côté à côté, validez ou corrigez les diagnostics, et contribuez à l\'amélioration du modèle.',
    visual: 'validation',
  },
];

const Onboarding: React.FC<OnboardingProps> = ({ onSkip }) => {
  const [current, setCurrent] = React.useState(0);

  const slide = SLIDES[current];
  const progress = ((current + 1) / SLIDES.length) * 100;

  const goNext = () => {
    if (current < SLIDES.length - 1) setCurrent(current + 1);
    else onSkip();
  };

  const goPrev = () => {
    if (current > 0) setCurrent(current - 1);
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: `linear-gradient(135deg, #0F172A 0%, #1E3A8A 60%, #0F172A 100%)`,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'Outfit', sans-serif", position: 'relative', overflow: 'hidden',
      padding: '32px 20px',
    }}>
      {/* Background decoration */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <div style={{ position: 'absolute', top: '-15%', right: '-5%', width: 600, height: 600, borderRadius: '50%', background: 'radial-gradient(circle, rgba(29,106,229,0.12) 0%, transparent 65%)' }} />
        <div style={{ position: 'absolute', bottom: '-20%', left: '-5%', width: 400, height: 400, borderRadius: '50%', background: 'radial-gradient(circle, rgba(16,185,129,0.09) 0%, transparent 65%)' }} />
      </div>

      <div style={{ width: '100%', maxWidth: 800, position: 'relative' }}>
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: 52 }}>
          <div style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <div style={{
              width: 64, height: 64, borderRadius: 18,
              background: 'rgba(255,255,255,0.1)',
              border: '1.5px solid rgba(255,255,255,0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 12px 48px rgba(0,0,0,0.25)',
            }}>
              <svg width="36" height="36" viewBox="0 0 40 40" fill="none">
                <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white" opacity="0.95"/>
                <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.9)" strokeWidth="1.8" strokeLinecap="round" fill="none"/>
                <circle cx="20" cy="15" r="2.5" fill="rgba(29,106,229,0.9)"/>
                <circle cx="20" cy="15" r="4.5" fill="none" stroke="rgba(147,197,253,0.5)" strokeWidth="1.2"/>
              </svg>
            </div>
            <div>
              <div style={{ fontSize: 40, fontWeight: 800, color: 'white', letterSpacing: '-1.2px' }}>KORAI</div>
              <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginTop: 6, letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 600 }}>
                Aide au diagnostic ORL · Sénégal
              </div>
            </div>
          </div>
        </div>

        {/* Progress */}
        <div style={{
          width: '100%', height: 3, background: 'rgba(255,255,255,0.1)',
          borderRadius: 99, overflow: 'hidden', marginBottom: 48,
        }}>
          <div style={{
            height: '100%', width: `${progress}%`, background: 'linear-gradient(90deg, #60A5FA, #3B82F6)',
            transition: 'width 0.4s ease', borderRadius: 99,
          }} />
        </div>

        {/* Content */}
        <div style={{
          background: 'rgba(30,58,138,0.4)',
          backdropFilter: 'blur(16px)',
          borderRadius: 28,
          border: '1px solid rgba(255,255,255,0.1)',
          padding: '48px 48px',
          minHeight: 480,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 16px 64px rgba(0,0,0,0.3)',
        }}>
          {/* Step indicator */}
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            background: 'rgba(96,165,250,0.15)',
            border: '1px solid rgba(96,165,250,0.3)',
            borderRadius: 99,
            padding: '7px 16px',
            marginBottom: 32,
          }}>
            <span style={{ width: 8, height: 8, background: '#60A5FA', borderRadius: '50%' }} />
            <span style={{ fontSize: 13, fontWeight: 700, color: '#93C5FD', letterSpacing: '0.08em' }}>
              {slide.step} / {SLIDES.length}
            </span>
          </div>

          {/* Title */}
          <h2 style={{
            margin: '0 0 20px', fontSize: 42, fontWeight: 800, color: 'white',
            letterSpacing: '-1px', textAlign: 'center', lineHeight: 1.2,
          }}>
            {slide.title}
          </h2>

          {/* Description */}
          <p style={{
            margin: '0 0 40px', fontSize: 16, color: 'rgba(255,255,255,0.7)',
            textAlign: 'center', lineHeight: 1.7, maxWidth: 500,
          }}>
            {slide.desc}
          </p>

          {/* Visual */}
          <div style={{ marginBottom: 48, width: '100%', display: 'flex', justifyContent: 'center' }}>
            <OnboardingVisual type={slide.visual} />
          </div>

          {/* Navigation */}
          <div style={{ display: 'flex', gap: 14, width: '100%', justifyContent: 'center' }}>
            <Button
              variant="ghost"
              onClick={goPrev}
              disabled={current === 0}
              style={{
                opacity: current === 0 ? 0.5 : 1,
                cursor: current === 0 ? 'not-allowed' : 'pointer',
              }}
            >
              Précédent
            </Button>
            <Button variant="primary" icon="arrowright" onClick={goNext}>
              {current === SLIDES.length - 1 ? 'Commencer' : 'Suivant'}
            </Button>
          </div>

          {/* Dots */}
          <div style={{ display: 'flex', gap: 8, marginTop: 32 }}>
            {SLIDES.map((_, i) => (
              <button
                key={i}
                onClick={() => setCurrent(i)}
                style={{
                  width: i === current ? 24 : 10,
                  height: 10, borderRadius: 99,
                  background: i === current ? '#60A5FA' : 'rgba(255,255,255,0.2)',
                  border: 'none', cursor: 'pointer',
                  transition: 'all 0.3s ease',
                }}
              />
            ))}
          </div>
        </div>

        {/* Skip button */}
        <button
          onClick={onSkip}
          style={{
            position: 'absolute', top: 0, right: 0,
            background: 'rgba(255,255,255,0.1)', border: 'none',
            color: 'rgba(255,255,255,0.6)', fontSize: 13, fontWeight: 600,
            padding: '8px 16px', borderRadius: 10, cursor: 'pointer',
            fontFamily: "'Outfit', sans-serif",
            transition: 'all 0.2s',
          }}
          onMouseEnter={e => {
            (e.target as HTMLButtonElement).style.background = 'rgba(255,255,255,0.15)';
            (e.target as HTMLButtonElement).style.color = 'rgba(255,255,255,0.9)';
          }}
          onMouseLeave={e => {
            (e.target as HTMLButtonElement).style.background = 'rgba(255,255,255,0.1)';
            (e.target as HTMLButtonElement).style.color = 'rgba(255,255,255,0.6)';
          }}
        >
          Passer
        </button>
      </div>
    </div>
  );
};

// Visuals for each slide
const OnboardingVisual: React.FC<{ type: string }> = ({ type }) => {
  if (type === 'ear-analysis') {
    return (
      <svg width="280" height="220" viewBox="0 0 280 220" style={{ animation: 'float 3s ease-in-out infinite' }}>
        {/* Ear visualization */}
        <g>
          {/* Outer circle */}
          <circle cx="140" cy="110" r="95" fill="url(#earGradient)" opacity="0.9" />
          <circle cx="140" cy="110" r="95" fill="none" stroke="rgba(96,165,250,0.3)" strokeWidth="2" />

          {/* Inner details */}
          <circle cx="140" cy="110" r="70" fill="none" stroke="rgba(96,165,250,0.2)" strokeWidth="1" />
          <circle cx="140" cy="110" r="50" fill="none" stroke="rgba(96,165,250,0.15)" strokeWidth="1" />

          {/* Pathology indicator */}
          <circle cx="150" cy="100" r="28" fill="#FCA5A5" opacity="0.8" />
          <circle cx="150" cy="100" r="28" fill="none" stroke="#DC2626" strokeWidth="2" />

          {/* Detail pattern */}
          <circle cx="160" cy="85" r="12" fill="rgba(220,38,38,0.3)" />
          <circle cx="140" cy="95" r="8" fill="rgba(220,38,38,0.2)" />

          {/* Confidence badge */}
          <g>
            <rect x="200" y="50" width="60" height="32" rx="8" fill="rgba(30,58,138,0.9)" stroke="rgba(96,165,250,0.5)" strokeWidth="1" />
            <text x="230" y="73" textAnchor="middle" fill="white" fontSize="13" fontWeight="700" fontFamily="'Outfit'">92%</text>
          </g>
        </g>

        <defs>
          <radialGradient id="earGradient">
            <stop offset="0%" stopColor="#FCA5A5" />
            <stop offset="100%" stopColor="#DC2626" />
          </radialGradient>
        </defs>
      </svg>
    );
  }

  if (type === 'rag-docs') {
    return (
      <svg width="280" height="220" viewBox="0 0 280 220" style={{ animation: 'float 3s ease-in-out infinite' }}>
        {/* Document card */}
        <g>
          {/* Background gradient */}
          <defs>
            <linearGradient id="docGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="rgba(16,185,129,0.15)" />
              <stop offset="100%" stopColor="rgba(16,185,129,0.05)" />
            </linearGradient>
          </defs>

          {/* Document card */}
          <rect x="80" y="40" width="160" height="160" rx="12" fill="white" stroke="rgba(16,185,129,0.3)" strokeWidth="2" />

          {/* Header */}
          <rect x="80" y="40" width="160" height="40" rx="12" fill="url(#docGrad)" />
          <circle cx="95" cy="60" r="8" fill="#10B981" />
          <text x="110" y="65" fill="#10B981" fontSize="12" fontWeight="700" fontFamily="'Outfit'">IA</text>
          <text x="145" y="65" fill="#10B981" fontSize="11" fontWeight="700" fontFamily="'Outfit'">Assistant ORL – RAG</text>

          {/* Content lines */}
          <line x1="90" y1="95" x2="220" y2="95" stroke="rgba(16,185,129,0.2)" strokeWidth="1.5" />
          <text x="90" y="110" fill="#1A2332" fontSize="10" fontWeight="600" fontFamily="'Outfit'">Signes d'un cholestéatome ?</text>

          <line x1="90" y1="125" x2="220" y2="125" stroke="rgba(16,185,129,0.2)" strokeWidth="1.5" />
          <text x="90" y="140" fill="#64748B" fontSize="9" fontFamily="'Outfit'">1. Causes probables</text>
          <text x="90" y="153" fill="#64748B" fontSize="9" fontFamily="'Outfit'">2. Signes associés</text>
          <text x="90" y="166" fill="#64748B" fontSize="9" fontFamily="'Outfit'">3. Conduite à tenir</text>

          {/* Checkmark */}
          <circle cx="235" cy="170" r="14" fill="#10B981" />
          <path d="M 230 170 L 233 173 L 238 168" stroke="white" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        </g>
      </svg>
    );
  }

  // validation
  return (
    <svg width="280" height="220" viewBox="0 0 280 220" style={{ animation: 'float 3s ease-in-out infinite' }}>
      {/* Two comparison boxes */}
      <g>
        {/* Vision IA box */}
        <rect x="40" y="50" width="100" height="130" rx="10" fill="rgba(29,106,229,0.1)" stroke="rgba(29,106,229,0.4)" strokeWidth="2" />
        <text x="90" y="72" textAnchor="middle" fill="white" fontSize="11" fontWeight="700" fontFamily="'Outfit'">Vision IA</text>

        {/* Ear circle */}
        <circle cx="90" cy="110" r="25" fill="#FCA5A5" opacity="0.7" />
        <circle cx="95" cy="105" r="8" fill="rgba(220,38,38,0.3)" />
        <circle cx="85" cy="115" r="5" fill="rgba(220,38,38,0.2)" />

        <text x="90" y="152" textAnchor="middle" fill="rgba(255,255,255,0.8)" fontSize="10" fontFamily="'Outfit'">Otite moyenne aiguë</text>

        {/* Check */}
        <circle cx="70" cy="170" r="10" fill="#10B981" />
        <path d="M 66 170 L 68 172 L 72 168" stroke="white" strokeWidth="1.5" fill="none" strokeLinecap="round" />

        {/* RAG box */}
        <rect x="160" y="50" width="100" height="130" rx="10" fill="rgba(16,185,129,0.1)" stroke="rgba(16,185,129,0.4)" strokeWidth="2" />
        <text x="210" y="72" textAnchor="middle" fill="white" fontSize="11" fontWeight="700" fontFamily="'Outfit'">Analyse RAG</text>

        {/* Content placeholder */}
        <line x1="170" y1="90" x2="240" y2="90" stroke="rgba(16,185,129,0.3)" strokeWidth="1" />
        <text x="170" y="105" fill="rgba(255,255,255,0.7)" fontSize="8" fontFamily="'Outfit'">Causes probables</text>
        <text x="170" y="118" fill="rgba(255,255,255,0.7)" fontSize="8" fontFamily="'Outfit'">Infection bactérienne...</text>

        <line x1="170" y1="130" x2="240" y2="130" stroke="rgba(16,185,129,0.3)" strokeWidth="1" />
        <text x="170" y="145" fill="rgba(255,255,255,0.7)" fontSize="8" fontFamily="'Outfit'">Conduite à tenir</text>
        <text x="170" y="158" fill="rgba(255,255,255,0.7)" fontSize="8" fontFamily="'Outfit'">Antibiothérapie...</text>

        {/* Check */}
        <circle cx="235" cy="170" r="10" fill="#10B981" />
        <path d="M 231 170 L 233 172 L 237 168" stroke="white" strokeWidth="1.5" fill="none" strokeLinecap="round" />

        {/* Arrow between boxes */}
        <path d="M 145 110 L 155 110" stroke="rgba(96,165,250,0.4)" strokeWidth="2" fill="none" markerEnd="url(#arrowhead)" />
        <defs>
          <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
            <polygon points="0 0, 10 3, 0 6" fill="rgba(96,165,250,0.4)" />
          </marker>
        </defs>
      </g>
    </svg>
  );
};

export default Onboarding;

