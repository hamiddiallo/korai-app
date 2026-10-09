import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/api/api_client.dart';
import 'core/auth/app_lock.dart';
import 'core/auth/app_lock_settings.dart';
import 'core/auth/biometric_service.dart';
import 'core/auth/lock_screen.dart';
import 'core/auth/session_controller.dart';
import 'core/design/design.dart';
import 'core/notifications/notification_cubit.dart';
import 'core/notifications/notification_repository.dart';
import 'core/refresh/live_refresh.dart';
import 'core/storage/local_data_conflict_page.dart';
import 'core/storage/local_data_guard.dart';
import 'core/sync/sync_cubit.dart';
import 'core/sync/sync_service.dart';
import 'features/admin/presentation/admin_home_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/nurse/presentation/nurse_home_page.dart';
import 'features/patient/presentation/patient_home_page.dart';
import 'features/specialist/presentation/specialist_home_page.dart';
import 'core/widgets/otoscopy_photo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Charge le `.env` (URL backend, etc.). Absent ? On retombe sur
  // --dart-define ou l'heuristique plateforme (cf. ApiConfig.baseUrl).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // `.env` introuvable : configuration assuree par les valeurs par defaut.
  }
  _registerFontLicenses();
  runApp(const KoraiApp());
}

/// Licences OFL des polices embarquées (visibles dans la page des licences).
void _registerFontLicenses() {
  const fonts = {
    'Sora': 'assets/fonts/OFL-Sora.txt',
    'Atkinson Hyperlegible Next': 'assets/fonts/OFL-AtkinsonHyperlegibleNext.txt',
    'Atkinson Hyperlegible Mono': 'assets/fonts/OFL-AtkinsonHyperlegibleMono.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in fonts.entries) {
      yield LicenseEntryWithLineBreaks([entry.key], await rootBundle.loadString(entry.value));
    }
  });
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
  late final ProtectedImageLoader photoLoader = ProtectedImageLoader.api(apiClient);
  late final NotificationCubit notificationCubit;
  late final AppLockCubit appLock;

  /// Relecture automatique des écrans (premier plan, notifications, relève).
  final live = LiveRefresh();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<AppLockState>? _lockSubscription;
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Application hors premier plan : contenu masqué (sélecteur d'apps).
  bool _obscured = false;
  bool _wasAuthenticated = false;
  bool _restoreDone = false;

  /// Données hors-ligne de ce téléphone : `null` tant que la vérification du
  /// propriétaire n'est pas terminée pour le compte connecté.
  LocalDataClaim? _localData;
  String? _claimedUserId;

  /// Connexion par mot de passe : proposer le verrouillage une fois l'accès
  /// aux données locales accordé (jamais par-dessus l'écran de conflit).
  bool _offerLockWhenReady = false;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    session = AuthCubit(apiClient: apiClient);
    syncCubit = SyncCubit(syncService: SyncService(apiClient: apiClient));
    notificationCubit = NotificationCubit(
      repository: NotificationRepository(apiClient),
      // Une notification annonce un changement (dossier pris, avis rendu,
      // compte validé) : les écrans concernés se relisent sans attendre.
      onNewNotifications: (fresh) => live.changed(LiveTopic.fromNotifications(fresh)),
    );
    live.listen(reload: notificationCubit.refresh, pollEvery: const Duration(seconds: 30));
    appLock = AppLockCubit()..load();
    _lockSubscription = appLock.stream.listen((lock) {
      // Clavier fermé quand l'écran de verrouillage apparaît.
      if (lock.locked) FocusManager.instance.primaryFocus?.unfocus();
    });
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _authSubscription = session.stream.listen(_handleAuthState);
    session.restore();
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    final obscured = lifecycle != AppLifecycleState.resumed;
    if (obscured != _obscured) setState(() => _obscured = obscured);
    switch (lifecycle) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        appLock.onBackgrounded();
        live.paused();
      case AppLifecycleState.resumed:
        appLock.onForegrounded();
        live.resumed();
      default:
        break;
    }
  }

  /// Après une connexion par mot de passe : proposer le verrouillage.
  Future<void> _offerAppLock() async {
    final lock = appLock.state;
    if (lock.enabled || !lock.method.available) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final overlayContext = _navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null || !overlayContext.mounted || !session.state.isAuthenticated) return;
    showAppLockOffer(overlayContext);
  }

  /// Vérifie que les données locales appartiennent au compte connecté avant
  /// d'afficher son espace et de lancer la synchronisation.
  Future<void> _claimLocalData(SessionUser user) async {
    setState(() => _localData = null);
    LocalDataClaim claim;
    try {
      claim = await LocalDataGuard.instance.claim(userId: user.id, userName: user.fullName);
    } catch (error) {
      if (kDebugMode) debugPrint('Vérification des données locales impossible : $error');
      claim = const LocalDataReady(); // base locale indisponible : aucune donnée à protéger
    }
    if (!mounted || _claimedUserId != user.id) return;
    setState(() => _localData = claim);
    if (claim is LocalDataReady) _onLocalDataReady();
  }

  Future<void> _discardOtherAccountData(SessionUser user) async {
    await LocalDataGuard.instance.discardAndClaim(userId: user.id, userName: user.fullName);
    if (!mounted) return;
    setState(() => _localData = const LocalDataReady(clearedPreviousOwner: true));
    _onLocalDataReady();
  }

  void _onLocalDataReady() {
    syncCubit.start();
    notificationCubit.start();
    live.start();
    if (_offerLockWhenReady) {
      _offerLockWhenReady = false;
      _offerAppLock();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    live.dispose();
    _lockSubscription?.cancel();
    appLock.close();
    _authSubscription?.cancel();
    syncCubit.close();
    notificationCubit.close();
    session.close();
    super.dispose();
  }

  void _handleAuthState(AuthState state) {
    if (state.isAuthenticated && !state.isRestoring) {
      final user = state.user!;
      // Une seule vérification par session (l'état est réémis à chaque mise à jour du profil).
      if (_claimedUserId != user.id) {
        _claimedUserId = user.id;
        _claimLocalData(user);
      }
    } else if (!state.isAuthenticated && !state.isRestoring) {
      syncCubit.stop();
      notificationCubit.stop();
      live.stop();
      _claimedUserId = null;
      _localData = null;
      _offerLockWhenReady = false;
      // Déconnexion ou session expirée : ferme les pages et feuilles ouvertes
      // par-dessus l'accueil, sinon elles resteraient au-dessus de la connexion.
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    if (state.isRestoring) return;
    final loggedIn = state.isAuthenticated && !_wasAuthenticated;
    final loggedOut = !state.isAuthenticated && _wasAuthenticated;
    // Connexion par mot de passe (pas une session restaurée au lancement).
    // Le verrouillage est proposé une fois l'espace affiché, jamais par-dessus
    // l'écran « Données d'un autre compte ».
    if (loggedIn && _restoreDone) {
      if (_localData is LocalDataReady) {
        _offerAppLock();
      } else {
        _offerLockWhenReady = true;
      }
    }
    if (loggedOut) {
      appLock.reset();
      // Les photos vues restent en mémoire le temps de la session seulement.
      photoLoader.clear();
    }
    _wasAuthenticated = state.isAuthenticated;
    _restoreDone = true;
  }

  @override
  Widget build(BuildContext context) {
    return LiveRefreshScope(
      live: live,
      child: MultiBlocProvider(
        providers: [
          RepositoryProvider<ProtectedImageLoader>.value(value: photoLoader),
          BlocProvider<AuthCubit>.value(value: session),
          BlocProvider<SyncCubit>.value(value: syncCubit),
          BlocProvider<NotificationCubit>.value(value: notificationCubit),
          BlocProvider<AppLockCubit>.value(value: appLock),
        ],
        child: BlocBuilder<AuthCubit, AuthState>(
          bloc: session,
          builder: (context, authState) => BlocBuilder<AppLockCubit, AppLockState>(
            bloc: appLock,
            buildWhen: (a, b) => a.ready != b.ready || a.locked != b.locked,
            builder: (context, lock) {
              final showLock = authState.isAuthenticated && lock.locked;
              return MaterialApp(
                navigatorKey: _navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'Korai ORL',
                theme: KoraiTheme.light(),
                darkTheme: KoraiTheme.dark(),
                themeMode: ThemeMode.system,
                scrollBehavior: MyCustomScrollBehavior(),
                // Réglages du verrou lus avant d'afficher un espace : aucun
                // dossier n'apparaît, même un instant, sur un appareil verrouillé.
                home: _home(authState, lock),
                builder: (context, child) => Stack(
                  children: [
                    ExcludeSemantics(
                      excluding: showLock,
                      child: IgnorePointer(ignoring: showLock, child: child ?? const SizedBox.shrink()),
                    ),
                    if (showLock)
                      Positioned.fill(
                        child: LockScreen(
                          userName: authState.user?.fullName ?? '',
                          onUsePassword: session.logout,
                        ),
                      ),
                    if (authState.isAuthenticated && _obscured && !showLock)
                      const Positioned.fill(child: PrivacyCover()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _home(AuthState authState, AppLockState lock) {
    if (authState.isRestoring) return const KoraiSplash();
    if (!authState.isAuthenticated) return LoginPage(session: session);
    final localData = _localData;
    if (!lock.ready || localData == null) return const KoraiSplash();
    if (localData is LocalDataConflict) {
      return LocalDataConflictPage(
        ownerName: localData.ownerName,
        unsentCount: localData.unsentCount,
        onLogout: session.logout,
        onDiscard: () => _discardOtherAccountData(authState.user!),
      );
    }
    return _homeForRole(authState.user);
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
    return Scaffold(
      body: SafeArea(
        child: KEmptyView(
          icon: Icons.lock_clock_outlined,
          title: 'Espace non disponible',
          message: 'Votre compte (${KLabels.role(session.user?.role)}) est connecté, '
              'mais aucun espace ne lui est encore associé dans l’application. '
              'Contactez l’administrateur.',
          actionLabel: 'Se déconnecter',
          onAction: session.logout,
        ),
      ),
    );
  }
}
