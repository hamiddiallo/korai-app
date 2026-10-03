import React from 'react';
import { COLORS } from '../shared';
import Icon from './Icon';
import { KoraiLogo } from './UI';
import type { User } from '../shared';

const SIDEBAR_FULL = 260;
const SIDEBAR_COLLAPSED = 64;
const MOBILE_BP = 768;

interface LayoutProps {
  user: User;
  route: string;
  onNavigate: (route: string) => void;
  onLogout: () => void;
  children: React.ReactNode;
}

const NAV_ITEMS = [
  { key: 'dashboard',        icon: 'dashboard',   label: 'Tableau de bord' },
  { key: 'new-consultation', icon: 'stethoscope', label: 'Nouvelle consultation' },
  { key: 'reports',          icon: 'filetext',    label: 'Consultations' },
  { key: 'profile',          icon: 'user',        label: 'Mon profil' },
  { key: 'dataset',          icon: 'upload',      label: 'Collecte dataset' },
];

const Layout: React.FC<LayoutProps> = ({ user, route, onNavigate, onLogout, children }) => {
  const [collapsed, setCollapsed] = React.useState(false);
  const [mobileOpen, setMobileOpen] = React.useState(false);
  const [isMobile, setIsMobile] = React.useState(window.innerWidth < MOBILE_BP);

  React.useEffect(() => {
    const onResize = () => {
      const m = window.innerWidth < MOBILE_BP;
      setIsMobile(m);
      if (!m) setMobileOpen(false);
    };
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  // Auto-close sidebar on navigation on mobile
  React.useEffect(() => {
    if (isMobile) setMobileOpen(false);
  }, [route]);

  const sidebarW = isMobile ? SIDEBAR_FULL : (collapsed ? SIDEBAR_COLLAPSED : SIDEBAR_FULL);
  const mainML = isMobile ? 0 : (collapsed ? SIDEBAR_COLLAPSED : SIDEBAR_FULL);
  const sidebarVisible = !isMobile || mobileOpen;
  const initials = user?.initials || (user?.username || 'U').slice(0, 2).toUpperCase();

  const iconOnly = collapsed && !isMobile;

  return (
    <div style={{ display: 'flex', minHeight: '100vh', fontFamily: "'Outfit', sans-serif", background: COLORS.background }}>

      {/* Mobile backdrop */}
      {isMobile && mobileOpen && (
        <div
          onClick={() => setMobileOpen(false)}
          style={{
            position: 'fixed', inset: 0, zIndex: 99,
            background: 'rgba(0,0,0,0.52)',
            backdropFilter: 'blur(2px)',
          }}
        />
      )}

      {/* ── Sidebar ───────────────────────────────────────────────────── */}
      <aside style={{
        width: sidebarW,
        background: `linear-gradient(180deg, ${COLORS.sidebar} 0%, ${COLORS.sidebarEnd} 100%)`,
        display: 'flex', flexDirection: 'column',
        position: 'fixed', top: 0, left: 0, bottom: 0, zIndex: 100,
        boxShadow: '4px 0 32px rgba(0,0,0,0.22)',
        transform: sidebarVisible ? 'translateX(0)' : 'translateX(-100%)',
        transition: 'transform 0.28s cubic-bezier(0.4,0,0.2,1), width 0.22s ease',
        overflow: 'hidden',
      }}>

        {/* Logo row */}
        {iconOnly ? (
          <div style={{
            padding: '16px 0 12px',
            borderBottom: '1px solid rgba(255,255,255,0.07)',
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            gap: 10, minHeight: 68, flexShrink: 0,
          }}>
            <KoraiLogo size={32} />
            {!isMobile && (
              <button
                onClick={() => setCollapsed(v => !v)}
                title="Déployer la barre"
                style={{
                  background: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.12)',
                  borderRadius: 8, width: 32, height: 22, flexShrink: 0,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  cursor: 'pointer', transition: 'all 0.15s',
                }}
                onMouseEnter={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'rgba(255,255,255,0.16)';
                  (e.currentTarget as HTMLButtonElement).style.borderColor = 'rgba(255,255,255,0.25)';
                }}
                onMouseLeave={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'rgba(255,255,255,0.07)';
                  (e.currentTarget as HTMLButtonElement).style.borderColor = 'rgba(255,255,255,0.12)';
                }}
              >
                <Icon name="chevronright" size={13} color="rgba(255,255,255,0.7)" />
              </button>
            )}
          </div>
        ) : (
          <div style={{
            padding: '18px 14px 14px',
            borderBottom: '1px solid rgba(255,255,255,0.07)',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            gap: 8, minHeight: 68, flexShrink: 0,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, overflow: 'hidden' }}>
              <KoraiLogo size={34} />
              <div>
                <div style={{ fontSize: 18, fontWeight: 800, color: 'white', letterSpacing: '-0.4px', lineHeight: 1.1 }}>KORAI</div>
                <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.38)', letterSpacing: '0.12em', textTransform: 'uppercase', marginTop: 1 }}>ORL · IA</div>
              </div>
            </div>

            {!isMobile && (
              <button
                onClick={() => setCollapsed(v => !v)}
                title="Réduire"
                style={{
                  background: 'rgba(255,255,255,0.08)', border: 'none', borderRadius: 8,
                  width: 28, height: 28, flexShrink: 0,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  cursor: 'pointer', transition: 'background 0.15s',
                }}
                onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.16)')}
                onMouseLeave={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.08)')}
              >
                <Icon name="chevronleft" size={14} color="rgba(255,255,255,0.75)" />
              </button>
            )}

            {isMobile && (
              <button
                onClick={() => setMobileOpen(false)}
                style={{
                  background: 'rgba(255,255,255,0.08)', border: 'none', borderRadius: 8,
                  width: 32, height: 32, flexShrink: 0,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  cursor: 'pointer',
                }}
              >
                <Icon name="x" size={16} color="rgba(255,255,255,0.75)" />
              </button>
            )}
          </div>
        )}

        {/* User info */}
        {iconOnly ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '12px 0 6px', flexShrink: 0 }}>
            <div style={{ position: 'relative' }} title={`${user?.username} · ${user?.role}`}>
              <div style={{
                width: 38, height: 38, borderRadius: '50%',
                background: 'linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 13, fontWeight: 700, color: 'white',
                border: '2px solid rgba(255,255,255,0.22)',
                boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
              }}>
                {initials}
              </div>
              <span style={{
                position: 'absolute', bottom: 1, right: 1,
                width: 9, height: 9, borderRadius: '50%',
                background: '#10B981', border: '2px solid #0F172A',
              }} />
            </div>
          </div>
        ) : (
          <div style={{
            padding: '12px 14px', margin: '8px 10px 0', flexShrink: 0,
            background: 'rgba(255,255,255,0.05)', borderRadius: 12,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{
                width: 36, height: 36, borderRadius: '50%',
                background: 'linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 13, fontWeight: 700, color: 'white', flexShrink: 0,
                border: '2px solid rgba(255,255,255,0.18)',
              }}>
                {initials}
              </div>
              <div style={{ overflow: 'hidden' }}>
                <div style={{ fontSize: 15, fontWeight: 700, color: 'white', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {user?.username || 'Utilisateur'}
                </div>
                <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.42)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: 1 }}>
                  {user?.role || 'Expert ORL'}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Navigation */}
        <nav style={{ flex: 1, padding: iconOnly ? '14px 6px' : '14px 10px', overflowY: 'auto' }}>
          {!iconOnly && (
            <div style={{ fontSize: 11, fontWeight: 700, color: 'rgba(255,255,255,0.28)', letterSpacing: '0.14em', textTransform: 'uppercase', padding: '6px 10px 8px' }}>
              Navigation
            </div>
          )}
          {NAV_ITEMS.map(item => (
            <NavItem
              key={item.key}
              icon={item.icon}
              label={item.label}
              active={route === item.key}
              dot={item.key === 'new-consultation'}
              iconOnly={iconOnly}
              onClick={() => onNavigate(item.key)}
            />
          ))}
        </nav>

        {/* Logout */}
        <div style={{ padding: iconOnly ? '10px 6px' : '10px', borderTop: '1px solid rgba(255,255,255,0.07)', flexShrink: 0 }}>
          <button
            onClick={onLogout}
            title="Déconnexion"
            style={{
              width: '100%', display: 'flex', alignItems: 'center',
              justifyContent: iconOnly ? 'center' : 'flex-start',
              gap: iconOnly ? 0 : 12,
              padding: iconOnly ? '11px 0' : '11px 14px',
              borderRadius: 10, border: 'none',
              background: 'transparent', color: 'rgba(255,255,255,0.42)',
              fontSize: 15, fontWeight: 500, fontFamily: "'Outfit', sans-serif",
              cursor: 'pointer', transition: 'all 0.15s ease',
            }}
            onMouseEnter={e => {
              (e.currentTarget as HTMLButtonElement).style.background = 'rgba(239,68,68,0.12)';
              (e.currentTarget as HTMLButtonElement).style.color = '#FCA5A5';
            }}
            onMouseLeave={e => {
              (e.currentTarget as HTMLButtonElement).style.background = 'transparent';
              (e.currentTarget as HTMLButtonElement).style.color = 'rgba(255,255,255,0.42)';
            }}
          >
            <Icon name="logout" size={18} color="currentColor" />
            {!iconOnly && <span>Déconnexion</span>}
          </button>
        </div>
      </aside>

      {/* ── Main content ──────────────────────────────────────────────── */}
      <main style={{
        marginLeft: mainML,
        flex: 1, minHeight: '100vh',
        overflow: 'auto', position: 'relative',
        transition: 'margin-left 0.22s ease',
      }}>
        {/* Mobile top bar */}
        {isMobile && (
          <div style={{
            position: 'sticky', top: 0, zIndex: 50,
            background: `linear-gradient(90deg, ${COLORS.sidebar} 0%, ${COLORS.sidebarEnd} 100%)`,
            padding: '10px 16px',
            display: 'flex', alignItems: 'center', gap: 12,
            boxShadow: '0 2px 14px rgba(0,0,0,0.22)',
          }}>
            <button
              onClick={() => setMobileOpen(true)}
              style={{
                background: 'rgba(255,255,255,0.1)', border: 'none', borderRadius: 9,
                width: 38, height: 38, flexShrink: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer',
              }}
            >
              <Icon name="menu" size={20} color="white" />
            </button>
            <KoraiLogo size={26} />
            <span style={{ color: 'white', fontWeight: 800, fontSize: 16, letterSpacing: '-0.3px' }}>KORAI</span>
            <span style={{ color: 'rgba(255,255,255,0.38)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', alignSelf: 'flex-end', paddingBottom: 1 }}>
              ORL · IA
            </span>
          </div>
        )}
        {children}
      </main>
    </div>
  );
};

