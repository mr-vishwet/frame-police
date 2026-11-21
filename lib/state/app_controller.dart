/// App state: the single [ChangeNotifier] every screen reads.
///
/// Owns exports, reports, rules, settings, account, CI runs, and the
/// inspection runner. All state persists to [LocalStore] on change; the
/// session token lives in [SecureSession]. Seeded demo data is loaded
/// on first launch only.
///
/// Screens read state via `AppScope.of(context)` and call the methods
/// below — there are no dead buttons on core flows: every action either
/// mutates real state or navigates to the screen that does.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../engine/demo_data.dart';
import '../engine/exit_codes.dart';
import '../engine/inspector.dart';
import '../engine/models.dart';
import '../engine/registry.dart';
import '../services/file_picker_service.dart';
import '../services/report_export.dart';
import '../services/secure_session.dart';
import '../services/store.dart';

/// Phase of the inspection runner.
enum InspectionPhase {
  /// No inspection running.
  idle,

  /// An inspection is running.
  running,

  /// The inspection finished.
  done,

  /// The inspection failed.
  error,
}

/// Per-probe state shown on the Inspecting screen.
enum ProbeState {
  /// Waiting to run.
  queued,

  /// Running now.
  running,

  /// Passed.
  pass,

  /// Found a defect.
  defect,

  /// Found a suggestion.
  suggestion,
}

/// One probe row in the live inspection list.
class ProbeProgress {
  /// Creates a [ProbeProgress].
  const ProbeProgress({
    required this.ruleCode,
    required this.label,
    required this.state,
    this.detail = '',
  });

  /// The rule code.
  final String ruleCode;
  /// The label.
  final String label;
  /// The state.
  final ProbeState state;
  /// The detail.
  final String detail;

  /// Returns a copy of this with the given fields replaced.
  ProbeProgress copyWith({ProbeState? state, String? detail}) =>
      ProbeProgress(
        ruleCode: ruleCode,
        label: label,
        state: state ?? this.state,
        detail: detail ?? this.detail,
      );
}

/// Counts shown on the migration screen (computed from the real store).
class MigrationSummary {
  /// Creates a [MigrationSummary].
  const MigrationSummary({
    required this.reports,
    required this.rules,
    required this.waivers,
    required this.defectsCaught,
  });

  /// The reports.
  final int reports;
  /// The rules.
  final int rules;
  /// The waivers.
  final int waivers;
  /// The defects caught.
  final int defectsCaught;

  /// The total.
  int get total => reports + rules + waivers;
}

/// App controller.
class AppController extends ChangeNotifier {
  /// Creates an [AppController].
  AppController({
    LocalStore? store,
    SecureSession? session,
    FilePickerService? picker,
    ReportExportService? exporter,
  })  : _store = store ?? LocalStore(),
        _session = session ?? SecureSession(),
        _picker = picker ?? FilePickerService(),
        _exporter = exporter ?? ReportExportService();

  final LocalStore _store;
  final SecureSession _session;
  final FilePickerService _picker;
  final ReportExportService _exporter;

  bool _initialized = false;
  /// Whether initialization has finished.
  bool get initialized => _initialized;

  // -- core state -------------------------------------------------------

  /// The exports.
  List<ExportFile> exports = [];
  /// The selected export.
  ExportFile? selectedExport;
  /// The reports.
  List<Report> reports = [];
  /// The current report.
  Report? currentReport;
  /// The rules.
  List<Rule> rules = [];
  /// The settings.
  AppSettings settings = const AppSettings();
  /// The account.
  Account? account;
  Account? _pendingAccount;
  /// The ci runs.
  List<CiRun> ciRuns = [];
  /// The ci totals.
  List<int> ciTotals = const [
    DemoFixture.ciTotalRuns,
    DemoFixture.ciFailedRuns,
    DemoFixture.ciCleanRuns,
  ];
  /// Whether the user has finished onboarding.
  bool onboarded = false;
  /// The defects caught.
  int defectsCaught = DemoFixture.defectsCaught;
  /// The zero defect exports.
  int zeroDefectExports = DemoFixture.zeroDefectExports;

  // -- inspection runner state ------------------------------------------

