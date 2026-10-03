import React from 'react';
import { Storage } from './shared';
import { DB } from './supabase';
import Onboarding from './components/Onboarding';
import Login from './components/Login';
import Layout from './components/Layout';
import Dashboard from './components/Dashboard';
import NewConsultation from './components/NewConsultation';
import Reports from './components/Reports';
import Profile from './components/Profile';
import DatasetCollection from './components/DatasetCollection';
import OrlAssistant from './components/OrlAssistant';
import type { User, Consultation } from './shared';

type Route = 'dashboard' | 'new-consultation' | 'reports' | 'profile' | 'dataset';

const App: React.FC = () => {
  const [showOnboarding, setShowOnboarding] = React.useState(true);
  const [user, setUser] = React.useState<User | null>(null);
  const [route, setRoute] = React.useState<Route>('dashboard');
  const [consultations, setConsultations] = React.useState<Consultation[]>(Storage.getConsultations());

  // Try to load from Supabase on mount; localStorage stays as fallback
  React.useEffect(() => {
    DB.loadConsultations()
      .then(data => {
        setConsultations(data);
        Storage.saveConsultations(data); // keep localStorage in sync
      })
      .catch(() => {
        // Supabase not configured or offline — localStorage data already loaded
      });
  }, []);

  const handleLogin = (u: User) => {
    setUser(u);
    setShowOnboarding(false);
  };
  const handleLogout = () => {
    setUser(null);
    setShowOnboarding(true);
  };
  const handleNavigate = (r: string) => setRoute(r as Route);
  const handleUpdateUser = (u: User) => setUser(u);

  if (showOnboarding) return <Onboarding onSkip={() => setShowOnboarding(false)} />;
  if (!user) return <Login onLogin={handleLogin} />;

  const renderPage = () => {
    switch (route) {
      case 'dashboard':
        return <Dashboard consultations={consultations} onNavigate={handleNavigate} />;
      case 'new-consultation':
        return (
          <NewConsultation
            consultations={consultations}
            setConsultations={setConsultations}
            onDone={() => handleNavigate('reports')}
            user={user}
          />
        );
      case 'reports':
        return <Reports consultations={consultations} />;
      case 'profile':
        return (
          <Profile
            user={user}
            onUpdate={handleUpdateUser}
            consultations={consultations}
          />
        );
      case 'dataset':
        return <DatasetCollection />;
      default:
        return <Dashboard consultations={consultations} onNavigate={handleNavigate} />;
    }
  };

  return (
    <Layout user={user} route={route} onNavigate={handleNavigate} onLogout={handleLogout}>
      {renderPage()}
      <OrlAssistant />
    </Layout>
  );
};

export default App;