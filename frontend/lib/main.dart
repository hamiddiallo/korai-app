import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api/api_client.dart';
import 'core/auth/session_controller.dart';
import 'core/notifications/notification_cubit.dart';
import 'core/notifications/notification_repository.dart';
import 'core/sync/sync_cubit.dart';
import 'core/sync/sync_service.dart';
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
  late final ApiClient apiClient;
  late final AuthCubit session;
  late final SyncCubit syncCubit;
  late final NotificationCubit notificationCubit;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    session = AuthCubit(apiClient: apiClient);
    syncCubit = SyncCubit(syncService: SyncService(apiClient: apiClient));
    notificationCubit = NotificationCubit(
      repository: NotificationRepository(apiClient),
    );
    _authSubscription = session.stream.listen(_handleAuthState);
    session.restore();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    syncCubit.close();
    notificationCubit.close();
    session.close();
    super.dispose();
  }

  void _handleAuthState(AuthState state) {
    if (state.isAuthenticated && !state.isRestoring) {
      syncCubit.start();
      notificationCubit.start();
    } else if (!state.isAuthenticated && !state.isRestoring) {
      syncCubit.stop();
      notificationCubit.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: session),
        BlocProvider<SyncCubit>.value(value: syncCubit),
        BlocProvider<NotificationCubit>.value(value: notificationCubit),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        bloc: session,
        builder: (context, authState) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Korai ORL',
            theme: AppTheme.light(),
            scrollBehavior: MyCustomScrollBehavior(),
            home: authState.isRestoring
                ? const SessionLoadingPage()
                : authState.isAuthenticated
                    ? _homeForRole(authState.user)
                    : LoginPage(session: session),
          );
        },
      ),
    );
  }

  Widget _homeForRole(SessionUser? user) {
    switch (user?.role.trim().toUpperCase()) {
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

  final AuthCubit session;

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

class SessionLoadingPage extends StatelessWidget {
  const SessionLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