  /// The inspection phase.
  InspectionPhase inspectionPhase = InspectionPhase.idle;
  /// The inspection progress.
  double inspectionProgress = 0;
  /// The probe progress.
  List<ProbeProgress> probeProgress = [];
  /// The frames probed.
  int framesProbed = 0;
  /// The inspection error.
  String? inspectionError;
  bool _cancelRequested = false;

  /// Whether the current user is a guest.
  bool get isGuest => account == null;
  /// Whether this is signed in.
  bool get isSignedIn => account != null;

  /// Scores of the last 5 reports, oldest first, for the history chart.
  List<int> get recentScores {
    final recent = reports.take(5).toList().reversed;
    return recent.map((r) => r.score).toList();
  }

  /// The waivers count.
  int get waiversCount => reports.fold(
        0,
        (sum, r) => sum + r.waivedDefects.length,
      );

  /// The migration summary.
  MigrationSummary get migrationSummary => MigrationSummary(
        reports: reports.length,
        rules: rules.length,
        waivers: waiversCount,
        defectsCaught: defectsCaught,
      );

  /// Finds the report with the given id.
  Report? reportById(String id) {
    for (final report in reports) {
      if (report.id == id) return report;
    }
    return null;
  }

  /// Finds the export with the given id.
  ExportFile? exportById(String id) {
    for (final export in exports) {
      if (export.id == id) return export;
    }
    return null;
  }

  /// Finds the rule with the given code.
  Rule? ruleByCode(String code) => findRule(rules, code);

  /// Finds the CI run with the given id.
  CiRun? ciRunById(String id) {
    for (final run in ciRuns) {
      if (run.id == id) return run;
    }
    return null;
  }

  // -- init / seeding ---------------------------------------------------

