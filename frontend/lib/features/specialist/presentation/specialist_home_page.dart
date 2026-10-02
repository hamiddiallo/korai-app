import 'package:flutter/material.dart';

import '../../../core/auth/profile_page.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/notifications/notification_models.dart';
import '../data/specialist_repository.dart';
import 'nurse_requests_page.dart';
import 'screens/specialist_queue_tab.dart';
import 'screens/specialist_review_page.dart';
import 'specialist_inbox.dart';

/// Onglets : 0 File, 1 Mes dossiers, 2 Inscriptions, 3 Profil.
const _queueTab = 0;

/// Espace du spécialiste : file d'avis, dossiers pris en charge, inscriptions
/// des soignants encadrés et profil.
class SpecialistHomePage extends StatefulWidget {
  const SpecialistHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<SpecialistHomePage> createState() => _SpecialistHomePageState();
}

class _SpecialistHomePageState extends State<SpecialistHomePage> {
  late final SpecialistRepository _repository;
  late final SpecialistInbox _inbox;
  int _tab = _queueTab;
  int _pendingRegistrations = 0;

  @override
  void initState() {
    super.initState();
    _repository = SpecialistRepository(widget.session.apiClient);
    _inbox = SpecialistInbox(_repository, currentUserId: widget.session.user?.id)..refresh();
  }

  @override
  void dispose() {
    _inbox.dispose();
    super.dispose();
  }

  Future<void> _open(ExpertiseInboxItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpecialistReviewPage(
          repository: _repository,
          item: item,
          currentUserId: widget.session.user?.id,
          onChanged: _inbox.refresh,
        ),
      ),
    );
    _inbox.refresh();
  }

  void _onNotificationTap(AppNotification n) {
    final id = n.consultationId;
    final item = id == null ? null : _inbox.items.where((i) => i.consultationId == id).firstOrNull;
    if (item != null) {
      _open(item);
    } else {
      setState(() => _tab = _queueTab);
      _inbox.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            SpecialistQueueTab(
              inbox: _inbox,
              userName: widget.session.user?.fullName ?? '',
              onOpen: _open,
              onNotificationTap: _onNotificationTap,
            ),
            SpecialistMineTab(
              inbox: _inbox,
              onOpen: _open,
              onGoToQueue: () => setState(() => _tab = _queueTab),
            ),
            NurseRequestsPage(
              apiClient: widget.session.apiClient,
              embedded: true,
              onPendingCountChanged: (n) {
                if (mounted && n != _pendingRegistrations) setState(() => _pendingRegistrations = n);
              },
            ),
            ProfilePage(session: widget.session, embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _inbox,
        builder: (context, _) => KPillNavBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: [
            KNavItem(
              icon: Icons.inbox_outlined,
              activeIcon: Icons.inbox_rounded,
              label: 'File',
              badge: _inbox.urgentCount,
            ),
            KNavItem(
              icon: Icons.assignment_ind_outlined,
              activeIcon: Icons.assignment_ind_rounded,
              label: 'Mes dossiers',
              badge: _inbox.mine.length,
            ),
            KNavItem(
              icon: Icons.group_add_outlined,
              activeIcon: Icons.group_add_rounded,
              label: 'Inscriptions',
              badge: _pendingRegistrations,
            ),
            const KNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
