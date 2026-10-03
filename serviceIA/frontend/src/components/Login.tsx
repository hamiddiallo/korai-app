import React from 'react';
import { COLORS, Storage } from '../shared';
import Icon from './Icon';
import type { User } from '../shared';

interface LoginProps {
  onLogin: (user: User) => void;
}

const Login: React.FC<LoginProps> = ({ onLogin }) => {
  const [username, setUsername] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [showPwd, setShowPwd] = React.useState(false);
  const [error, setError] = React.useState('');
  const [loading, setLoading] = React.useState(false);

  const handleLogin = async () => {
    setError('');
    setLoading(true);
    await new Promise(r => setTimeout(r, 700));
    
    // Identifiants par défaut temporaires (hard-coded)
    const DEFAULT_CREDENTIALS = [
      { username: 'Pr Ciré', password: 'module', role: 'Professeur ORL', initials: 'PC' },
      { username: 'Dr Fatou', password: 'demo', role: 'Médecin ORL', initials: 'DF' },
    ];
    
    // Vérifier d'abord la base de données
    const users = Storage.getUsers();
    let user = users.find(u => u.username === username && u.password === password);
    
    // Si pas trouvé, vérifier les identifiants par défaut (fallback temporaire)
    if (!user) {
      user = DEFAULT_CREDENTIALS.find(u => u.username === username && u.password === password);
    }
    
    setLoading(false);
    if (user) {
      onLogin(user);
    } else {
      setError('Identifiants incorrects. Vérifiez votre nom d\'utilisateur et mot de passe.');
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: `linear-gradient(135deg, #0F172A 0%, #1E3A8A 60%, #0F172A 100%)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'Outfit', sans-serif", position: 'relative', overflow: 'hidden',
    }}>
      {/* Background decoration */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <div style={{ position: 'absolute', top: '-15%', right: '-5%', width: 700, height: 700, borderRadius: '50%', background: 'radial-gradient(circle, rgba(29,106,229,0.14) 0%, transparent 65%)' }} />
        <div style={{ position: 'absolute', bottom: '-20%', left: '-5%', width: 500, height: 500, borderRadius: '50%', background: 'radial-gradient(circle, rgba(16,185,129,0.09) 0%, transparent 65%)' }} />
        <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.03 }}>
          <defs>
            <pattern id="lgrid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="white" strokeWidth="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#lgrid)"/>
        </svg>
        {/* Floating blobs */}
        {[
          { top: '15%', left: '8%', size: 120, opacity: 0.06 },
          { top: '60%', right: '10%', size: 80, opacity: 0.05 },
          { bottom: '15%', left: '40%', size: 60, opacity: 0.04 },
        ].map((b, i) => (
          <div key={i} style={{
            position: 'absolute', ...b,
            width: b.size, height: b.size,
            borderRadius: '50%', background: 'white',
            opacity: b.opacity,
          }} />
        ))}
      </div>

      <div style={{ width: '100%', maxWidth: 440, padding: '0 16px', position: 'relative' }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 34 }}>
          <div style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 72, height: 72, borderRadius: 20,
              background: 'rgba(255,255,255,0.1)',
              border: '1.5px solid rgba(255,255,255,0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
            }}>
              <svg width="42" height="42" viewBox="0 0 40 40" fill="none">
                <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white" opacity="0.92"/>
                <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.9)" strokeWidth="1.8" strokeLinecap="round" fill="none"/>
                <circle cx="20" cy="15" r="2.5" fill="rgba(29,106,229,0.9)"/>
                <circle cx="20" cy="15" r="4.5" fill="none" stroke="rgba(147,197,253,0.5)" strokeWidth="1.2"/>
              </svg>
            </div>
            <div>
              <div style={{ fontSize: 34, fontWeight: 800, color: 'white', letterSpacing: '-0.8px', lineHeight: 1 }}>KORAI ORL</div>
              <div style={{ color: 'rgba(255,255,255,0.45)', fontSize: 12, marginTop: 4, letterSpacing: '0.12em', textTransform: 'uppercase' }}>
                Système de diagnostic intelligent
              </div>
            </div>
          </div>
        </div>

        {/* Card */}
        <div style={{
          background: 'rgba(255,255,255,0.98)',
          borderRadius: 24,
          padding: '36px 40px',
          boxShadow: '0 32px 80px rgba(0,0,0,0.4)',
        }}>
          <h2 style={{ margin: '0 0 6px', fontSize: 24, fontWeight: 800, color: COLORS.textPrimary, letterSpacing: '-0.3px' }}>
            Connexion
          </h2>
          <p style={{ margin: '0 0 30px', color: COLORS.textSecondary, fontSize: 14 }}>
            Accédez à votre espace expert ORL
          </p>

          {/* Username */}
          <div style={{ marginBottom: 18 }}>
            <label style={{ display: 'block', marginBottom: 7, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
              Nom d'utilisateur
            </label>
            <div style={{
              display: 'flex', alignItems: 'center',
              border: `1.5px solid ${COLORS.border}`, borderRadius: 12,
              background: '#fff', overflow: 'hidden', transition: 'border-color 0.2s',
            }}>
              <div style={{ padding: '0 14px', flexShrink: 0 }}>
                <Icon name="user" size={17} color={COLORS.textSecondary} />
              </div>
              <input
                value={username}
                onChange={e => setUsername(e.target.value)}
                placeholder="Nom d'utilisateur"
                style={{
                  flex: 1, border: 'none', outline: 'none',
                  padding: '13px 14px 13px 0', fontSize: 14,
                  fontFamily: "'Outfit', sans-serif", color: COLORS.textPrimary,
                }}
                onKeyDown={e => e.key === 'Enter' && handleLogin()}
              />
            </div>
          </div>

          {/* Password */}
          <div style={{ marginBottom: 26 }}>
            <label style={{ display: 'block', marginBottom: 7, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
              Mot de passe
            </label>
            <div style={{
              display: 'flex', alignItems: 'center',
              border: `1.5px solid ${COLORS.border}`, borderRadius: 12,
              background: '#fff', overflow: 'hidden',
            }}>
              <div style={{ padding: '0 14px', flexShrink: 0 }}>
                <Icon name="lock" size={17} color={COLORS.textSecondary} />
              </div>
              <input
                type={showPwd ? 'text' : 'password'}
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="Mot de passe"
                style={{
                  flex: 1, border: 'none', outline: 'none',
                  padding: '13px 0', fontSize: 14,
                  fontFamily: "'Outfit', sans-serif", color: COLORS.textPrimary,
                }}
                onKeyDown={e => e.key === 'Enter' && handleLogin()}
              />
              <button onClick={() => setShowPwd(v => !v)} style={{
                background: 'none', border: 'none', padding: '0 14px',
                cursor: 'pointer', color: COLORS.textSecondary, flexShrink: 0,
              }}>
                <Icon name={showPwd ? 'eyeoff' : 'eye'} size={17} color={COLORS.textSecondary} />
              </button>
            </div>
          </div>

          {error && (
            <div style={{
              background: COLORS.danger + '10', border: `1px solid ${COLORS.danger}25`,
              borderRadius: 10, padding: '11px 15px', marginBottom: 20,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <Icon name="alert" size={16} color={COLORS.danger} />
              <span style={{ fontSize: 13, color: COLORS.danger, fontWeight: 500 }}>{error}</span>
            </div>
          )}

          <button
            onClick={handleLogin}
            disabled={loading}
            style={{
              width: '100%', padding: '14px', borderRadius: 12,
              background: loading ? COLORS.secondary : COLORS.primary,
              color: 'white', border: 'none', fontFamily: "'Outfit', sans-serif",
              fontSize: 15, fontWeight: 700, cursor: loading ? 'default' : 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
              transition: 'all 0.2s', boxShadow: loading ? 'none' : `0 4px 14px ${COLORS.primary}40`,
            }}
          >
            {loading ? (
              <>
                <svg width="18" height="18" viewBox="0 0 24 24" style={{ animation: 'spin 0.8s linear infinite' }}>
                  <circle cx="12" cy="12" r="10" fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth="3"/>
                  <path fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" d="M12 2a10 10 0 0 1 10 10"/>
                </svg>
                Connexion en cours…
              </>
            ) : (
              <>Se connecter <Icon name="arrowright" size={17} color="white" /></>
            )}
          </button>
        </div>

        <p style={{ textAlign: 'center', color: 'rgba(255,255,255,0.3)', fontSize: 12, marginTop: 22 }}>
          KORAI ORL · Données protégées
        </p>
      </div>
    </div>
  );
};

export default Login;

