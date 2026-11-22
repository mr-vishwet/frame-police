/// Failure-path tests: a throw from the picker, the store, the session,
/// or the exporter must surface as an on-screen error — never a stuck
/// spinner, a dead tap, or an unhandled async error.
///
/// These tests pin the fixes for the audit's error-handling findings:
/// the inspecting screen used to leave a re-inspection stuck at 0%
/// when the report's export was missing from the store, and every
/// busy-flag screen left its button stuck when its await threw.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/app.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/reporter.dart';
import 'package:frame_police/screens/autofix_screen.dart';
import 'package:frame_police/screens/data_controls_screen.dart';
import 'package:frame_police/screens/export_screen.dart';
import 'package:frame_police/screens/home_screen.dart';
import 'package:frame_police/screens/report_screen.dart';
import 'package:frame_police/screens/waiver_screen.dart';
import 'package:frame_police/services/file_picker_service.dart';
import 'package:frame_police/services/report_export.dart';
import 'package:frame_police/services/secure_session.dart';
import 'package:frame_police/services/store.dart';
import 'package:frame_police/state/app_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fixtures.dart';

class _ThrowingPicker extends FilePickerService {
  @override
  Future<ExportFile?> pickExport() async =>
      throw Exception('dialog blocked');
}

class _CancellingPicker extends FilePickerService {
  @override
  Future<ExportFile?> pickExport() async => null;
}

/// Storage that fails on write: reads still work (via the real
/// SharedPreferences mock), so init() falls back to in-memory empty
/// state and every later save throws.
class _ThrowingStore extends LocalStore {
  @override
  Future<void> saveExports(List<ExportFile> exports) async =>
      throw Exception('storage unavailable');

  @override
  Future<void> saveReports(List<Report> reports) async =>
      throw Exception('storage unavailable');
}

class _ThrowingExporter extends ReportExportService {
  @override
  Future<String?> saveReport(Report report, ReportFormat format) async =>
      throw Exception('download blocked');

  @override
  Future<String?> saveFullExport({
    required List<Report> reports,
    required List<Rule> rules,
    required List<CiRun> ciRuns,
    required List<ExportFile> exports,
  }) async =>
      throw Exception('download blocked');
}

class _ThrowingSession extends SecureSession {
  @override
  Future<String> createSession(String email) async =>
      throw Exception('keychain unavailable');
}

