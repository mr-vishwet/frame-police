/// Frame Police app shell + routing.
///
/// One route per screen (30 routes); each route adapts to mobile or web
/// layout (see `core/responsive.dart`), covering all 60 screens of the
/// V7 inventory. First launch shows Welcome (guest-first); returning
/// users land on Home.
library;

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/account_screen.dart';
import 'screens/autofix_screen.dart';
import 'screens/ci_runs_screen.dart';
import 'screens/ci_setup_screen.dart';
import 'screens/connected_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/data_controls_screen.dart';
import 'screens/defect_detail_screen.dart';
import 'screens/export_screen.dart';
import 'screens/guest_mode_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inspect_entry_screen.dart';
import 'screens/inspecting_screen.dart';
import 'screens/migrate_screen.dart';
import 'screens/payoff_screen.dart';
import 'screens/pr_comment_screen.dart';
import 'screens/pre_inspection_screen.dart';
import 'screens/registry_screen.dart';
import 'screens/report_screen.dart';
import 'screens/report_waived_screen.dart';
import 'screens/rule_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/suggestions_screen.dart';
import 'screens/upgrade_prompt_screen.dart';
import 'screens/verify_screen.dart';
import 'screens/waiver_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_controller.dart';
import 'widgets/logo.dart';

/// Named routes — one per screen in the V7 inventory.
class AppRoutes {
  static const home = '/home';
  static const inspect = '/inspect';
  static const preInspection = '/pre-inspection';
  static const inspecting = '/inspecting';
  static const report = '/report';
  static const defect = '/defect';
  static const autofix = '/autofix';
  static const suggestions = '/suggestions';
  static const waiver = '/waiver';
  static const reportWaived = '/report-waived';
  static const registry = '/registry';
  static const rule = '/rule';
  static const history = '/history';
  static const ci = '/ci';
  static const pr = '/pr';
  static const ciSetup = '/ci-setup';
  static const export = '/export';
  static const settings = '/settings';
  static const payoff = '/payoff';
  static const welcome = '/welcome';
  static const guest = '/guest';
  static const signIn = '/sign-in';
  static const createAccount = '/create-account';
  static const verify = '/verify';
  static const upgrade = '/upgrade';
  static const migrate = '/migrate';
  static const account = '/account';
  static const connected = '/connected';
  static const data = '/data';
}

class FramePoliceApp extends StatefulWidget {
  const FramePoliceApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<FramePoliceApp> createState() => _FramePoliceAppState();
}

class _FramePoliceAppState extends State<FramePoliceApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: widget.controller,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (!widget.controller.initialized) {
            return MaterialApp(
              title: 'Frame Police',
              theme: AppTheme.data,
              home: const _SplashScreen(),
            );
          }
          return MaterialApp(
            title: 'Frame Police',
            theme: AppTheme.data,
            initialRoute: widget.controller.onboarded
                ? AppRoutes.home
                : AppRoutes.welcome,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder == null) {
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: settings,
      );
    }
    return MaterialPageRoute(
      builder: (_) => builder(),
      settings: settings,
    );
  }

  static const Map<String, Widget Function()> _routes = {
    AppRoutes.home: HomeScreen.new,
    AppRoutes.inspect: InspectEntryScreen.new,
    AppRoutes.preInspection: PreInspectionScreen.new,
    AppRoutes.inspecting: InspectingScreen.new,
    AppRoutes.report: ReportScreen.new,
    AppRoutes.defect: DefectDetailScreen.new,
    AppRoutes.autofix: AutofixScreen.new,
    AppRoutes.suggestions: SuggestionsScreen.new,
    AppRoutes.waiver: WaiverScreen.new,
    AppRoutes.reportWaived: ReportWaivedScreen.new,
    AppRoutes.registry: RegistryScreen.new,
    AppRoutes.rule: RuleDetailScreen.new,
    AppRoutes.history: HistoryScreen.new,
    AppRoutes.ci: CiRunsScreen.new,
    AppRoutes.pr: PrCommentScreen.new,
    AppRoutes.ciSetup: CiSetupScreen.new,
    AppRoutes.export: ExportScreen.new,
    AppRoutes.settings: SettingsScreen.new,
    AppRoutes.payoff: PayoffScreen.new,
    AppRoutes.welcome: WelcomeScreen.new,
    AppRoutes.guest: GuestModeScreen.new,
    AppRoutes.signIn: SignInScreen.new,
    AppRoutes.createAccount: CreateAccountScreen.new,
    AppRoutes.verify: VerifyScreen.new,
    AppRoutes.upgrade: UpgradePromptScreen.new,
    AppRoutes.migrate: MigrateScreen.new,
    AppRoutes.account: AccountScreen.new,
    AppRoutes.connected: ConnectedScreen.new,
    AppRoutes.data: DataControlsScreen.new,
  };
}

/// Splash shown while the store loads (local JSON — fast).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FpBadge(size: 80),
            const SizedBox(height: 16),
            Text(
              'FRAME POLICE',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