  /// Loads persisted state, seeding demo data on first launch.
  ///
  /// Never throws: on any storage or seeding failure the app falls back
  /// to in-memory demo state and still marks itself initialized. The
  /// whole UI is gated on [initialized] (see `app.dart`), so a
  /// persistence failure — e.g. web storage unavailable or a stored
  /// value that no longer decodes — must never strand the app on the
  /// splash screen.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final seeded = await _store.isSeeded();
      onboarded = await _store.isOnboarded();
      settings = await _store.loadSettings() ?? const AppSettings();
      account = await _store.loadAccount();
      if (!seeded) {
        exports = demoExports();
        reports = demoHistoryReports();
        rules = defaultRules();
        ciRuns = demoCiRuns();
        ciTotals = const [
          DemoFixture.ciTotalRuns,
          DemoFixture.ciFailedRuns,
          DemoFixture.ciCleanRuns,
        ];
        defectsCaught = DemoFixture.defectsCaught;
        zeroDefectExports = DemoFixture.zeroDefectExports;
        await _persistAll();
        await _store.setSeeded(true);
      } else {
        exports = await _store.loadExports() ?? demoExports();
        reports = await _store.loadReports() ?? [];
        rules = await _store.loadRules() ?? defaultRules();
        ciRuns = await _store.loadCiRuns() ?? demoCiRuns();
        ciTotals = await _store.loadCiTotals() ??
            const [
              DemoFixture.ciTotalRuns,
              DemoFixture.ciFailedRuns,
              DemoFixture.ciCleanRuns,
            ];
        final counters = await _store.loadCounters();
        defectsCaught = counters[0];
        zeroDefectExports = counters[1];
      }
    } on Object catch (_) {
      // Storage unavailable or stored data unreadable: run with
      // in-memory demo state so the app can still start.
      if (exports.isEmpty) exports = demoExports();
      if (reports.isEmpty) reports = demoHistoryReports();
      if (rules.isEmpty) rules = defaultRules();
      if (ciRuns.isEmpty) ciRuns = demoCiRuns();
    } finally {
      selectedExport = exports.isNotEmpty ? exports.first : null;
      currentReport = reports.isNotEmpty ? reports.first : null;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistAll() async {
    await _store.saveExports(exports);
    await _store.saveReports(reports);
    await _store.saveRules(rules);
    await _store.saveSettings(settings);
    await _store.saveAccount(account);
    await _store.saveCiRuns(ciRuns);
    await _store.saveCiTotals(ciTotals);
    await _store.saveCounters([defectsCaught, zeroDefectExports]);
  }

  // -- exports ----------------------------------------------------------

  /// Selects the export.
  void selectExport(ExportFile export) {
    selectedExport = export;
    notifyListeners();
  }

  /// Picks a file via the system picker and adds it to the export list.
  /// Returns null when the user cancels.
  Future<ExportFile?> pickExportFile() async {
    final picked = await _picker.pickExport();
    if (picked == null) return null;
    exports = [picked, ...exports];
    selectedExport = picked;
    await _store.saveExports(exports);
    notifyListeners();
    return picked;
  }

  // -- inspection -------------------------------------------------------

  /// Runs the inspection of [file] with live probe progression.
  /// [previousReport] carries waivers / fixed findings forward on
  /// re-inspection. Returns the new report, or null when cancelled.
  Future<Report?> runInspection(
    ExportFile file, {
    Report? previousReport,
  }) async {
    _cancelRequested = false;
    inspectionPhase = InspectionPhase.running;
    inspectionProgress = 0;
    framesProbed = 0;
    inspectionError = null;
    final activeRules = rules.where((r) {
      if (!r.enabled) return false;
      if (r.kind == FindingKind.suggestion && !settings.suggestionsEnabled) {
        return false;
      }
      return true;
    }).toList();
    probeProgress = activeRules
        .map((r) => ProbeProgress(
              ruleCode: r.code,
              label: r.name,
              state: ProbeState.queued,
            ))
        .toList();
    notifyListeners();

    try {
      for (var i = 0; i < activeRules.length; i++) {
        if (_cancelRequested) {
          inspectionPhase = InspectionPhase.idle;
          notifyListeners();
          return null;
        }
        probeProgress[i] =
            probeProgress[i].copyWith(state: ProbeState.running);
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 260));
        if (_cancelRequested) {
          inspectionPhase = InspectionPhase.idle;
          notifyListeners();
          return null;
        }
        final rule = activeRules[i];
        final finding = Inspector.evaluateRule(rule, file);
        final state = finding == null
            ? ProbeState.pass
            : finding.isDefect
                ? ProbeState.defect
                : ProbeState.suggestion;
        probeProgress[i] = probeProgress[i].copyWith(
          state: state,
          detail: finding == null
              ? 'Pass'
              : finding.isDefect
                  ? 'Defect — ${finding.measuredLabel}'
                  : 'Suggestion',
        );
        inspectionProgress = (i + 1) / activeRules.length;
        framesProbed =
            (file.frameCount * inspectionProgress).round();
        notifyListeners();
      }
    } on Object catch (e) {
      inspectionPhase = InspectionPhase.error;
      inspectionError = e.toString();
      notifyListeners();
      return null;
    }

    final report = Inspector.inspect(
      file: file,
      rules: rules,
      registryVersion: settings.pinnedRegistry,
      suggestionsEnabled: settings.suggestionsEnabled,
      previousReport: previousReport,
    );
    reports = [report, ...reports];
    currentReport = report;
    defectsCaught += report.defects.length;
    if (report.isClean) zeroDefectExports += 1;

    // A re-inspection that turns exit 1 into exit 0 unblocks the PR:
    // append the passing CI run (the payoff run).
    if (previousReport != null &&
        previousReport.exitCode == kExitDefects &&
        report.exitCode == kExitClean) {
      _appendCiRun(report, previousReport);
    }

    inspectionPhase = InspectionPhase.done;
    inspectionProgress = 1;
    framesProbed = file.frameCount;
    await _persistAll();
    notifyListeners();
    return report;
  }

  /// Cancels the inspection.
  void cancelInspection() {
    _cancelRequested = true;
  }

  void _appendCiRun(Report report, Report previousReport) {
    final nextNumber = ciTotals[0] + 1;
    final isTeaser = report.exportId == 'exp_teaser_v3';
    final run = CiRun(
      id: 'ci_$nextNumber',
      number: nextNumber,
      prNumber: isTeaser
          ? DemoFixture.demoPrNumber
          : (ciRuns.isEmpty
              ? DemoFixture.demoPrNumber + 1
              : ciRuns.first.prNumber + 1),
      prTitle: isTeaser
          ? 'Launch teaser v3 — final cut'
          : '${report.exportName} — re-inspected',
      exportName: report.exportName,
      exitCode: kExitClean,
      registryVersion: settings.pinnedRegistry,
      createdAt: DateTime.now(),
    );
    ciRuns = [run, ...ciRuns];
    ciTotals = [ciTotals[0] + 1, ciTotals[1], ciTotals[2] + 1];
  }

  /// Builds the working copy for a re-inspection: the export with the
  /// report's fixed findings applied to its probe data / metadata.
  /// The working copy replaces the stored export; the original file is
  /// untouched (v0.1 fixes operate on probe data, not media bytes).
  ExportFile prepareReinspection(Report report) {
    final export = exportById(report.exportId);
    if (export == null) {
      throw StateError('Export ${report.exportId} not found');
    }
    final workingCopy =
        Inspector.applyFixesToExport(export, report.fixedAwaiting);
    exports = exports
        .map((e) => e.id == export.id ? workingCopy : e)
        .toList();
    selectedExport = workingCopy;
    notifyListeners();
    return workingCopy;
  }

  /// Re-inspects the export behind [report] after fixes were applied:
  /// the working copy carries the fixed probe values, and the previous
  /// report carries waivers forward.
  Future<Report?> reinspect(Report report) async {
    final workingCopy = prepareReinspection(report);
    return runInspection(workingCopy, previousReport: report);
  }

  // -- fixes / waivers --------------------------------------------------

  /// Applies the auto-fix for one finding. The exit code stays 1 until
  /// re-inspection confirms it.
  Future<Report?> applyFix(String reportId, String findingId) async {
    final report = reportById(reportId);
    if (report == null) return null;
    final updated = _updateFindings(
      report,
      (f) => f.id == findingId && f.status == FindingStatus.open
          ? f.copyWith(status: FindingStatus.fixed)
          : f,
    );
    return _saveUpdatedReport(updated);
  }

  /// Applies every available auto-fix in one tap.
  Future<Report?> applyAllFixes(String reportId) async {
    final report = reportById(reportId);
    if (report == null) return null;
    final updated = _updateFindings(
      report,
      (f) => f.isDefect &&
              f.status == FindingStatus.open &&
              f.fix != null
          ? f.copyWith(status: FindingStatus.fixed)
          : f,
    );
    return _saveUpdatedReport(updated);
  }

  /// Waives a defect with a reason. The reason stays in the report;
  /// waiving never deletes the finding.
  Future<Report?> waiveFinding(
    String reportId,
    String findingId, {
    required String reason,
    required String tag,
  }) async {
    if (reason.trim().length < kMinWaiverChars) return null;
    final report = reportById(reportId);
    if (report == null) return null;
    final waiver = Waiver(
      reason: reason.trim(),
      tag: tag,
      createdAt: DateTime.now(),
      waivedBy: account?.name ?? 'Guest',
    );
    final updated = _updateFindings(
      report,
      (f) => f.id == findingId
          ? f.copyWith(status: FindingStatus.waived, waiver: waiver)
          : f,
    );
    return _saveUpdatedReport(updated);
  }

  Report _updateFindings(
    Report report,
    Finding Function(Finding) update,
  ) {
    final findings = report.findings.map(update).toList();
    final updated = report.copyWith(
      findings: findings,
      score: Inspector.scoreFor(findings),
      exitCode: exitCodeForFindings(findings),
    );
    return updated.copyWith(
      fingerprint: Inspector.fingerprintFor(updated),
    );
  }

  Future<Report> _saveUpdatedReport(Report updated) async {
    reports = reports
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    if (currentReport?.id == updated.id) currentReport = updated;
    await _store.saveReports(reports);
    notifyListeners();
    return updated;
  }

  // -- rules ------------------------------------------------------------

  /// Edits a rule's limit — creates a new rule version, never rewrites
  /// history. Old reports keep pointing at the version that ran them.
  Future<void> updateRuleLimit({
    required String code,
    required double newValue,
    required String newLabel,
    required String note,
  }) async {
    rules = rules.map((r) {
      if (r.code != code) return r;
      return r.withNewLimit(
        newValue: newValue,
        newLabel: newLabel,
        note: note,
      );
    }).toList();
    await _store.saveRules(rules);
    notifyListeners();
  }

  /// Toggles the rule.
  Future<void> toggleRule(String code, bool enabled) async {
    rules = rules
        .map((r) => r.code == code ? r.copyWith(enabled: enabled) : r)
        .toList();
    await _store.saveRules(rules);
    notifyListeners();
  }

  /// Resets all rules to registry defaults.
  Future<void> resetRules() async {
    rules = defaultRules();
    await _store.saveRules(rules);
    notifyListeners();
  }

  // -- settings ---------------------------------------------------------

  /// Updates the settings.
  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _store.saveSettings(settings);
    notifyListeners();
  }

  // -- auth (local-only in v0.1 — no backend) ---------------------------

  /// Continues as a guest.
  Future<void> continueAsGuest() async {
    onboarded = true;
    await _store.setOnboarded(true);
    notifyListeners();
  }

  /// Starts sign-in: validates the form and holds the account pending
  /// verification. Returns an error message, or null on success.
  String? startSignIn({required String email, required String password}) {
    final error = _validateCredentials(email: email, password: password);
    if (error != null) return error;
    final name = _nameFromEmail(email);
    _pendingAccount = Account(
      name: name,
      email: email,
      plan: 'Free',
      createdAt: DateTime.now(),
      verified: false,
    );
    notifyListeners();
    return null;
  }

  /// Starts account creation. Returns an error message, or null.
  String? startCreateAccount({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty) return 'Enter your name.';
    final error = _validateCredentials(email: email, password: password);
    if (error != null) return error;
    _pendingAccount = Account(
      name: name.trim(),
      email: email,
      plan: 'Free',
      createdAt: DateTime.now(),
      verified: false,
    );
    notifyListeners();
    return null;
  }

  /// The pending account.
  Account? get pendingAccount => _pendingAccount;

  static String? _validateCredentials({
    required String email,
    required String password,
  }) {
    if (!email.contains('@') || email.trim().length < 5) {
      return 'Enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password needs at least 8 characters.';
    }
    return null;
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
    if (cleaned.isEmpty) return 'Inspector';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Verifies the pending account. v0.1 accepts any 6-digit code —
  /// there is no email backend yet; the verify screen says so.
  /// Returns an error message, or null on success.
  Future<String?> verifyCode(String code) async {
    if (_pendingAccount == null) return 'No sign-in in progress.';
    if (code.length != 6 || int.tryParse(code) == null) {
      return 'Enter the 6-digit code.';
    }
    final verified = Account(
      name: _pendingAccount!.name,
      email: _pendingAccount!.email,
      plan: _pendingAccount!.plan,
      createdAt: _pendingAccount!.createdAt,
      verified: true,
    );
    account = verified;
    _pendingAccount = null;
    onboarded = true;
    await _session.createSession(verified.email);
    await _store.saveAccount(account);
    await _store.setOnboarded(true);
    notifyListeners();
    return null;
  }

  /// Signs out of this device. Local reports stay on the device —
  /// signing out never deletes them.
  Future<void> signOut() async {
    account = null;
    await _session.clearSession();
    await _store.saveAccount(null);
    notifyListeners();
  }

  /// Deletes the account and its synced copies. Local reports stay
  /// until deleted separately — deleting never deletes local reports.
  Future<void> deleteAccount() async {
    account = null;
    _pendingAccount = null;
    await _session.clearSession();
    await _store.clearAll(deleteReports: false);
    notifyListeners();
  }

  // -- CI ---------------------------------------------------------------

  /// Sets whether CI is connected.
  Future<void> setCiConnected(bool connected) async {
    await updateSettings(settings.copyWith(ciConnected: connected));
  }

  // -- exports ----------------------------------------------------------

  /// The exporter.
  ReportExportService get exporter => _exporter;
}

/// Provides the [AppController] to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  /// Creates an [AppScope].
  const AppScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  /// Returns the [AppController] above this context.
  static AppController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Reads the controller without subscribing to updates.
  static AppController read(BuildContext context) {
    final scope =
        context.getElementForInheritedWidgetOfExactType<AppScope>()?.widget
            as AppScope?;
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