Future<AppController> _seededController({
  LocalStore? store,
  SecureSession? session,
  FilePickerService? picker,
  ReportExportService? exporter,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = AppController(
    store: store,
    session: session,
    picker: picker,
    exporter: exporter,
  );
  await controller.init();
  // Skip the welcome gate: these tests drive screens directly.
  controller.onboarded = true;
  // Hand-built export: the tests inspect this, not seeded demo state
  // (first launch starts empty).
  final export = twoDefectExport();
  controller.exports = [export];
  controller.selectedExport = export;
  return controller;
}

/// The two-defect report (hand-built export: 2 defects, score 82).
Report _twoDefectReport(AppController controller) {
  final export = controller.exports.firstWhere(
    (e) => e.id == 'exp_test_two_defect',
  );
  return Inspector.inspect(
    file: export,
    rules: controller.rules,
    registryVersion: kRegistryVersion,
    now: DateTime.utc(2026, 11, 21, 12),
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppController controller,
) async {
  // Desktop viewport: the wide layout (side rail + content) is designed
  // for desktop widths — the default 800x600 test surface overflows
  // home/report rows that fit at real desktop sizes.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FramePoliceApp(controller: controller));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _push(
  WidgetTester tester,
  String route, [
  Map<String, dynamic>? args,
]) async {
  final context = tester.element(find.byType(HomeScreen));
  Navigator.pushNamed(context, route, arguments: args);
  await tester.pump();
  // Let the 300 ms route transition finish: mid-transition the new
  // route is shifted right and taps land off-target.
  await tester.pump(const Duration(milliseconds: 400));
}

/// The error snackbar on [screen]: the messenger renders the snackbar
/// in every route's scaffold, so scope the finder to the screen under
/// test (the copy under a covered route is invisible).
Finder _snackOn(Type screen, String message) => find.descendant(
      of: find.byType(screen),
      matching: find.text(message),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickExportFile failure', () {
    test('picker throw returns null and records pickerError', () async {
      final controller =
          await _seededController(picker: _ThrowingPicker());
      final before = controller.exports.length;
      final picked = await controller.pickExportFile();
      expect(picked, isNull);
      expect(controller.pickerError, contains('dialog blocked'));
      expect(controller.exports.length, before);
    });

    test('cancel returns null with no pickerError', () async {
      final controller =
          await _seededController(picker: _CancellingPicker());
      final picked = await controller.pickExportFile();
      expect(picked, isNull);
      expect(controller.pickerError, isNull);
    });
  });

  group('inspecting screen failure', () {
    testWidgets(
      're-inspection of a report whose export is missing shows an error, '
      'not a stuck spinner',
      (tester) async {
        final controller = await _seededController();
        final orphan = Report(
          id: 'rep_orphan',
          exportId: 'exp_missing',
          exportName: 'Missing export.mp4',
          createdAt: DateTime.utc(2026, 11, 21, 12),
          registryVersion: kRegistryVersion,
          findings: const [],
          score: 100,
          exitCode: kExitClean,
          durationSeconds: 19,
          framesProbed: 0,
          fingerprint: '',
        );
        controller.reports = [orphan, ...controller.reports];
        await _pumpApp(tester, controller);
        await _push(tester, '/inspecting', {
          'exportId': 'exp_test_two_defect',
          'previousReportId': 'rep_orphan',
        });
        await tester.pump();
        await tester.pump();
        expect(find.text('Inspection could not run'), findsOneWidget);
        expect(find.textContaining('exp_missing'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets('a plain inspection still runs to the report',
        (tester) async {
      final controller = await _seededController();
      await _pumpApp(tester, controller);
      await _push(tester, '/inspecting', {'exportId': 'exp_test_two_defect'});
      // 14 rules x 260 ms per probe, plus persistence.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(controller.currentReport?.score, 82);
      expect(controller.currentReport?.exitCode, kExitDefects);
    });
  });

  group('busy-flag screens recover from a failed await', () {
    testWidgets('a failed report save shows an error and re-enables',
        (tester) async {
      final controller =
          await _seededController(exporter: _ThrowingExporter());
      final report = _twoDefectReport(controller);
      controller.reports = [report, ...controller.reports];
      controller.currentReport = report;
      await _pumpApp(tester, controller);
      await _push(tester, '/export', {'reportId': report.id});
      await tester.ensureVisible(find.textContaining('Export as'));
      await tester.tap(find.textContaining('Export as'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _snackOn(ExportScreen, 'Could not save the report. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Saving…'), findsNothing);
    });

    testWidgets('a failed waiver save shows an error and re-enables',
        (tester) async {
      final controller = await _seededController(store: _ThrowingStore());
      final report = _twoDefectReport(controller);
      controller.reports = [report, ...controller.reports];
      controller.currentReport = report;
      await _pumpApp(tester, controller);
      await _push(tester, '/waiver', {
        'reportId': report.id,
        'findingId': 'SUB-SAFE-01',
      });
      await tester.enterText(
        find.byType(TextField),
        'Client signed off on this subtitle placement.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Waive and record reason'));
      await tester.tap(find.text('Waive and record reason'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _snackOn(WaiverScreen, 'Could not record the waiver. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Recording…'), findsNothing);
    });

    testWidgets('a failed verification shows an error and re-enables',
        (tester) async {
      final controller =
          await _seededController(session: _ThrowingSession());
      expect(
        controller.startSignIn(
          email: 'ada@example.com',
          password: 'password123',
        ),
        isNull,
      );
      await _pumpApp(tester, controller);
      await _push(tester, '/verify');
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(find.text('Verify and continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Verification failed. Try again.'), findsOneWidget);
      expect(find.text('Verifying…'), findsNothing);
    });

    testWidgets('a failed full export shows an error and re-enables',
        (tester) async {
      final controller =
          await _seededController(exporter: _ThrowingExporter());
      await _pumpApp(tester, controller);
      await _push(tester, '/data');
      await tester.ensureVisible(find.text('Export'));
      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _snackOn(
          DataControlsScreen,
          'Could not export everything. Try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exporting…'), findsNothing);
    });

    testWidgets(
        'fix guidance opens without changing finding status',
        (tester) async {
      final controller = await _seededController(store: _ThrowingStore());
      final report = _twoDefectReport(controller);
      controller.reports = [report, ...controller.reports];
      controller.currentReport = report;
      await _pumpApp(tester, controller);
      await _push(tester, '/report', {'reportId': report.id});
      await tester.ensureVisible(find.text('How to fix all (2)'));
      await tester.tap(find.text('How to fix all (2)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Guidance only: the screen opens and no finding is marked fixed
      // (fixes happen in the editor; nothing here changes state, so a
      // throwing store cannot fail this tap either).
      expect(find.byType(AutofixScreen), findsOneWidget);
      final updated =
          controller.reports.firstWhere((r) => r.id == report.id);
      expect(
        updated.defects.map((f) => f.status),
        everyElement(FindingStatus.open),
      );
    });
  });
}
