import React from 'react';
import { COLORS } from '../shared';
import Icon from './Icon';

// ── Card ─────────────────────────────────────────────────────────────────────
interface CardProps {
  children: React.ReactNode;
  padding?: number;
  style?: React.CSSProperties;
  onClick?: () => void;
}
export const Card: React.FC<CardProps> = ({ children, padding = 24, style, onClick }) => (
  <div
    onClick={onClick}
    style={{
      background: COLORS.cardBg,
      borderRadius: 16,
      border: `1px solid ${COLORS.border}`,
      padding,
      boxShadow: '0 1px 3px rgba(0,0,0,0.04), 0 4px 12px rgba(0,0,0,0.03)',
      ...style,
    }}
  >
    {children}
  </div>
);

// ── Button ────────────────────────────────────────────────────────────────────
interface ButtonProps {
  children: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  icon?: string;
  iconRight?: string;
  onClick?: () => void;
  disabled?: boolean;
  fullWidth?: boolean;
  style?: React.CSSProperties;
  type?: 'button' | 'submit';
}
export const Button: React.FC<ButtonProps> = ({
  children, variant = 'primary', size = 'md', icon, iconRight,
  onClick, disabled, fullWidth, style, type = 'button'
}) => {
  const colors: Record<string, { bg: string; color: string; border: string; hover: string }> = {
    primary: { bg: COLORS.primary, color: 'white', border: COLORS.primary, hover: '#1558CC' },
    secondary: { bg: COLORS.secondary, color: 'white', border: COLORS.secondary, hover: '#0284C7' },
    ghost: { bg: 'transparent', color: COLORS.textSecondary, border: COLORS.border, hover: COLORS.background },
    danger: { bg: COLORS.danger, color: 'white', border: COLORS.danger, hover: '#DC2626' },
  };
  const sizes: Record<string, { padding: string; fontSize: number; height: number }> = {
    sm: { padding: '6px 14px', fontSize: 13, height: 32 },
    md: { padding: '10px 20px', fontSize: 14, height: 40 },
    lg: { padding: '13px 28px', fontSize: 15, height: 48 },
  };
  const c = colors[variant];
  const s = sizes[size];
  const [hovered, setHovered] = React.useState(false);

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        padding: s.padding, fontSize: s.fontSize, fontWeight: 600,
        fontFamily: "'Outfit', sans-serif",
        background: disabled ? COLORS.border : hovered ? c.hover : c.bg,
        color: disabled ? COLORS.textSecondary : c.color,
        border: `1.5px solid ${disabled ? COLORS.border : c.border}`,
        borderRadius: 10, cursor: disabled ? 'not-allowed' : 'pointer',
        transition: 'all 0.18s ease', width: fullWidth ? '100%' : undefined,
        whiteSpace: 'nowrap', ...style,
      }}
    >
      {icon && <Icon name={icon} size={s.fontSize + 2} color={disabled ? COLORS.textSecondary : c.color} />}
      {children}
      {iconRight && <Icon name={iconRight} size={s.fontSize + 2} color={disabled ? COLORS.textSecondary : c.color} />}
    </button>
  );
};

// ── Badge / StatusBadge ───────────────────────────────────────────────────────
interface BadgeProps { children: React.ReactNode; color?: string; bg?: string; }
export const Badge: React.FC<BadgeProps> = ({ children, color = COLORS.primary, bg }) => (
  <span style={{
    display: 'inline-flex', alignItems: 'center', gap: 4,
    padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600,
    background: bg || color + '15', color,
    fontFamily: "'Outfit', sans-serif",
  }}>
    {children}
  </span>
);

export const StatusBadge: React.FC<{ status: string }> = ({ status }) => {
  const map: Record<string, { color: string; icon: string }> = {
    'Validée': { color: COLORS.success, icon: 'checkcircle' },
    'Corrigée': { color: COLORS.warning, icon: 'alert' },
  };
  const cfg = map[status] || { color: COLORS.textSecondary, icon: 'info' };
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '4px 12px', borderRadius: 99, fontSize: 12, fontWeight: 600,
      background: cfg.color + '12', color: cfg.color,
      fontFamily: "'Outfit', sans-serif",
    }}>
      <Icon name={cfg.icon} size={12} color={cfg.color} />
      {status}
    </span>
  );
};

// ── Modal ─────────────────────────────────────────────────────────────────────
interface ModalProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  width?: number;
  children: React.ReactNode;
}
export const Modal: React.FC<ModalProps> = ({ open, onClose, title, width = 520, children }) => {
  if (!open) return null;
  return (
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: 16, animation: 'fadeIn 0.2s ease-out',
      }}
      onClick={e => e.target === e.currentTarget && onClose()}
    >
      <div style={{
        background: COLORS.cardBg, borderRadius: 20, width: '100%', maxWidth: width,
        maxHeight: '90vh', display: 'flex', flexDirection: 'column',
        boxShadow: '0 24px 80px rgba(0,0,0,0.3)',
        animation: 'fadeIn 0.25s ease-out',
      }}>
        {title && (
          <div style={{
            padding: '22px 28px', borderBottom: `1px solid ${COLORS.border}`,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            flexShrink: 0,
          }}>
            <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: COLORS.textPrimary, fontFamily: "'Outfit', sans-serif" }}>
              {title}
            </h3>
            <button onClick={onClose} style={{
              width: 32, height: 32, borderRadius: 8, border: 'none',
              background: COLORS.background, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="x" size={16} color={COLORS.textSecondary} />
            </button>
          </div>
        )}
        <div style={{ padding: '24px 28px', overflowY: 'auto', flex: 1 }}>{children}</div>
      </div>
    </div>
  );
};

