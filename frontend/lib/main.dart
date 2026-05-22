import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/auth/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_home_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/nurse/presentation/nurse_home_page.dart';
import 'features/patient/presentation/patient_home_page.dart';
import 'features/specialist/presentation/specialist_home_page.dart';

void main() {
  runApp(const KoraiApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class KoraiApp extends StatefulWidget {
  const KoraiApp({super.key});

  @override
  State<KoraiApp> createState() => _KoraiAppState();
}

class _KoraiAppState extends State<KoraiApp> {
  late final SessionController session;

  @override
  void initState() {
    super.initState();
    session = SessionController(apiClient: ApiClient());
    session.restore();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Korai ORL',
          theme: AppTheme.light(),
          scrollBehavior: MyCustomScrollBehavior(),
          home: session.isAuthenticated ? _homeForRole() : LoginPage(session: session),
        );
      },
    );
  }

  Widget _homeForRole() {
    switch (session.user?.role.trim().toUpperCase()) {
      case 'ADMIN':
        return AdminHomePage(session: session);
      case 'NURSE':
      case 'PROFESSIONAL':
        return NurseHomePage(session: session);
      case 'PATIENT':
        return PatientHomePage(session: session);
      case 'SPECIALIST':
        return SpecialistHomePage(session: session);
      default:
        return RoleNotReadyPage(session: session);
    }
  }
}

class RoleNotReadyPage extends StatelessWidget {
  const RoleNotReadyPage({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final role = session.user?.role ?? 'INCONNU';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Korai ORL'),
        actions: [
          IconButton(
            tooltip: 'Deconnexion',
            onPressed: session.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Espace $role en preparation',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce profil est connecte, mais son interface mobile dediee sera ajoutee dans une prochaine etape.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
