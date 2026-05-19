import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_controller.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';
import 'nurse_consultation_view_model.dart';
import '../../chatbot/presentation/korai_chatbot_screen.dart';

class NurseHomePage extends StatefulWidget {
  const NurseHomePage({super.key, required this.session});

  final SessionController session;

  @override
  State<NurseHomePage> createState() => _NurseHomePageState();
}

class _NurseHomePageState extends State<NurseHomePage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final ageController = TextEditingController();
  final notesController = TextEditingController();
  String sex = 'F';

  late final NurseConsultationViewModel viewModel;
  late final NurseRepository repository;

  int _currentTab = 0; // 0 = Home/Dashboard, 1 = Chatbot, 2 = Consultation, 3 = Rapport, 4 = Profil
  bool _isSprintActive = false; // Whether the consultation wizard is active
  bool _isLoadingStats = false;
  List<Patient> _patients = [];
  List<AiCase> _cases = [];
  String _searchQuery = '';
  String _pendingSearchQuery = '';

  static const steps = [
    'Patient',
    'Symptômes',
    'Antécédents',
    'Toucher',
    'Image ORL',
    'Récapitulatif',
  ];

  @override
  void initState() {
    super.initState();
    repository = NurseRepository(widget.session.apiClient);
    viewModel = NurseConsultationViewModel(
      repository: repository,
    );
    viewModel.loadClinicalReferences();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingStats = true);
    try {
      final results = await Future.wait([
        repository.listPatients(),
        repository.listCases(),
      ]);
      setState(() {
        _patients = results[0] as List<Patient>;
        _cases = results[1] as List<AiCase>;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  void _showNotificationBottomSheet(BuildContext context, List<Patient> unvalidatedPatients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006D77),
                        ),
                  ),
                  if (unvalidatedPatients.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Text(
                        '${unvalidatedPatients.length} en attente',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              if (unvalidatedPatients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Aucune nouvelle notification',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: unvalidatedPatients.length,
                    itemBuilder: (context, index) {
                      final patient = unvalidatedPatients[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_outlined, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                                      children: [
                                        const TextSpan(text: 'Nouveau compte créé par '),
                                        TextSpan(
                                          text: patient.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(text: '. À valider.'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    patient.phone ?? 'Pas de téléphone',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006D77),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                try {
                                  setState(() => _isLoadingStats = true);
                                  await repository.validatePatient(patient.id);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Le compte de ${patient.fullName} a été validé !'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  await _loadDashboardData();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur lors de la validation: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  setState(() => _isLoadingStats = false);
                                }
                              },
                              child: const Text('Valider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    ageController.dispose();
    notesController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _startNewPatientConsultation() {
    setState(() {
      firstNameController.clear();
      lastNameController.clear();
      phoneController.clear();
      addressController.clear();
      ageController.clear();
      notesController.clear();
      sex = 'F';
      viewModel.patient = null;
      viewModel.image = null;
      viewModel.aiCase = null;
      viewModel.currentStep = 0;
      viewModel.selectedSymptomIds.clear();
      viewModel.selectedMedicalHistoryIds.clear();
      viewModel.selectedTouchCheckIds.clear();
      _isSprintActive = true;
    });
  }

  void _startExistingPatientConsultation(Patient patient) {
    setState(() {
      viewModel.patient = patient;
      lastNameController.text = patient.lastName;
      firstNameController.text = patient.firstName;
      phoneController.text = patient.phone ?? '';
      addressController.text = patient.address ?? '';
      ageController.text = patient.birthDate?.replaceAll('Age: ', '') ?? '';
      sex = patient.sex ?? 'F';
      viewModel.image = null;
      viewModel.aiCase = null;
      viewModel.currentStep = 0;
      viewModel.selectedSymptomIds.clear();
      viewModel.selectedMedicalHistoryIds.clear();
      viewModel.selectedTouchCheckIds.clear();
      notesController.clear();

      // Try to find a draft case for this patient to pre-populate clinical data
      final draftCases = _cases.where((c) => c.patientId == patient.id && c.status == 'DRAFT').toList();
      if (draftCases.isNotEmpty) {
        final draftCase = draftCases.first;
        final narrative = draftCase.symptoms;

        if (narrative != null && narrative.isNotEmpty) {
          // Parse symptoms
          for (final symptom in viewModel.symptoms) {
            if (narrative.toLowerCase().contains(symptom.label.toLowerCase())) {
              viewModel.selectedSymptomIds.add(symptom.id);
            }
          }

          // Parse histories
          for (final history in viewModel.medicalHistories) {
            if (narrative.toLowerCase().contains(history.label.toLowerCase())) {
              viewModel.selectedMedicalHistoryIds.add(history.id);
            }
          }

          // Parse notes
          final notesIndex = narrative.indexOf('Notes libres:');
          if (notesIndex != -1) {
            notesController.text = narrative.substring(notesIndex + 13).trim();
          } else {
            final altNotesIndex = narrative.indexOf('Notes:');
            if (altNotesIndex != -1) {
              notesController.text = narrative.substring(altNotesIndex + 6).trim();
            }
          }
        }
      }

      _isSprintActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: _buildCurrentTabBody(),
          ),
          bottomNavigationBar: _isSprintActive && _currentTab == 2
              ? null // Hide bottom bar when inside active consultation sprint
              : _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTab) {
      case 0:
        return _buildDashboard();
      case 1:
        return KoraiChatbotScreen(userName: widget.session.user?.fullName);
      case 2:
        return _buildConsultationTab();
      case 3:
        return _buildRapportTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildDashboard();
    }
  }

  // --- DASHBOARD UI ---
  Widget _buildDashboard() {
    final colorScheme = Theme.of(context).colorScheme;
    final nurseName = widget.session.user?.fullName ?? 'Professionnel';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Premium Header (as in the screenshot)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF80ED99).withOpacity(0.9),
                  const Color(0xFFC7F9CC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hearing, size: 28, color: Color(0xFF006D77)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KORAI',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF006D77),
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            Text(
                              'Assistant ORL IA',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF006D77).withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final unvalidatedPatients = _patients.where((p) => !p.isValidated).toList();
                            final count = unvalidatedPatients.length;
                            return IconButton(
                              onPressed: () => _showNotificationBottomSheet(context, unvalidatedPatients),
                              icon: count > 0
                                  ? Badge(
                                      label: Text('$count'),
                                      child: const Icon(Icons.notifications_active, color: Color(0xFF006D77)),
                                    )
                                  : const Icon(Icons.notifications_none, color: Color(0xFF006D77)),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => setState(() => _currentTab = 4),
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF006D77)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Tab links below the header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HeaderTabButton(
                      label: 'Consultation',
                      onPressed: () => setState(() => _currentTab = 2),
                    ),
                    _HeaderTabButton(
                      label: 'Otoscope',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Module Otoscope en cours de préparation.')),
                        );
                      },
                    ),
                    _HeaderTabButton(
                      label: 'Rapport',
                      onPressed: () => setState(() => _currentTab = 3),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Greeting Card (as in the screenshot)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour, $nurseName',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Bienvenue sur KORAI.',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.sentiment_satisfied_alt_outlined, size: 48, color: Color(0xFF006D77)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Three Counters Grid (as in the screenshot)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Consultation',
                        value: _isLoadingStats ? '...' : '${_cases.length}',
                        color: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Patients',
                        value: _isLoadingStats ? '...' : '${_patients.length}',
                        color: const Color(0xFFE0F2F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Diagnostic',
                        value: _isLoadingStats ? '...' : '${_cases.where((c) => c.status == 'AI_COMPLETED' || c.status == 'SPECIALIST_COMPLETED').length}',
                        color: const Color(0xFFF1F8E9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 4. "C'est quoi KORAI ?" Section (as in the screenshot)
                Center(
                  child: Text(
                    "C'est quoi KORAI ?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Four illustrated descriptions
                _buildKoraiFeatureRow(
                  icon: Icons.assignment_outlined,
                  title: 'Gestion sécurisée des dossiers patients ORL',
                  description: 'Sauvegardez les données et images dans un espace crypté.',
                ),
                _buildKoraiFeatureRow(
                  icon: Icons.recommend_outlined,
                  title: 'Accès rapide aux recommandations médicales',
                  description: 'Obtenez des suggestions de traitement approuvées par l\'IA.',
                ),
                _buildKoraiFeatureRow(
                  icon: Icons.people_outline,
                  title: 'Collaboration fluide entre professionnels de santé',
                  description: 'Partagez instantanément les cas complexes avec des experts.',
                ),
                _buildKoraiFeatureRow(
                  icon: Icons.lock_outline,
                  title: 'Confidentialité optimale grâce au chiffrement des données',
                  description: 'Respectez scrupuleusement la confidentialité médicale de vos patients.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF006D77)),
          ),
        ],
      ),
    );
  }

  Widget _buildKoraiFeatureRow({required IconData icon, required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8F5E9),
            child: Icon(icon, color: const Color(0xFF006D77)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CONSULTATION SCREEN (SELECTION & SPRINT WIZARD) ---
  Widget _buildConsultationTab() {
    if (_isSprintActive) {
      return _buildConsultationSprintWizard();
    }

    final filteredPendingPatients = _patients.where((p) => !p.isValidated).where((p) {
      if (_pendingSearchQuery.isEmpty) return true;
      final query = _pendingSearchQuery.toLowerCase();
      final phone = p.phone?.toLowerCase() ?? '';
      final fullName = p.fullName.toLowerCase();
      return phone.contains(query) || fullName.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Lancer une consultation',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('Choisissez l\'origine du dossier patient.'),
        const SizedBox(height: 24),

        // Two big selection cards
        Row(
          children: [
            Expanded(
              child: _buildConsultationSelectionCard(
                icon: Icons.person_add_outlined,
                title: 'Nouveau Patient',
                description: 'Enregistrer un nouveau dossier de consultation.',
                onTap: _startNewPatientConsultation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildConsultationSelectionCard(
                icon: Icons.people_outline,
                title: 'Patient Existant',
                description: 'Sélectionner un dossier patient déjà enregistré.',
                onTap: () {
                  setState(() => _searchQuery = '');
                  _showExistingPatientsDialog();
                },
              ),
            ),
          ],
        ),

        // Accounts waiting validation section
        if (_patients.any((p) => !p.isValidated)) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Comptes patients en attente (${_patients.where((p) => !p.isValidated).length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.orange),
              hintText: 'Rechercher par téléphone ou nom...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade200),
              ),
            ),
            onChanged: (val) {
              setState(() => _pendingSearchQuery = val);
            },
          ),
          const SizedBox(height: 12),
          if (filteredPendingPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Aucun compte patient en attente ne correspond.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...filteredPendingPatients.map((patient) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            patient.phone ?? 'Pas de téléphone renseigné',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006D77),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Valider & Ouvrir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        try {
                          setState(() => _isLoadingStats = true);
                          await repository.validatePatient(patient.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Le compte de ${patient.fullName} a été validé !'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _loadDashboardData();
                          _startExistingPatientConsultation(patient);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur lors de la validation: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          setState(() => _isLoadingStats = false);
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildConsultationSelectionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(icon, size: 28, color: const Color(0xFF006D77)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF006D77)),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showExistingPatientsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredPatients = _patients.where((p) {
              final query = _searchQuery.toLowerCase();
              return p.firstName.toLowerCase().contains(query) ||
                  p.lastName.toLowerCase().contains(query) ||
                  (p.phone ?? '').contains(query);
            }).toList();

            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sélectionner un patient',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Rechercher par nom, prénom ou téléphone...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setModalState(() => _searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredPatients.isEmpty
                        ? const Center(child: Text('Aucun patient trouvé.'))
                        : ListView.builder(
                            itemCount: filteredPatients.length,
                            itemBuilder: (context, index) {
                              final p = filteredPatients[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF006D77),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(
                                    '${p.firstName} ${p.lastName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(p.phone ?? 'Pas de numéro de téléphone'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _startExistingPatientConsultation(p);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- CONSULTATION WIZARD UI ---
  Widget _buildConsultationSprintWizard() {
    return Column(
      children: [
        // App header inside consultation to return or close
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Quitter la consultation ?'),
                      content: const Text('Toutes les données saisies pour ce sprint seront perdues.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() => _isSprintActive = false);
                          },
                          child: const Text('Confirmer'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                viewModel.patient != null ? 'Consultation (Existant)' : 'Consultation (Nouveau)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                'Étape ${viewModel.currentStep + 1}/${steps.length}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        SprintProgress(
          steps: steps,
          currentStep: viewModel.currentStep,
          onTap: viewModel.goToStep,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (viewModel.errorMessage != null) ...[
                ErrorBanner(message: viewModel.errorMessage!),
                const SizedBox(height: 12),
              ],
              SprintCard(
                title: steps[viewModel.currentStep],
                child: _currentStepBody(),
              ),
              if (viewModel.aiCase != null) ...[
                const SizedBox(height: 16),
                AiResultCard(aiCase: viewModel.aiCase!),
              ],
            ],
          ),
        ),
        SprintNavigationBar(
          isFirst: viewModel.currentStep == 0,
          isLast: viewModel.currentStep == steps.length - 1,
          isBusy: viewModel.isSubmitting,
          onPrevious: viewModel.previousStep,
          onNext: _handleNext,
        ),
      ],
    );
  }

  Widget _currentStepBody() {
    return switch (viewModel.currentStep) {
      0 => PatientInfoStep(
          firstNameController: firstNameController,
          lastNameController: lastNameController,
          phoneController: phoneController,
          addressController: addressController,
          ageController: ageController,
          sex: sex,
          onSexChanged: (value) => setState(() => sex = value),
        ),
      1 => ClinicalSelectionStep(
          items: viewModel.symptoms,
          selectedIds: viewModel.selectedSymptomIds,
          emptyText: 'Aucun symptôme configuré',
          onChanged: (id, selected) => viewModel.toggleSelection('SYMPTOM', id, selected),
        ),
      2 => ClinicalSelectionStep(
          items: viewModel.medicalHistories,
          selectedIds: viewModel.selectedMedicalHistoryIds,
          emptyText: 'Aucun antécédent configuré',
          onChanged: (id, selected) => viewModel.toggleSelection('MEDICAL_HISTORY', id, selected),
        ),
      3 => ClinicalSelectionStep(
          items: viewModel.touchChecks,
          selectedIds: viewModel.selectedTouchCheckIds,
          emptyText: 'Aucune vérification configurée',
          onChanged: (id, selected) => viewModel.toggleSelection('TOUCH_CHECK', id, selected),
        ),
      4 => ImageStep(
          hasImage: viewModel.image != null,
          onCamera: () => viewModel.pickImage(ImageSource.camera),
          onGallery: () => viewModel.pickImage(ImageSource.gallery),
        ),
      _ => RecapStep(
          firstName: firstNameController.text,
          lastName: lastNameController.text,
          phone: phoneController.text,
          address: addressController.text,
          age: ageController.text,
          sex: sex,
          notesController: notesController,
          selectedSymptoms: viewModel.labelsFor(viewModel.symptoms, viewModel.selectedSymptomIds),
          selectedHistories: viewModel.labelsFor(viewModel.medicalHistories, viewModel.selectedMedicalHistoryIds),
          selectedTouchChecks: viewModel.labelsFor(viewModel.touchChecks, viewModel.selectedTouchCheckIds),
          hasImage: viewModel.image != null,
          requestSpecialistReview: viewModel.requestSpecialistReview,
          onReviewChanged: viewModel.setRequestSpecialistReview,
        ),
    };
  }

  void _handleNext() {
    if (viewModel.currentStep < steps.length - 1) {
      viewModel.nextStep();
      return;
    }

    viewModel.submitSprint(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      phone: phoneController.text,
      address: addressController.text,
      age: ageController.text,
      sex: sex,
      notes: notesController.text,
    ).then((_) {
      if (viewModel.aiCase != null) {
        _loadDashboardData(); // Refresh counts
      }
    });
  }

  // --- REPORT TAB ---
  Widget _buildRapportTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique des Diagnostics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Visualisez les comptes-rendus et expertises ORL.'),
          const SizedBox(height: 16),
          Expanded(
            child: _cases.isEmpty
                ? const Center(child: Text('Aucun diagnostic enregistré.'))
                : ListView.builder(
                    itemCount: _cases.length,
                    itemBuilder: (context, index) {
                      final c = _cases[index];
                      final summary = c.summary;
                      final isCompleted = c.status == 'AI_COMPLETED' || c.status == 'SPECIALIST_COMPLETED';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                            child: Icon(
                              isCompleted ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                              color: isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                          title: Text(
                            summary.likelyDiagnosis ?? 'Diagnostic en attente',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Statut: ${c.status}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (context) => Container(
                                padding: const EdgeInsets.all(24),
                                height: MediaQuery.of(context).size.height * 0.75,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Détails du Diagnostic',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Divider(height: 24),
                                      SummaryLine(label: 'Statut', value: c.status),
                                      SummaryLine(label: 'Diagnostic probable', value: summary.likelyDiagnosis ?? 'Non déterminé'),
                                      SummaryLine(label: 'Avis image', value: summary.imageOpinion ?? 'Non disponible'),
                                      SummaryLine(label: 'Avis symptômes', value: summary.ragOpinion ?? 'Non disponible'),
                                      SummaryLine(label: 'Confiance', value: summary.confidenceLabel),
                                      if (summary.warnings.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        const Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ...summary.warnings.map((w) => Text('- $w', style: const TextStyle(fontSize: 12))),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- PROFILE TAB ---
  Widget _buildProfileTab() {
    final user = widget.session.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.person, size: 48, color: Color(0xFF006D77)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              user?.fullName ?? 'Infirmier',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ProfileDetailRow(label: 'Rôle', value: user?.role ?? 'NURSE'),
                  const Divider(),
                  _ProfileDetailRow(label: 'Identifiant Patient Lié', value: user?.linkedPatientId ?? 'Aucun'),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: widget.session.logout,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Se Déconnecter'),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM BAR UI ---
  Widget _buildBottomNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC7F9CC),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomTabIcon(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            isActive: _currentTab == 0,
            onPressed: () => setState(() {
              _currentTab = 0;
              _isSprintActive = false;
            }),
          ),
          _BottomTabIcon(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            isActive: _currentTab == 1,
            onPressed: () => setState(() {
              _currentTab = 1;
              _isSprintActive = false;
            }),
          ),
          _BottomTabIcon(
            icon: Icons.add_circle_outline_rounded,
            activeIcon: Icons.add_circle_rounded,
            isActive: _currentTab == 2,
            onPressed: () => setState(() {
              _currentTab = 2;
            }),
          ),
          _BottomTabIcon(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            isActive: _currentTab == 3,
            onPressed: () => setState(() {
              _currentTab = 3;
              _isSprintActive = false;
            }),
          ),
          _BottomTabIcon(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            isActive: _currentTab == 4,
            onPressed: () => setState(() {
              _currentTab = 4;
              _isSprintActive = false;
            }),
          ),
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF006D77),
        backgroundColor: Colors.white.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class _BottomTabIcon extends StatelessWidget {
  const _BottomTabIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        isActive ? activeIcon : icon,
        color: const Color(0xFF006D77),
        size: isActive ? 28 : 24,
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SprintProgress extends StatefulWidget {
  const SprintProgress({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onTap,
  });

  final List<String> steps;
  final int currentStep;
  final ValueChanged<int> onTap;

  @override
  State<SprintProgress> createState() => _SprintProgressState();
}

class _SprintProgressState extends State<SprintProgress> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveStep());
  }

  @override
  void didUpdateWidget(covariant SprintProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _scrollToActiveStep();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveStep() {
    if (!_scrollController.hasClients) return;

    // Estimate item width plus padding/spacing
    const double itemWidth = 140.0;
    final screenWidth = MediaQuery.of(context).size.width;

    // Target scroll offset to center active index
    final targetOffset = (widget.currentStep * itemWidth) + 16.0 - (screenWidth / 2) + (itemWidth / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (widget.currentStep + 1) / widget.steps.length,
                minHeight: 6,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 16),
                for (var index = 0; index < widget.steps.length; index++) ...[
                  GestureDetector(
                    onTap: () => widget.onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: index == widget.currentStep
                            ? colorScheme.primary
                            : index < widget.currentStep
                                ? colorScheme.primary.withOpacity(0.08)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: index == widget.currentStep
                              ? colorScheme.primary
                              : colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: index == widget.currentStep
                                ? Colors.white
                                : index < widget.currentStep
                                    ? colorScheme.primary
                                    : colorScheme.outline.withOpacity(0.5),
                            child: index < widget.currentStep
                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: index == widget.currentStep ? colorScheme.primary : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.steps[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: index == widget.currentStep ? FontWeight.bold : FontWeight.normal,
                              color: index == widget.currentStep
                                  ? Colors.white
                                  : index < widget.currentStep
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < widget.steps.length - 1) const SizedBox(width: 8),
                ],
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SprintCard extends StatelessWidget {
  const SprintCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const Divider(height: 24, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }
}

class ClinicalSelectionStep extends StatelessWidget {
  const ClinicalSelectionStep({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.emptyText,
    required this.onChanged,
  });

  final List<dynamic> items;
  final Set<String> selectedIds;
  final String emptyText;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: items.map((item) {
        final isSelected = selectedIds.contains(item.id);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              item.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: item.description == null ? null : Text(item.description!),
            value: isSelected,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) => onChanged(item.id, value ?? false),
          ),
        );
      }).toList(),
    );
  }
}

class PatientInfoStep extends StatelessWidget {
  const PatientInfoStep({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.addressController,
    required this.ageController,
    required this.sex,
    required this.onSexChanged,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController ageController;
  final String sex;
  final ValueChanged<String> onSexChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      hintText: 'ex: Diallo',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prénom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      hintText: 'ex: Aïssatou',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Téléphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'ex: +221 77 ...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Adresse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: addressController,
          decoration: InputDecoration(
            hintText: 'ex: Sacré-Cœur 3, Dakar',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Âge (ans)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'ex: 28',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sexe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                      selectedForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    segments: const [
                      ButtonSegment(value: 'M', label: Text('M')),
                      ButtonSegment(value: 'F', label: Text('F')),
                      ButtonSegment(value: 'OTHER', label: Text('Autre')),
                    ],
                    selected: {sex},
                    onSelectionChanged: (value) => onSexChanged(value.first),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ImageStep extends StatelessWidget {
  const ImageStep({
    super.key,
    required this.hasImage,
    required this.onCamera,
    required this.onGallery,
  });

  final bool hasImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: hasImage ? colorScheme.primary.withOpacity(0.04) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage ? colorScheme.primary : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                hasImage ? Icons.check_circle : Icons.camera_alt_outlined,
                size: 64,
                color: hasImage ? colorScheme.primary : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                hasImage ? 'Image ORL ajoutée avec succès !' : 'Aucune photo ajoutée',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasImage ? colorScheme.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasImage ? 'Vous pouvez capturer une nouvelle photo si besoin.' : 'Prenez une photo claire avec votre otoscope mobile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onCamera,
          icon: const Icon(Icons.camera),
          label: const Text('Prendre une photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choisir dans la galerie'),
        ),
      ],
    );
  }
}

class RecapStep extends StatelessWidget {
  const RecapStep({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address,
    required this.age,
    required this.sex,
    required this.notesController,
    required this.selectedSymptoms,
    required this.selectedHistories,
    required this.selectedTouchChecks,
    required this.hasImage,
    required this.requestSpecialistReview,
    required this.onReviewChanged,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String address;
  final String age;
  final String sex;
  final TextEditingController notesController;
  final List<String> selectedSymptoms;
  final List<String> selectedHistories;
  final List<String> selectedTouchChecks;
  final bool hasImage;
  final bool requestSpecialistReview;
  final ValueChanged<bool> onReviewChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummaryLine(label: 'Patient', value: '$firstName $lastName'.trim()),
        SummaryLine(label: 'Âge', value: age.isEmpty ? 'Non renseigné' : '$age ans'),
        SummaryLine(label: 'Sexe', value: sex == 'M' ? 'Masculin' : sex == 'F' ? 'Féminin' : 'Autre'),
        SummaryLine(label: 'Téléphone', value: phone.isEmpty ? 'Non renseigné' : phone),
        SummaryLine(label: 'Adresse', value: address.isEmpty ? 'Non renseignée' : address),
        const Divider(height: 20),
        SummaryLine(
          label: 'Symptômes',
          value: selectedSymptoms.isEmpty ? 'Aucun sélectionné' : selectedSymptoms.join(', '),
        ),
        SummaryLine(
          label: 'Antécédents',
          value: selectedHistories.isEmpty ? 'Aucun sélectionné' : selectedHistories.join(', '),
        ),
        SummaryLine(
          label: 'Toucher',
          value: selectedTouchChecks.isEmpty ? 'Aucun sélectionné' : selectedTouchChecks.join(', '),
        ),
        SummaryLine(
          label: 'Image ORL',
          value: hasImage ? 'Photo prête' : 'Manquante',
          valueColor: hasImage ? Colors.green : Colors.red,
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('Demander un avis spécialiste', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Soumettre le diagnostic pour validation experte.', style: TextStyle(fontSize: 11)),
          value: requestSpecialistReview,
          onChanged: onReviewChanged,
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(height: 24),
        const Text(
          'Notes ou commentaires complémentaires',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: notesController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Saisissez vos observations cliniques libres ici...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class SprintNavigationBar extends StatelessWidget {
  const SprintNavigationBar({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
  });

  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isFirst || isBusy ? null : onPrevious,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Précédent'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy ? null : onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isLast ? Icons.send : Icons.arrow_forward),
                label: Text(isLast ? 'Valider et Analyser' : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.aiCase});

  final dynamic aiCase;

  @override
  Widget build(BuildContext context) {
    final summary = aiCase.summary;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Synthèse de l\'Analyse IA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            SummaryLine(label: 'Diagnostic probable', value: summary.likelyDiagnosis ?? 'Non déterminé'),
            SummaryLine(label: 'Avis image', value: summary.imageOpinion ?? 'Non disponible'),
            SummaryLine(label: 'Avis symptômes', value: summary.ragOpinion ?? 'Non disponible'),
            SummaryLine(
              label: 'Niveau de confiance',
              value: summary.confidenceLabel,
              valueColor: summary.confidenceLabel == 'HIGH'
                  ? Colors.green
                  : summary.confidenceLabel == 'MEDIUM'
                      ? Colors.orange
                      : Colors.red,
            ),
            if (summary.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Alertes & Conseils', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              ...summary.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SummaryLine extends StatelessWidget {
  const SummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