// ── Spinner ───────────────────────────────────────────────────────────────────
export const Spinner: React.FC<{ size?: number; color?: string }> = ({ size = 24, color = COLORS.primary }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ animation: 'spin 0.8s linear infinite', flexShrink: 0 }}>
    <circle cx="12" cy="12" r="10" fill="none" stroke={color + '30'} strokeWidth="3"/>
    <path fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" d="M12 2a10 10 0 0 1 10 10"/>
  </svg>
);

// ── ConfidenceBar ─────────────────────────────────────────────────────────────
export const ConfidenceBar: React.FC<{ value: number; color?: string; label?: string }> = ({
  value, color = COLORS.primary, label
}) => (
  <div>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
      <span style={{ fontSize: 12, color: COLORS.textSecondary, fontWeight: 500 }}>
        {label || 'Confiance'}
      </span>
      <span style={{ fontSize: 13, fontWeight: 700, color }}>
        {Number(value).toFixed(1)}%
      </span>
    </div>
    <div style={{ height: 8, background: COLORS.border, borderRadius: 99, overflow: 'hidden' }}>
      <div style={{
        height: '100%', width: `${Math.min(value, 100)}%`,
        background: `linear-gradient(90deg, ${color}80, ${color})`,
        borderRadius: 99, transition: 'width 0.8s ease',
      }} />
    </div>
  </div>
);

// ── PageHeader ────────────────────────────────────────────────────────────────
interface PageHeaderProps {
  title: string;
  subtitle?: string;
  actions?: React.ReactNode;
}
export const PageHeader: React.FC<PageHeaderProps> = ({ title, subtitle, actions }) => (
  <div style={{
    padding: '24px 32px 20px',
    borderBottom: `1px solid ${COLORS.border}`,
    background: COLORS.cardBg,
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    position: 'sticky', top: 0, zIndex: 50,
    boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
  }}>
    <div>
      <h1 style={{
        margin: 0, fontSize: 22, fontWeight: 800, color: COLORS.textPrimary,
        letterSpacing: '-0.3px', fontFamily: "'Outfit', sans-serif",
      }}>
        {title}
      </h1>
      {subtitle && (
        <p style={{ margin: '4px 0 0', fontSize: 14, color: COLORS.textSecondary }}>
          {subtitle}
        </p>
      )}
    </div>
    {actions && <div style={{ display: 'flex', gap: 10 }}>{actions}</div>}
  </div>
);

// ── Input ─────────────────────────────────────────────────────────────────────
interface InputProps {
  label?: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  type?: string;
  required?: boolean;
  icon?: string;
  fullWidth?: boolean;
}
export const Input: React.FC<InputProps> = ({ label, value, onChange, placeholder, type = 'text', required, icon, fullWidth }) => (
  <div style={{ width: fullWidth ? '100%' : undefined }}>
    {label && (
      <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
        {label}{required && <span style={{ color: COLORS.danger }}> *</span>}
      </label>
    )}
    <div style={{
      display: 'flex', alignItems: 'center',
      border: `1.5px solid ${COLORS.border}`, borderRadius: 10,
      background: '#fff', overflow: 'hidden',
      width: fullWidth ? '100%' : undefined,
    }}>
      {icon && (
        <div style={{ padding: '0 12px', flexShrink: 0 }}>
          <Icon name={icon} size={16} color={COLORS.textSecondary} />
        </div>
      )}
      <input
        type={type}
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        style={{
          flex: 1, border: 'none', outline: 'none',
          padding: icon ? '11px 14px 11px 0' : '11px 14px',
          fontSize: 14, fontFamily: "'Outfit', sans-serif",
          color: COLORS.textPrimary, background: 'transparent',
        }}
      />
    </div>
  </div>
);

// ── KoraiEarLogo ─────────────────────────────────────────────────────────────
export const KoraiLogo: React.FC<{ size?: number }> = ({ size = 36 }) => (
  <svg width={size} height={size} viewBox="0 0 40 40" fill="none">
    <rect width="40" height="40" rx="10" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.2)" strokeWidth="1"/>
    {/* Outer pinna */}
    <path d="M20 7C15.6 7 12 10.6 12 15C12 18.4 14 21.4 17 22.8V27C17 27.8 17.7 28.5 18.5 28.5H21.5C22.3 28.5 23 27.8 23 27V22.8C26 21.4 28 18.4 28 15C28 10.6 24.4 7 20 7Z" fill="white" opacity="0.9"/>
    {/* Inner helix */}
    <path d="M20 11C17.8 11 16 12.8 16 15C16 16.8 17.1 18.3 18.5 18.9" stroke="rgba(147,197,253,0.9)" strokeWidth="1.8" strokeLinecap="round" fill="none"/>
    {/* Canal / detection point */}
    <circle cx="20" cy="15" r="2.5" fill="rgba(29,106,229,0.95)"/>
    {/* Scan ring */}
    <circle cx="20" cy="15" r="4.5" fill="none" stroke="rgba(147,197,253,0.5)" strokeWidth="1.2"/>
  </svg>
);

