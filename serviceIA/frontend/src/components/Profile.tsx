import React from 'react';
import { COLORS, Storage } from '../shared';
import { Card, Button, PageHeader, Modal } from './UI';
import Icon from './Icon';
import type { User } from '../shared';

interface ProfileProps {
  user: User;
  onUpdate: (user: User) => void;
  consultations: { status: string }[];
}

const Profile: React.FC<ProfileProps> = ({ user, onUpdate, consultations }) => {
  const [tab, setTab] = React.useState<'profile' | 'accounts'>('profile');

  // Profile editing
  const [editing, setEditing] = React.useState(false);
  const [username, setUsername] = React.useState(user.username);
  const [role, setRole] = React.useState(user.role);
  const [currentPwd, setCurrentPwd] = React.useState('');
  const [newPwd, setNewPwd] = React.useState('');
  const [newPwd2, setNewPwd2] = React.useState('');
  const [msg, setMsg] = React.useState('');

  // Account management
  const [users, setUsers] = React.useState<User[]>(Storage.getUsers());
  const [showCreate, setShowCreate] = React.useState(false);
  const [newName, setNewName] = React.useState('');
  const [newRole, setNewRole] = React.useState('Médecin ORL');
  const [createPwd, setCreatePwd] = React.useState('');
  const [createPwd2, setCreatePwd2] = React.useState('');
  const [createMsg, setCreateMsg] = React.useState('');
  const [deleteConfirm, setDeleteConfirm] = React.useState<string | null>(null);

  const stats = [
    { label: 'Consultations validées', value: consultations.filter(c => c.status === 'Validée').length, color: COLORS.success },
    { label: 'Consultations corrigées', value: consultations.filter(c => c.status === 'Corrigée').length, color: COLORS.warning },
    { label: 'Total', value: consultations.length, color: COLORS.secondary },
  ];

  const handleSaveProfile = () => {
    setMsg('');
    const allUsers = Storage.getUsers();
    const idx = allUsers.findIndex(u => u.username === user.username);
    if (idx === -1) return setMsg('Utilisateur introuvable.');
    if (currentPwd && allUsers[idx].password !== currentPwd) return setMsg('Mot de passe actuel incorrect.');
    if (newPwd && newPwd !== newPwd2) return setMsg('Les nouveaux mots de passe ne correspondent pas.');
    const initials = username.split(' ').map((w: string) => w[0]).join('').toUpperCase().slice(0, 2);
    allUsers[idx] = { ...allUsers[idx], username, role, initials, ...(newPwd ? { password: newPwd } : {}) };
    Storage.saveUsers(allUsers);
    onUpdate(allUsers[idx]);
    setMsg('✓ Profil mis à jour avec succès.');
    setEditing(false);
    setCurrentPwd(''); setNewPwd(''); setNewPwd2('');
  };

  const handleCreate = () => {
    setCreateMsg('');
    if (!newName || !createPwd) return setCreateMsg('Nom et mot de passe obligatoires.');
    if (createPwd !== createPwd2) return setCreateMsg('Les mots de passe ne correspondent pas.');
    const allUsers = Storage.getUsers();
    if (allUsers.find(u => u.username === newName)) return setCreateMsg('Ce nom d\'utilisateur existe déjà.');
    const initials = newName.split(' ').map((w: string) => w[0]).join('').toUpperCase().slice(0, 2);
    const updated = [...allUsers, { username: newName, password: createPwd, role: newRole, initials }];
    Storage.saveUsers(updated);
    setUsers(updated);
    setCreateMsg('✓ Compte créé avec succès.');
    setNewName(''); setCreatePwd(''); setCreatePwd2('');
    setTimeout(() => { setShowCreate(false); setCreateMsg(''); }, 1500);
  };

  const handleDelete = (uname: string) => {
    if (uname === user.username) return;
    const updated = Storage.getUsers().filter(u => u.username !== uname);
    Storage.saveUsers(updated);
    setUsers(updated);
    setDeleteConfirm(null);
  };

  const inputStyle = {
    width: '100%', padding: '11px 14px',
    border: `1.5px solid ${COLORS.border}`, borderRadius: 10,
    fontSize: 14, fontFamily: "'Outfit', sans-serif",
    outline: 'none', boxSizing: 'border-box' as const, marginBottom: 16,
  };

  return (
    <div style={{ fontFamily: "'Outfit', sans-serif" }}>
      <PageHeader
        title="Mon espace"
        subtitle="Gérez votre profil et les comptes utilisateurs"
      />

      <div style={{ padding: '28px 32px' }}>
        {/* Tab bar */}
        <div style={{ display: 'flex', gap: 4, marginBottom: 28, background: COLORS.background, borderRadius: 12, padding: 5, width: 'fit-content', border: `1px solid ${COLORS.border}` }}>
          {[
            { key: 'profile', label: 'Mon profil', icon: 'user' },
            { key: 'accounts', label: 'Gestion des comptes', icon: 'users' },
          ].map(t => (
            <button key={t.key} onClick={() => setTab(t.key as 'profile' | 'accounts')} style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '9px 20px', borderRadius: 9, border: 'none', cursor: 'pointer',
              background: tab === t.key ? COLORS.cardBg : 'transparent',
              color: tab === t.key ? COLORS.primary : COLORS.textSecondary,
              fontFamily: "'Outfit', sans-serif", fontSize: 14, fontWeight: tab === t.key ? 700 : 500,
              boxShadow: tab === t.key ? '0 1px 4px rgba(0,0,0,0.07)' : 'none',
              transition: 'all 0.15s',
            }}>
              <Icon name={t.icon} size={16} color={tab === t.key ? COLORS.primary : COLORS.textSecondary} />
              {t.label}
            </button>
          ))}
        </div>

        {tab === 'profile' && (
          <div style={{ display: 'grid', gridTemplateColumns: '300px 1fr', gap: 24 }}>
            {/* Profile card */}
            <Card padding={28} style={{ textAlign: 'center', alignSelf: 'start' }}>
              <div style={{
                width: 80, height: 80, borderRadius: '50%',
                background: `linear-gradient(135deg, ${COLORS.primary}, #1558CC)`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                margin: '0 auto 16px', fontSize: 28, fontWeight: 800, color: 'white',
                boxShadow: `0 8px 24px ${COLORS.primary}30`,
              }}>
                {user.initials}
              </div>
              <h3 style={{ margin: '0 0 4px', fontSize: 18, fontWeight: 800, color: COLORS.textPrimary }}>{user.username}</h3>
              <p style={{ margin: '0 0 20px', fontSize: 13, color: COLORS.textSecondary }}>{user.role}</p>
              <div style={{ paddingTop: 16, borderTop: `1px solid ${COLORS.border}` }}>
                {stats.map(s => (
                  <div key={s.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 0', borderBottom: `1px solid ${COLORS.border}` }}>
                    <span style={{ fontSize: 13, color: COLORS.textSecondary }}>{s.label}</span>
                    <span style={{ fontSize: 15, fontWeight: 700, color: s.color }}>{s.value}</span>
                  </div>
                ))}
              </div>
            </Card>

            {/* Edit form */}
            <Card padding={28}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 28 }}>
                <h3 style={{ margin: 0, fontSize: 17, fontWeight: 800, color: COLORS.textPrimary }}>Informations personnelles</h3>
                {!editing && <Button variant="ghost" icon="edit" onClick={() => setEditing(true)}>Modifier</Button>}
              </div>

              {msg && (
                <div style={{
                  padding: '11px 16px', borderRadius: 10, marginBottom: 20,
                  background: msg.startsWith('✓') ? COLORS.success + '10' : COLORS.danger + '10',
                  border: `1px solid ${msg.startsWith('✓') ? COLORS.success : COLORS.danger}25`,
                  fontSize: 13, fontWeight: 500,
                  color: msg.startsWith('✓') ? COLORS.success : COLORS.danger,
                }}>
                  {msg}
                </div>
              )}

              <div>
                <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>Nom d'utilisateur</label>
                <input
                  value={username} onChange={e => setUsername(e.target.value)}
                  disabled={!editing} style={{ ...inputStyle, background: editing ? '#fff' : COLORS.background }}
                />
                <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>Rôle</label>
                {editing ? (
                  <select value={role} onChange={e => setRole(e.target.value)} style={{ ...inputStyle, background: '#fff' }}>
                    <option>Médecin ORL</option>
                    <option>Professeur ORL</option>
                    <option>Interne ORL</option>
                    <option>Chirurgien ORL</option>
                    <option>Audiologiste</option>
                  </select>
                ) : (
                  <input value={role} disabled style={{ ...inputStyle, background: COLORS.background }} />
                )}

                {editing && (
                  <>
                    <div style={{ paddingTop: 20, marginTop: 4, borderTop: `1px solid ${COLORS.border}`, marginBottom: 16 }}>
                      <h4 style={{ fontSize: 14, fontWeight: 700, color: COLORS.textPrimary, margin: '0 0 16px' }}>Changer le mot de passe (optionnel)</h4>
                    </div>
                    {['Mot de passe actuel', 'Nouveau mot de passe', 'Confirmer le nouveau'].map((label, i) => (
                      <div key={label}>
                        <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>{label}</label>
                        <input
                          type="password"
                          value={[currentPwd, newPwd, newPwd2][i]}
                          onChange={e => [setCurrentPwd, setNewPwd, setNewPwd2][i](e.target.value)}
                          style={{ ...inputStyle }}
                        />
                      </div>
                    ))}
                    <div style={{ display: 'flex', gap: 12, marginTop: 4 }}>
                      <Button variant="ghost" onClick={() => { setEditing(false); setUsername(user.username); setRole(user.role); setMsg(''); }}>
                        Annuler
                      </Button>
                      <Button variant="primary" icon="check" onClick={handleSaveProfile}>
                        Enregistrer les modifications
                      </Button>
                    </div>
                  </>
                )}
              </div>
            </Card>
          </div>
        )}

        {tab === 'accounts' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 17, fontWeight: 800, color: COLORS.textPrimary }}>Comptes experts</h3>
                <p style={{ margin: '4px 0 0', fontSize: 13, color: COLORS.textSecondary }}>{users.length} compte{users.length > 1 ? 's' : ''} enregistré{users.length > 1 ? 's' : ''}</p>
              </div>
              <Button variant="primary" icon="plus" onClick={() => setShowCreate(true)}>
                Créer un compte
              </Button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {users.map(u => (
                <Card key={u.username} padding={20} style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
                  <div style={{
                    width: 48, height: 48, borderRadius: '50%', flexShrink: 0,
                    background: u.username === user.username
                      ? `linear-gradient(135deg, ${COLORS.primary}, #1558CC)`
                      : `linear-gradient(135deg, ${COLORS.secondary}, #0284C7)`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 16, fontWeight: 700, color: 'white',
                  }}>
                    {u.initials}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: COLORS.textPrimary, display: 'flex', alignItems: 'center', gap: 10 }}>
                      {u.username}
                      {u.username === user.username && (
                        <span style={{ fontSize: 11, fontWeight: 700, background: COLORS.primary + '12', color: COLORS.primary, padding: '2px 8px', borderRadius: 99 }}>
                          Vous
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: 13, color: COLORS.textSecondary, marginTop: 2 }}>{u.role}</div>
                  </div>
                  {u.username !== user.username && (
                    <Button variant="danger" size="sm" icon="trash" onClick={() => setDeleteConfirm(u.username)}>
                      Supprimer
                    </Button>
                  )}
                </Card>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Create account modal */}
      <Modal open={showCreate} onClose={() => { setShowCreate(false); setCreateMsg(''); }} title="Créer un compte expert" width={460}>
        <div>
          {[
            { label: 'Nom complet', value: newName, onChange: setNewName, placeholder: 'Dr Prénom Nom', type: 'text', required: true },
          ].map(f => (
            <div key={f.label}>
              <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>
                {f.label}{f.required && <span style={{ color: COLORS.danger }}> *</span>}
              </label>
              <input
                type={f.type} value={f.value} onChange={e => f.onChange(e.target.value)}
                placeholder={f.placeholder}
                style={{ width: '100%', padding: '11px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', marginBottom: 16, boxSizing: 'border-box' as const }}
              />
            </div>
          ))}
          <div>
            <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>Rôle</label>
            <select value={newRole} onChange={e => setNewRole(e.target.value)}
              style={{ width: '100%', padding: '11px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', marginBottom: 16 }}>
              <option>Médecin ORL</option>
              <option>Professeur ORL</option>
              <option>Interne ORL</option>
              <option>Chirurgien ORL</option>
              <option>Audiologiste</option>
            </select>
          </div>
          {['Mot de passe *', 'Confirmer le mot de passe *'].map((label, i) => (
            <div key={label}>
              <label style={{ display: 'block', marginBottom: 6, fontSize: 13, fontWeight: 600, color: COLORS.textSecondary }}>{label}</label>
              <input
                type="password"
                value={[createPwd, createPwd2][i]}
                onChange={e => [setCreatePwd, setCreatePwd2][i](e.target.value)}
                placeholder="••••••••"
                style={{ width: '100%', padding: '11px 14px', border: `1.5px solid ${COLORS.border}`, borderRadius: 10, fontSize: 14, fontFamily: "'Outfit', sans-serif", outline: 'none', marginBottom: 16, boxSizing: 'border-box' as const }}
              />
            </div>
          ))}
          {createMsg && (
            <div style={{ padding: '10px 14px', borderRadius: 8, marginBottom: 14, background: createMsg.startsWith('✓') ? COLORS.success + '10' : COLORS.danger + '10', border: `1px solid ${createMsg.startsWith('✓') ? COLORS.success : COLORS.danger}25`, fontSize: 13, color: createMsg.startsWith('✓') ? COLORS.success : COLORS.danger }}>
              {createMsg}
            </div>
          )}
          <Button variant="primary" fullWidth icon="plus" onClick={handleCreate}>
            Créer le compte
          </Button>
        </div>
      </Modal>

      {/* Delete confirm modal */}
      <Modal open={!!deleteConfirm} onClose={() => setDeleteConfirm(null)} title="Confirmer la suppression" width={400}>
        <div>
          <p style={{ color: COLORS.textSecondary, fontSize: 14, lineHeight: 1.6, marginTop: 0 }}>
            Êtes-vous sûr de vouloir supprimer le compte <strong style={{ color: COLORS.textPrimary }}>{deleteConfirm}</strong> ? Cette action est irréversible.
          </p>
          <div style={{ display: 'flex', gap: 12, marginTop: 24 }}>
            <Button variant="ghost" onClick={() => setDeleteConfirm(null)} fullWidth>Annuler</Button>
            <Button variant="danger" icon="trash" onClick={() => deleteConfirm && handleDelete(deleteConfirm)} fullWidth>
              Supprimer
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default Profile;

