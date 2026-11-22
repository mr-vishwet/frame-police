/// App state: the single [ChangeNotifier] every screen reads.
///
/// Owns exports, reports, rules, settings, account, CI runs, and the
/// inspection runner. All state persists to [LocalStore] on change; the
/// session token lives in [SecureSession]. First launch loads the real
/// demo media through the real Tier A probe (web) or starts empty
/// (where the probe cannot run).
///
/// Screens read state via `AppScope.of(context)` and call the methods
/// below — there are no dead buttons on core flows: every action either
/// mutates real state or navigates to the screen that does.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../engine/exit_codes.dart';
import '../engine/inspector.dart';
import '../engine/models.dart';
import '../engine/registry.dart';
import '../services/demo_media_loader.dart';
import '../services/file_picker_service.dart';
import '../services/file_system_access.dart';
import '../services/media_probe.dart';
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

  /// Not measured by this probe — the rule was skipped, not passed.
  skipped,
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
  List<int> ciTotals = const [0, 0, 0];
  /// Whether the user has finished onboarding.
  bool onboarded = false;
  /// The defects caught.
  int defectsCaught = 0;
  /// The zero defect exports.
  int zeroDefectExports = 0;

  /// The last file-picker error, if picking failed (null on cancel).
  String? pickerError;

  // -- inspection runner state ------------------------------------------

  /// The inspection phase.
  InspectionPhase inspectionPhase = InspectionPhase.idle;
  /// The inspection progress.
  double inspectionProgress = 0;
  /// The live probe stage ("Probing video…", "Evaluating rules…").
  /// Empty when no inspection is running.
  String inspectionStage = '';
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

  /// Number of demo exports currently in the library (Data controls
  /// shows "Clear demo data" only when this is non-zero).
  int get demoExportCount => exports.where((e) => e.isDemo).length;

  // -- init / seeding ---------------------------------------------------

  /// Loads persisted state, loading the real demo media on first launch.
  ///
  /// Never throws: on any storage or seeding failure the app falls back
  /// to in-memory empty state and still marks itself initialized. The
  /// whole UI is gated on [initialized] (see `app.dart`), so a
  /// persistence failure — e.g. web storage unavailable or a stored
  /// value that no longer decodes — must never strand the app on the
  /// splash screen.
  ///
  /// Migration (real-data conversion): a stored library from before the
  /// conversion still carries the old seeded demo exports (ids
  /// `exp_teaser_v3`, `exp_demo_v2`, `exp_founder_cut4`,
  /// `exp_known_bad`). Those exports and their reports are dropped, all
  /// stored CI runs are dropped (no real CI integration exists, so all
  /// are fake), and the lifetime counters are RECOMPUTED from the kept
  /// reports — recompute, not reset to zero, so real history survives.
  /// User-picked exports are kept with their demo-probe flag intact
  /// (re-pick to measure for real). The migration runs once: it is
  /// keyed on the old seed ids, so the new demo media (ids starting
  /// `demo_`) never triggers it.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final seeded = await _store.isSeeded();
      onboarded = await _store.isOnboarded();
      settings = await _store.loadSettings() ?? const AppSettings();
      account = await _store.loadAccount();
      rules = await _store.loadRules() ?? defaultRules();
      if (!seeded) {
        exports = await _loadFirstRunExports();
        reports = [];
        ciRuns = [];
        ciTotals = const [0, 0, 0];
        defectsCaught = 0;
        zeroDefectExports = 0;
        await _persistAll();
        await _store.setSeeded(true);
      } else {
        final storedExports = await _store.loadExports() ?? [];
        final storedReports = await _store.loadReports() ?? [];
        if (_isPreConversion(storedExports)) {
          final keptExports =
              storedExports.where((e) => !e.isDemo).toList();
          final keptIds = keptExports.map((e) => e.id).toSet();
          final keptReports = storedReports
              .where((r) => keptIds.contains(r.exportId))
              .toList();
          exports = keptExports;
          reports = keptReports;
          ciRuns = [];
          ciTotals = const [0, 0, 0];
          defectsCaught =
              keptReports.fold(0, (sum, r) => sum + r.defects.length);
          zeroDefectExports =
              keptReports.where((r) => r.isClean).length;
          await _persistAll();
        } else {
          exports = storedExports;
          reports = storedReports;
          ciRuns = await _store.loadCiRuns() ?? [];
          ciTotals = await _store.loadCiTotals() ?? const [0, 0, 0];
          final counters = await _store.loadCounters();
          defectsCaught = counters[0];
          zeroDefectExports = counters[1];
        }
      }
    } on Object catch (_) {
      // Storage unavailable or stored data unreadable: run with
      // in-memory empty state so the app can still start.
      if (rules.isEmpty) rules = defaultRules();
    } finally {
      selectedExport = exports.isNotEmpty ? exports.first : null;
      currentReport = reports.isNotEmpty ? reports.first : null;
      _initialized = true;
      notifyListeners();
    }
  }

  /// The old seeded demo export ids, dropped by the migration. The new
  /// demo media uses ids starting `demo_` and never matches.
  static const _preConversionDemoIds = {
    'exp_teaser_v3',
    'exp_demo_v2',
    'exp_founder_cut4',
    'exp_known_bad',
  };

  static bool _isPreConversion(List<ExportFile> storedExports) =>
      storedExports.any((e) => _preConversionDemoIds.contains(e.id));

  /// First-run exports: the real demo media, probed through the real
  /// Tier A probe — on web. Where the probe cannot run (non-web, or a
  /// probe failure), the library starts empty and the user picks a
  /// file. Never throws.
  Future<List<ExportFile>> _loadFirstRunExports() async {
    if (!MediaProbe.isSupported) return [];
    try {
      return await DemoMediaLoader(picker: _picker).load();
    } on Object catch (_) {
      return [];
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
  /// Returns null when the user cancels — or when the picker itself
  /// fails, in which case [pickerError] holds the failure (the picker
  /// can throw, e.g. when the browser blocks the dialog on web, and a
  /// bare null would leave the tap silently dead).
  Future<ExportFile?> pickExportFile() async {
    pickerError = null;
    ExportFile? picked;
    try {
      picked = await _picker.pickExport();
    } on Object catch (e) {
      pickerError = e.toString();
      notifyListeners();
      return null;
    }
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
  ///
  /// Two stages, both real. Stage 1 probes FIRST when the export has
  /// never been probed and its bytes are in this session's cache: the
  /// Tier A probe measures the media with live progress callbacks
  /// ("Probing video…") and the probed export is persisted. When the
  /// bytes are gone (a stored export from an earlier session), the run
  /// fails honestly with "pick the file again" instead of inventing
  /// measurements. Stage 2 evaluates the rules fast, with NO artificial
  /// delays — the per-rule rows update as each rule evaluates (a zero
  /// yield per rule lets the UI paint). Cancel aborts the probe
  /// between stages via the [shouldCancel] callback. The inspection
  /// duration is measured with a [Stopwatch] and recorded in the
  /// report — the old hardcoded 19 s is gone.
  Future<Report?> runInspection(
    ExportFile file, {
    Report? previousReport,
  }) async {
    _cancelRequested = false;
    inspectionPhase = InspectionPhase.running;
    inspectionProgress = 0;
    inspectionStage = 'Probing video…';
    framesProbed = 0;
    inspectionError = null;
    final stopwatch = Stopwatch()..start();
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

    // Stage 1: probe the media (first inspection only — an
    // already-probed export re-evaluates its stored measurements).
    var inspected = file;
    if (needsProbe(file)) {
      final bytes = _picker.bytesFor(file.id) ??
          await _reloadBytesFromHandle(file);
      if (bytes == null) {
        inspectionPhase = InspectionPhase.error;
        inspectionStage = '';
        inspectionError =
            'This export was picked in an earlier session and its file '
            'is no longer in memory. Pick the file again to measure it.';
        notifyListeners();
        return null;
      }
      try {
        final result = await MediaProbe.probeVideo(
          bytes,
          mimeType: MediaProbe.mimeTypeFor(file.name),
          onProgress: (stage, progress) {
            inspectionStage = stage;
            // The probe is the slow part: it owns the first 80%.
            inspectionProgress = progress * 0.8;
            notifyListeners();
          },
          shouldCancel: () => _cancelRequested,
        );
        inspected = file.copyWith(
          durationSeconds: result.durationSeconds,
          frameCount: result.frameCount,
          width: result.width,
          height: result.height,
          fps: result.fps,
          probe: result.probe,
          frameThumbnailBase64: result.frameThumbnailBase64,
          waveformPeaks: result.waveformPeaks,
        );
        exports =
            exports.map((e) => e.id == file.id ? inspected : e).toList();
        if (selectedExport?.id == file.id) selectedExport = inspected;
        framesProbed = result.framesSampled;
        await _store.saveExports(exports);
      } on ProbeCancelledException {
        inspectionPhase = InspectionPhase.idle;
        inspectionStage = '';
        inspectionProgress = 0;
        notifyListeners();
        return null;
      } on ProbeException catch (e) {
        inspectionPhase = InspectionPhase.error;
        inspectionStage = '';
        inspectionError = e.message;
        notifyListeners();
        return null;
      } on Object catch (e) {
        inspectionPhase = InspectionPhase.error;
        inspectionStage = '';
        inspectionError = e.toString();
        notifyListeners();
        return null;
      }
    }
    if (_cancelRequested) {
      inspectionPhase = InspectionPhase.idle;
      inspectionStage = '';
      inspectionProgress = 0;
      notifyListeners();
      return null;
    }

    // Stage 2: evaluate the rules fast — no artificial delays.
    inspectionStage = 'Evaluating rules…';
    notifyListeners();
    try {
      for (var i = 0; i < activeRules.length; i++) {
        if (_cancelRequested) {
          inspectionPhase = InspectionPhase.idle;
          inspectionStage = '';
          notifyListeners();
          return null;
        }
        final rule = activeRules[i];
        if (inspected.probe.unmeasured.contains(rule.code)) {
          // Not measured by this probe: skipped, not passed — the
          // report records it in skippedRules.
          probeProgress[i] = probeProgress[i].copyWith(
            state: ProbeState.skipped,
            detail: 'Not measured in this inspection',
          );
        } else {
          probeProgress[i] =
              probeProgress[i].copyWith(state: ProbeState.running);
          notifyListeners();
          final finding = Inspector.evaluateRule(rule, inspected);
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
        }
        inspectionProgress = 0.8 + 0.2 * (i + 1) / activeRules.length;
        // A zero yield lets the UI paint each row's state. This is not
        // an artificial delay — the rules evaluate in microseconds.
        await Future<void>.delayed(Duration.zero);
        notifyListeners();
      }
    } on Object catch (e) {
      inspectionPhase = InspectionPhase.error;
      inspectionStage = '';
      inspectionError = e.toString();
      notifyListeners();
      return null;
    }

    final report = Inspector.inspect(
      file: inspected,
      rules: rules,
      registryVersion: settings.pinnedRegistry,
      suggestionsEnabled: settings.suggestionsEnabled,
      previousReport: previousReport,
      durationSeconds: stopwatch.elapsed.inSeconds,
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
    inspectionStage = '';
    inspectionProgress = 1;
    framesProbed = inspected.frameCount;
    await _persistAll();
    notifyListeners();
    return report;
  }

  /// Re-reads an export's bytes from its persisted File System Access
  /// handle (Chromium only), for re-inspection after a restart, when
  /// the session bytes cache is gone. Returns null when there is no
  /// handle, the handle is gone, or permission is denied — the caller
  /// then asks the user to pick the file again. Never throws.
  Future<Uint8List?> _reloadBytesFromHandle(ExportFile file) async {
    final key = file.fsaHandleKey;
    if (key == null) return null;
    try {
      final bytes = await FileSystemAccess.readPersistedFile(key);
      if (bytes != null) _picker.cacheBytes(file.id, bytes);
      return bytes;
    } on Object catch (_) {
      return null;
    }
  }

  /// Cancels the inspection.
  void cancelInspection() {
    _cancelRequested = true;
  }

  void _appendCiRun(Report report, Report previousReport) {
    final nextNumber = ciTotals[0] + 1;
    // Local record only (no CI integration yet): the run number is a
    // local sequence starting at 1, not a GitHub PR number.
    final prNumber = ciRuns.isEmpty
        ? 1
        : ciRuns.map((r) => r.prNumber).reduce((a, b) => a > b ? a : b) + 1;
    final run = CiRun(
      id: 'ci_$nextNumber',
      number: nextNumber,
      prNumber: prNumber,
      prTitle: '${report.exportName} — re-inspected',
      exportName: report.exportName,
      exitCode: kExitClean,
      registryVersion: settings.pinnedRegistry,
      createdAt: DateTime.now(),
    );
    ciRuns = [run, ...ciRuns];
    ciTotals = [ciTotals[0] + 1, ciTotals[1], ciTotals[2] + 1];
  }

  /// Resolves the export behind [report] for a re-inspection. There is
  /// no working copy anymore: auto-fixes operated on probe data, not
  /// media, and were removed in the real-data conversion. Re-inspection
  /// re-evaluates the export's real measurements against the current
  /// rules (and re-probes from cached bytes when the export has never
  /// been probed). Throws [StateError] when the report's export is
  /// missing from the store.
  ExportFile prepareReinspection(Report report) {
    final export = exportById(report.exportId);
    if (export == null) {
      throw StateError('Export ${report.exportId} not found');
    }
    selectedExport = export;
    notifyListeners();
    return export;
  }

  /// Re-inspects the export behind [report]: fixes happen in the editor
  /// and arrive as a re-export, so this re-evaluates the export's
  /// measurements against the current rules, and the previous report
  /// carries waivers forward.
  Future<Report?> reinspect(Report report) async {
    final workingCopy = prepareReinspection(report);
    return runInspection(workingCopy, previousReport: report);
  }

  /// Removes demo exports and their reports (Data controls → Clear
  /// demo data). User-picked exports and their reports are untouched;
  /// cached demo bytes are dropped, and the lifetime counters are
  /// recomputed from the kept reports.
  Future<void> clearDemoData() async {
    final demoIds = exports.where((e) => e.isDemo).map((e) => e.id).toSet();
    if (demoIds.isEmpty) return;
    exports = exports.where((e) => !e.isDemo).toList();
    reports =
        reports.where((r) => !demoIds.contains(r.exportId)).toList();
    for (final id in demoIds) {
      _picker.dropBytes(id);
    }
    if (selectedExport != null && demoIds.contains(selectedExport!.id)) {
      selectedExport = exports.isNotEmpty ? exports.first : null;
    }
    if (currentReport != null &&
        demoIds.contains(currentReport!.exportId)) {
      currentReport = reports.isNotEmpty ? reports.first : null;
    }
    defectsCaught =
        reports.fold(0, (sum, r) => sum + r.defects.length);
    zeroDefectExports = reports.where((r) => r.isClean).length;
    await _store.saveExports(exports);
    await _store.saveReports(reports);
    await _store.saveCounters([defectsCaught, zeroDefectExports]);
    notifyListeners();
  }

  // -- waivers ----------------------------------------------------------

  // No applyFix/applyAllFixes anymore: fixes happen in the editor (see
  // the fix-guidance screen), and marking a finding "fixed" without
  // anything actually changing was dishonest. Findings stay open until
  // a re-export is re-inspected.

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
