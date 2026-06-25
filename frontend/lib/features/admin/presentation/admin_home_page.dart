import 'package:flutter/material.dart';

import '../../../core/auth/session_controller.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  late final AdminRepository repository;

  String?
      _subView; // null = Dashboard, 'USERS', 'PATIENTS', 'SYMPTOMS', 'HISTORIES', 'TOUCHES'

  bool _isLoadingStats = false;
  int _userCount = 0;
  int _patientCount = 0;
  int _symptomCount = 0;
  int _historyCount = 0;
  int _touchCount = 0;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    repository = AdminRepository(widget.session.apiClient);
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });
    try {
      final results = await Future.wait([
        repository.listUsers(),
        repository.listPatients(),
        repository.listClinicalItems('SYMPTOM'),
        repository.listClinicalItems('MEDICAL_HISTORY'),
        repository.listClinicalItems('TOUCH_CHECK'),
      ]);

      if (mounted) {
        setState(() {
          _userCount = results[0].length;
          _patientCount = results[1].length;
          _symptomCount = results[2].length;
          _historyCount = results[3].length;
          _touchCount = results[4].length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = 'Erreur de chargement des compteurs: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  void _navigateTo(String? view) {
    setState(() {
      _subView = view;
    });
    if (view == null) {
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = Colors.indigo.shade600;

    return PopScope(
      canPop: _subView == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _subView != null) {
          _navigateTo(null);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: _subView == null
              ? _buildDashboard(context, theme, primaryColor)
              : _buildSubView(context, theme, primaryColor),
        ),
      ),
    );
  }

  // --- Gorgeous Dashboard Home Page ---
  Widget _buildDashboard(
      BuildContext context, ThemeData theme, Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Sleek Modern Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KORAI Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    'Console Admin',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Déconnexion',
                onPressed: widget.session.logout,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded,
                      color: Colors.red.shade600, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Greeting Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Colors.indigo.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Mode Administrateur',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Bonjour, Administrateur 👋',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Supervisez en temps réel les accès cliniques, gérez les dossiers de patients et configurez les dictionnaires de diagnostics IA.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dynamic counters Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vue d\'ensemble système',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              if (_isLoadingStats)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _loadStats,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_statsError != null) ...[
            Text(_statsError!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
            const SizedBox(height: 8),
          ],

          // Counter grid
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Comptes Utilisateurs',
                      count: _userCount,
                      icon: Icons.people_outline_rounded,
                      color: Colors.blue.shade600,
                      onTap: () => _navigateTo('USERS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Patients',
                      count: _patientCount,
                      icon: Icons.personal_injury_rounded,
                      color: Colors.teal.shade600,
                      onTap: () => _navigateTo('PATIENTS'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Symptômes IA',
                      count: _symptomCount,
                      icon: Icons.sick_outlined,
                      color: Colors.amber.shade700,
                      onTap: () => _navigateTo('SYMPTOMS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Antécédents Médicaux',
                      count: _historyCount,
                      icon: Icons.history_edu_outlined,
                      color: Colors.purple.shade600,
                      onTap: () => _navigateTo('HISTORIES'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Vérifications au Toucher',
                count: _touchCount,
                icon: Icons.touch_app_outlined,
                color: Colors.deepOrange.shade600,
                onTap: () => _navigateTo('TOUCHES'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Modules Management Title
          const Text(
            'Modules de gestion',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          // Launcher cards for Subviews
          _buildLauncherItem(
            title: 'Gestion des Comptes',
            subtitle: 'Créer, modifier et suspendre les accès praticiens.',
            icon: Icons.group_outlined,
            color: Colors.blue,
            onTap: () => _navigateTo('USERS'),
          ),
          const SizedBox(height: 10),
          _buildLauncherItem(
            title: 'Dossiers Patients',
            subtitle: 'Suivi global, consentement et fiches administratives.',
            icon: Icons.personal_injury_outlined,
            color: Colors.teal,
            onTap: () => _navigateTo('PATIENTS'),
          ),
          const SizedBox(height: 10),
          _buildLauncherItem(
            title: 'Dictionnaire des Symptômes',
            subtitle: 'Définir les symptômes analysés par l\'IA.',
            icon: Icons.sick_outlined,
            color: Colors.amber,
            onTap: () => _navigateTo('SYMPTOMS'),
          ),
          const SizedBox(height: 10),
          _buildLauncherItem(
            title: 'Antécédents Médicaux',
            subtitle: 'Dictionnaire des pathologies et facteurs de risque.',
            icon: Icons.history_edu_outlined,
            color: Colors.purple,
            onTap: () => _navigateTo('HISTORIES'),
          ),
          const SizedBox(height: 10),
          _buildLauncherItem(
            title: 'Vérifications au Toucher',
            subtitle: 'Actes de palpation et pressions auriculaires.',
            icon: Icons.touch_app_outlined,
            color: Colors.deepOrange,
            onTap: () => _navigateTo('TOUCHES'),
          ),
          const SizedBox(height: 24),

          // System Health Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security_rounded,
                      color: Colors.green.shade600, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statut de l\'Infrastructure',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Base de données sync, chiffrement SSL activé.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: Colors.white),
                      SizedBox(width: 4),
                      Text('EN LIGNE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 110,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.grey, size: 12),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLauncherItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade600, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Unified Modern Sub-view builder ---
  Widget _buildSubView(
      BuildContext context, ThemeData theme, Color primaryColor) {
    final title = switch (_subView) {
      'USERS' => 'Comptes Praticiens',
      'PATIENTS' => 'Dossiers Patients',
      'SYMPTOMS' => 'Dictionnaire Symptômes',
      'HISTORIES' => 'Antécédents Médicaux',
      'TOUCHES' => 'Verifications Toucher',
      _ => 'Administration',
    };

    return Column(
      children: [
        // Subview Elegant Header with Custom Back Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _navigateTo(null),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B)),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_subView) {
            'USERS' => AdminUsersTab(repository: repository),
            'PATIENTS' => AdminPatientsTab(repository: repository),
            'SYMPTOMS' => ClinicalItemsTab(
                repository: repository, type: 'SYMPTOM', title: 'symptome'),
            'HISTORIES' => ClinicalItemsTab(
                repository: repository,
                type: 'MEDICAL_HISTORY',
                title: 'antecedent'),
            'TOUCHES' => ClinicalItemsTab(
                repository: repository,
                type: 'TOUCH_CHECK',
                title: 'verification au toucher'),
            _ => const SizedBox(),
          },
        ),
      ],
    );
  }
}

// --- BEAUTIFUL MODERNIZED TABS ---

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  List<AdminUser> users = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      users = await widget.repository.listUsers();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> openForm([AdminUser? user]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => UserFormDialog(user: user),
    );
    if (result == null) return;

    try {
      if (user == null) {
        await widget.repository.createUser(result);
      } else {
        await widget.repository.updateUser(user.id, result);
      }
      await load();
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> delete(AdminUser user) async {
    final confirmed =
        await confirmDelete(context, 'Supprimer ${user.fullName} ?');
    if (!confirmed) return;
    try {
      await widget.repository.deleteUser(user.id);
      await load();
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      title: 'Comptes utilisateurs',
      isLoading: isLoading,
      errorMessage: errorMessage,
      onRefresh: load,
      onCreate: () => openForm(),
      children: users
          .map(
            (user) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: _roleColor(user.role).withValues(alpha: 0.1),
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        color: _roleColor(user.role),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _roleColor(user.role).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role,
                        style: TextStyle(
                            color: _roleColor(user.role),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => openForm(user),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade400),
                      onPressed: () => delete(user),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'ADMIN' => Colors.purple,
      'SPECIALIST' => Colors.blue,
      'NURSE' => Colors.teal,
      'PATIENT' => Colors.orange,
      _ => Colors.grey,
    };
  }
}

class AdminPatientsTab extends StatefulWidget {
  const AdminPatientsTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminPatientsTab> createState() => _AdminPatientsTabState();
}

class _AdminPatientsTabState extends State<AdminPatientsTab> {
  List<AdminPatient> patients = [];
  List<AdminPatient> deletedPatients = [];
  bool showTrash = false;
  AdminPatient? selectedPatient;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.listPatients(),
        widget.repository.listDeletedPatients(),
      ]);
      patients = results[0];
      deletedPatients = results[1];
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> openForm([AdminPatient? patient]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PatientFormDialog(patient: patient),
    );
    if (result == null) return;

    try {
      if (patient == null) {
        await widget.repository.createPatient(result);
      } else {
        await widget.repository.updatePatient(patient.id, result);
      }
      await load();
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> delete(AdminPatient patient) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed =
        await confirmDelete(context, 'Supprimer le dossier complet de ${patient.fullName} ?');
    if (!confirmed) return;
    try {
      await widget.repository.deletePatient(patient.id);
      await load();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Dossier de ${patient.fullName} supprimé'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              try {
                await widget.repository.restorePatient(patient.id);
                await load();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erreur de restauration: $e')),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> restore(AdminPatient patient) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      await widget.repository.restorePatient(patient.id);
      await load();
      messenger.showSnackBar(
        SnackBar(content: Text('Dossier de ${patient.fullName} restauré')),
      );
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Widget _buildTabsToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => showTrash = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !showTrash ? Colors.indigo.shade600 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Actifs (${patients.length})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !showTrash ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => showTrash = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: showTrash ? Colors.indigo.shade600 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Corbeille (${deletedPatients.length})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: showTrash ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedPatient != null) {
      return PatientDossierView(
        patient: selectedPatient!,
        repository: widget.repository,
        onBack: () => setState(() => selectedPatient = null),
        onPatientUpdated: (updated) {
          setState(() {
            selectedPatient = updated;
          });
          load();
        },
        onPatientDeleted: (patient) async {
          setState(() => selectedPatient = null);
          await load();
        },
      );
    }

    final displayedPatients = showTrash ? deletedPatients : patients;

    return AdminListScaffold(
      title: 'Patients',
      isLoading: isLoading,
      errorMessage: errorMessage,
      onRefresh: load,
      onCreate: () => openForm(),
      children: [
        _buildTabsToggle(),
        ...displayedPatients.map(
          (patient) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: showTrash
                  ? null
                  : () => setState(() => selectedPatient = patient),
              leading: CircleAvatar(
                backgroundColor: showTrash ? Colors.red.shade50 : Colors.teal.shade50,
                child: Icon(
                  showTrash ? Icons.delete_sweep_rounded : Icons.personal_injury_rounded,
                  color: showTrash ? Colors.red.shade600 : Colors.teal.shade600,
                ),
              ),
              title: Text(patient.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    [patient.phone, patient.address]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (showTrash)
                    Text(
                      'Supprimé le: ${patient.deletedAt != null ? formatDate(patient.deletedAt!) : "Inconnu"}',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                    )
                  else
                    Row(
                      children: [
                        if (patient.consentForAi)
                          _buildConsentBadge('IA Agréé', Colors.green)
                        else
                          _buildConsentBadge('IA Refusé', Colors.red),
                        const SizedBox(width: 6),
                        if (patient.consentForTeleExpertise)
                          _buildConsentBadge('Expertise OK', Colors.blue)
                        else
                          _buildConsentBadge('Expertise NO', Colors.grey),
                      ],
                    ),
                ],
              ),
              trailing: showTrash
                  ? IconButton(
                      tooltip: 'Restaurer',
                      icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.green),
                      onPressed: () => restore(patient),
                    )
                  : Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          onPressed: () => openForm(patient),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400),
                          onPressed: () => delete(patient),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// --- SUBVIEW PATIENT DOSSIER VIEW ---

class PatientDossierView extends StatefulWidget {
  const PatientDossierView({
    super.key,
    required this.patient,
    required this.repository,
    required this.onBack,
    required this.onPatientUpdated,
    required this.onPatientDeleted,
  });

  final AdminPatient patient;
  final AdminRepository repository;
  final VoidCallback onBack;
  final ValueChanged<AdminPatient> onPatientUpdated;
  final ValueChanged<AdminPatient> onPatientDeleted;

  @override
  State<PatientDossierView> createState() => _PatientDossierViewState();
}

class _PatientDossierViewState extends State<PatientDossierView> {
  List<AdminConsultation> consultations = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadConsultations();
  }

  Future<void> loadConsultations() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      consultations = await widget.repository.listPatientConsultations(widget.patient.id);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> openEditForm() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PatientFormDialog(patient: widget.patient),
    );
    if (result == null) return;

    try {
      final updated = await widget.repository.updatePatient(widget.patient.id, result);
      widget.onPatientUpdated(updated);
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> deletePatient() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDelete(context, 'Supprimer le dossier complet de ${widget.patient.fullName} (cette action soft-deletes toutes ses consultations) ?');
    if (!confirmed) return;
    try {
      await widget.repository.deletePatient(widget.patient.id);
      widget.onPatientDeleted(widget.patient);
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Dossier de ${widget.patient.fullName} supprimé'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              try {
                await widget.repository.restorePatient(widget.patient.id);
                widget.onPatientUpdated(widget.patient);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erreur de restauration: $e')),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> deleteConsult(AdminConsultation consult) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDelete(context, 'Supprimer cette consultation ?');
    if (!confirmed) return;
    try {
      await widget.repository.deleteConsultation(consult.id);
      await loadConsultations();
      
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Consultation supprimée'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              try {
                await widget.repository.restoreConsultation(consult.id);
                await loadConsultations();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erreur de restauration: $e')),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Dossier Patient',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            tooltip: 'Modifier patient',
            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
            onPressed: openEditForm,
          ),
          IconButton(
            tooltip: 'Supprimer dossier complet',
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            onPressed: deletePatient,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadConsultations,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPatientDetailsCard(),
            const SizedBox(height: 24),
            const Text(
              'Historique des Consultations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (errorMessage != null) ...[
              Text(errorMessage!, style: TextStyle(color: Colors.red.shade600)),
              const SizedBox(height: 12),
            ],
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (consultations.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Aucune consultation enregistrée',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...consultations.asMap().entries.map((entry) {
                final index = entry.key;
                final consult = entry.value;
                return _buildTimelineItem(consult, index, consultations.length);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.shade50,
                child: Icon(Icons.personal_injury_rounded, size: 28, color: Colors.teal.shade600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patient.fullName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sexe: ${widget.patient.sex == 'M' ? 'Masculin' : 'Féminin'} • Né(e) le: ${widget.patient.birthDate ?? 'Inconnu'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (widget.patient.phone != null && widget.patient.phone!.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_outlined, 'Téléphone', widget.patient.phone!),
            const SizedBox(height: 12),
          ],
          if (widget.patient.address != null && widget.patient.address!.isNotEmpty) ...[
            _buildInfoRow(Icons.map_outlined, 'Adresse', widget.patient.address!),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.patient.consentForAi)
                _buildConsentBadge('IA Agréé', Colors.green)
              else
                _buildConsentBadge('IA Refusé', Colors.red),
              const SizedBox(width: 8),
              if (widget.patient.consentForTeleExpertise)
                _buildConsentBadge('Expertise OK', Colors.blue)
              else
                _buildConsentBadge('Expertise NO', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text('$label : ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF334155), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildConsentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConsultationCard(AdminConsultation consult) {
    final urgencyColor = _getUrgencyColor(consult.urgency);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: urgencyColor, width: 5),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showConsultationDetail(context, consult, () => deleteConsult(consult)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatDate(consult.createdAt),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                            ),
                            const Spacer(),
                            _buildBadge(consult.urgency, _getUrgencyColor(consult.urgency)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          consult.clinicalNarrative.isNotEmpty
                              ? consult.clinicalNarrative
                              : 'Aucune description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(AdminConsultation consult, int index, int total) {
    final urgencyColor = _getUrgencyColor(consult.urgency);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: index == 0 ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: urgencyColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: index == total - 1 ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildConsultationCard(consult),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CONSULTATION DETAILS BOTTOM SHEET ---

void showConsultationDetail(BuildContext context, AdminConsultation consultation, VoidCallback onDelete) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.85,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Détails Consultation',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildBadge(consultation.status, _getStatusColor(consultation.status)),
                            const SizedBox(width: 8),
                            _buildBadge(consultation.urgency, _getUrgencyColor(consultation.urgency)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Date de création',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(consultation.createdAt),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Symptômes déclarés',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        consultation.symptomLabels.isEmpty
                            ? const Text('Aucun symptôme déclaré', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: consultation.symptomLabels
                                    .map((label) => Chip(
                                          label: Text(label, style: const TextStyle(fontSize: 11)),
                                          backgroundColor: Colors.grey.shade100,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ))
                                    .toList(),
                              ),
                        const SizedBox(height: 16),
                        const Text(
                          'Description clinique',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            consultation.clinicalNarrative.isNotEmpty
                                ? consultation.clinicalNarrative
                                : 'Aucune description clinique fournie.',
                            style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                          ),
                        ),
                        if (consultation.otoscopicImages.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Images ORL & Descriptions',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ...consultation.otoscopicImages.map((img) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.image_outlined, color: Colors.indigo.shade400, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Oreille ${img.earSide == "LEFT" ? "Gauche" : img.earSide == "RIGHT" ? "Droite" : "Bilatérale"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                if (img.description != null && img.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    img.description!,
                                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Aucune description fournie',
                                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          )),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade50, Colors.orange.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.psychology_rounded, color: Colors.amber.shade800, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Diagnostic IA Vraisemblable',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      consultation.likelyDiagnosis ?? 'Aucun diagnostic généré',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(color: Colors.red.shade200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Supprimer la consultation', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  onDelete();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

Color _getStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
      return Colors.green.shade700;
    case 'IN_PROGRESS':
      return Colors.blue.shade700;
    case 'PENDING':
      return Colors.orange.shade700;
    default:
      return Colors.grey.shade700;
  }
}

Color _getUrgencyColor(String urgency) {
  switch (urgency.toUpperCase()) {
    case 'HIGH':
    case 'EMERGENCY':
    case 'CRITICAL':
      return Colors.red.shade700;
    case 'MEDIUM':
      return Colors.orange.shade700;
    case 'LOW':
      return Colors.green.shade700;
    default:
      return Colors.grey.shade700;
  }
}

String formatDate(String isoString) {
  try {
    final date = DateTime.parse(isoString).toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  } catch (_) {
    return isoString;
  }
}


class ClinicalItemsTab extends StatefulWidget {
  const ClinicalItemsTab({
    super.key,
    required this.repository,
    required this.type,
    required this.title,
  });

  final AdminRepository repository;
  final String type;
  final String title;

  @override
  State<ClinicalItemsTab> createState() => _ClinicalItemsTabState();
}

class _ClinicalItemsTabState extends State<ClinicalItemsTab> {
  List<ClinicalReferenceItem> items = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      items = await widget.repository.listClinicalItems(widget.type);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> openForm([ClinicalReferenceItem? item]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ClinicalItemFormDialog(
          type: widget.type, title: widget.title, item: item),
    );
    if (result == null) return;

    try {
      if (item == null) {
        await widget.repository.createClinicalItem(result);
      } else {
        await widget.repository.updateClinicalItem(item.id, result);
      }
      await load();
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  Future<void> delete(ClinicalReferenceItem item) async {
    final confirmed = await confirmDelete(context, 'Supprimer ${item.label} ?');
    if (!confirmed) return;
    try {
      await widget.repository.deleteClinicalItem(item.id);
      await load();
    } catch (error) {
      setState(() => errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      title: '${widget.title}s',
      isLoading: isLoading,
      errorMessage: errorMessage,
      onRefresh: load,
      onCreate: () => openForm(),
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: item.isActive
                      ? Colors.teal.shade50
                      : Colors.grey.shade100,
                  child: Icon(
                    item.isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: item.isActive ? Colors.teal : Colors.grey,
                  ),
                ),
                title: Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    item.description ?? 'Aucune description',
                    style: const TextStyle(fontSize: 12)),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.type == 'SYMPTOM' ||
                        item.type == 'MEDICAL_HISTORY')
                      dangerScoreBadge(item.dangerScore),
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => openForm(item),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade400),
                      onPressed: () => delete(item),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// --- Sleek Custom List Scaffold for Admin Sub-views ---
class AdminListScaffold extends StatelessWidget {
  const AdminListScaffold({
    super.key,
    required this.title,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onCreate,
    required this.children,
  });

  final String title;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final message = errorMessage;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(message,
                            style: TextStyle(
                                color: Colors.red.shade800, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isLoading) ...[
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('Aucun élément trouvé',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                ...children,
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Créer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade600,
        elevation: 4,
      ),
    );
  }
}

// --- PREMIUM DIALOG FORMS ---

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.user});

  final AdminUser? user;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final fullName = TextEditingController(text: widget.user?.fullName);
  late final email = TextEditingController(text: widget.user?.email);
  late final password = TextEditingController();
  late final phone = TextEditingController(text: widget.user?.phone);
  late final healthFacility =
      TextEditingController(text: widget.user?.healthFacility);
  late final professionalId =
      TextEditingController(text: widget.user?.professionalId);
  late String role = widget.user?.role ?? 'NURSE';

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    phone.dispose();
    healthFacility.dispose();
    professionalId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.user == null ? 'Nouveau Praticien' : 'Modifier Compte',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B)),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 12),
              const SizedBox(height: 12),
              _buildField(
                  controller: fullName,
                  label: 'Nom complet',
                  icon: Icons.person_outline),
              const SizedBox(height: 12),
              _buildField(
                  controller: email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress),
              if (widget.user == null) ...[
                const SizedBox(height: 12),
                _buildField(
                    controller: password,
                    label: 'Mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: InputDecoration(
                  labelText: 'Rôle',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: const ['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => role = value ?? role),
              ),
              const SizedBox(height: 12),
              _buildField(
                  controller: phone,
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField(
                  controller: healthFacility,
                  label: 'Structure de Santé',
                  icon: Icons.local_hospital_outlined),
              const SizedBox(height: 12),
              _buildField(
                  controller: professionalId,
                  label: 'Identifiant Professionnel',
                  icon: Icons.assignment_ind_outlined),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final data = <String, dynamic>{
              'fullName': fullName.text,
              'email': email.text,
              'role': role,
              if (phone.text.isNotEmpty) 'phone': phone.text,
              if (healthFacility.text.isNotEmpty)
                'healthFacility': healthFacility.text,
              if (professionalId.text.isNotEmpty)
                'professionalId': professionalId.text,
              if (widget.user == null) 'password': password.text,
            };
            Navigator.pop(context, data);
          },
          child: const Text('Enregistrer',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class PatientFormDialog extends StatefulWidget {
  const PatientFormDialog({super.key, this.patient});

  final AdminPatient? patient;

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  late final firstName = TextEditingController(text: widget.patient?.firstName);
  late final lastName = TextEditingController(text: widget.patient?.lastName);
  late final birthDate = TextEditingController(text: widget.patient?.birthDate);
  late final phone = TextEditingController(text: widget.patient?.phone);
  late final address = TextEditingController(text: widget.patient?.address);
  late String sex = widget.patient?.sex == 'M' ? 'M' : 'F';
  late bool consentForAi = widget.patient?.consentForAi ?? true;
  late bool consentForTeleExpertise =
      widget.patient?.consentForTeleExpertise ?? true;

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    birthDate.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.patient == null ? 'Nouveau Patient' : 'Modifier Fiche Patient',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B)),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildField(
                          controller: firstName,
                          label: 'Prénom',
                          icon: Icons.person_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildField(
                          controller: lastName,
                          label: 'Nom',
                          icon: Icons.person_outline)),
                ],
              ),
              const SizedBox(height: 12),
              _buildField(
                  controller: birthDate,
                  label: 'Date Naissance',
                  icon: Icons.cake_outlined,
                  hint: 'AAAA-MM-JJ'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: sex,
                decoration: InputDecoration(
                  labelText: 'Sexe',
                  prefixIcon: const Icon(Icons.transgender_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'F', child: Text('Féminin (F)')),
                  DropdownMenuItem(value: 'M', child: Text('Masculin (M)')),
                ],
                onChanged: (value) => setState(() => sex = value ?? sex),
              ),
              const SizedBox(height: 12),
              _buildField(
                  controller: phone,
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField(
                  controller: address,
                  label: 'Adresse',
                  icon: Icons.map_outlined),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Consentement Diagnostic IA',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Autoriser l\'envoi des cas aux serveurs IA',
                    style: TextStyle(fontSize: 10)),
                value: consentForAi,
                activeThumbColor: Colors.indigo.shade600,
                onChanged: (value) => setState(() => consentForAi = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Consentement Télé-Expertise',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Partager le cas aux spécialistes KORAI',
                    style: TextStyle(fontSize: 10)),
                value: consentForTeleExpertise,
                activeThumbColor: Colors.indigo.shade600,
                onChanged: (value) =>
                    setState(() => consentForTeleExpertise = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'firstName': firstName.text,
              'lastName': lastName.text,
              if (birthDate.text.isNotEmpty) 'birthDate': birthDate.text,
              'sex': sex,
              if (phone.text.isNotEmpty) 'phone': phone.text,
              if (address.text.isNotEmpty) 'address': address.text,
              'consentForAi': consentForAi,
              'consentForTeleExpertise': consentForTeleExpertise,
            });
          },
          child: const Text('Enregistrer',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class ClinicalItemFormDialog extends StatefulWidget {
  const ClinicalItemFormDialog({
    super.key,
    required this.type,
    required this.title,
    this.item,
  });

  final String type;
  final String title;
  final ClinicalReferenceItem? item;

  @override
  State<ClinicalItemFormDialog> createState() => _ClinicalItemFormDialogState();
}

class _ClinicalItemFormDialogState extends State<ClinicalItemFormDialog> {
  late final label = TextEditingController(text: widget.item?.label);
  late final description =
      TextEditingController(text: widget.item?.description);
  late bool isActive = widget.item?.isActive ?? true;
  late int dangerScore = widget.item?.dangerScore ?? 0;

  static const _dangerLabels = {
    0: '0 — Bénin',
    1: '1 — À surveiller',
    2: '2 — Préoccupant',
    3: '3 — Critique',
  };

  @override
  void dispose() {
    label.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.item == null
            ? 'Nouveau ${widget.title}'
            : 'Modifier ${widget.title}',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B)),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 12),
              const SizedBox(height: 12),
              TextField(
                controller: label,
                decoration: InputDecoration(
                  labelText: 'Libellé',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description optionnelle',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (widget.type == 'SYMPTOM' ||
                  widget.type == 'MEDICAL_HISTORY') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: dangerScore,
                  decoration: InputDecoration(
                    labelText: 'Score de danger (urgence)',
                    prefixIcon: const Icon(Icons.priority_high_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  items: _dangerLabels.entries
                      .map((e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => dangerScore = value ?? 0),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Élément Actif',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Rendre visible dans les sprints praticiens et patients',
                    style: TextStyle(fontSize: 10)),
                value: isActive,
                activeThumbColor: Colors.indigo.shade600,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'type': widget.type,
              'label': label.text,
              if (description.text.isNotEmpty) 'description': description.text,
              'isActive': isActive,
              'dangerScore': dangerScore,
            });
          },
          child: const Text('Enregistrer',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Petit badge coloré du score de danger (0–3) d'un élément clinique.
Widget dangerScoreBadge(int score) {
  final color = switch (score) {
    >= 3 => const Color(0xFFEF4444),
    2 => const Color(0xFFF59E0B),
    1 => const Color(0xFFCA8A04),
    _ => Colors.grey,
  };
  return Tooltip(
    message: 'Score de danger : $score / 3',
    child: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$score',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Suppression',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ??
      false;
}