const NavItem: React.FC<{
  icon: string; label: string; active: boolean; dot?: boolean; iconOnly?: boolean; onClick: () => void;
}> = ({ icon, label, active, dot, iconOnly, onClick }) => {
  const [hovered, setHovered] = React.useState(false);

  if (iconOnly) {
    return (
      <button
        onClick={onClick}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        title={label}
        style={{
          width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: '6px 0', border: 'none', background: 'transparent',
          cursor: 'pointer', marginBottom: 4,
          fontFamily: "'Outfit', sans-serif", position: 'relative',
        }}
      >
        {/* Indicateur actif — barre gauche */}
        <span style={{
          position: 'absolute', left: 0, top: '50%', transform: 'translateY(-50%)',
          width: 3, height: active ? 26 : 0,
          background: '#60A5FA', borderRadius: '0 3px 3px 0',
          transition: 'height 0.2s ease',
        }} />
        {/* Conteneur icône */}
        <div style={{
          width: 42, height: 42, borderRadius: 12,
          background: active
            ? 'rgba(96,165,250,0.22)'
            : hovered ? 'rgba(255,255,255,0.09)' : 'transparent',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          transition: 'background 0.15s ease',
          boxShadow: active ? 'inset 0 0 0 1px rgba(96,165,250,0.3)' : 'none',
        }}>
          <Icon
            name={icon}
            size={20}
            color={active ? '#93C5FD' : hovered ? 'rgba(255,255,255,0.75)' : 'rgba(255,255,255,0.48)'}
          />
        </div>
        {/* Point vert (nouvelle consultation) */}
        {dot && (
          <span style={{
            position: 'absolute', top: 8, right: 8,
            width: 7, height: 7, borderRadius: '50%', background: '#10B981',
            boxShadow: '0 0 0 2px #0F172A',
          }} />
        )}
      </button>
    );
  }

  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        width: '100%', display: 'flex', alignItems: 'center',
        gap: 12, padding: '11px 14px',
        borderRadius: 12, border: 'none',
        background: active ? 'rgba(255,255,255,0.13)' : hovered ? 'rgba(255,255,255,0.07)' : 'transparent',
        color: active ? 'white' : 'rgba(255,255,255,0.52)',
        fontSize: 15, fontWeight: active ? 600 : 400,
        fontFamily: "'Outfit', sans-serif",
        cursor: 'pointer', marginBottom: 3,
        textAlign: 'left', transition: 'all 0.15s ease',
        borderLeft: `3px solid ${active ? '#60A5FA' : 'transparent'}`,
        position: 'relative',
      }}
    >
      <Icon name={icon} size={18} color={active ? '#93C5FD' : 'rgba(255,255,255,0.42)'} />
      <span style={{ flex: 1 }}>{label}</span>
      {dot && (
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#10B981', flexShrink: 0 }} />
      )}
    </button>
  );
};

export default Layout;
