/// Seeded demo data — REMOVED.
///
/// This file used to seed four demo exports, five history reports, and
/// eight CI runs on first launch. The real-data conversion deleted the
/// seeds: first launch now starts empty ("pick your file" onboarding)
/// and every export, report, and CI run in the app is real state.
///
/// The function signatures are kept, returning empty lists. The file is
/// dead — nothing calls these — and is kept only because the GitHub
/// connector cannot delete files; delete it via the web UI.
library;

import 'models.dart';

/// No seeded exports: the library starts empty.
List<ExportFile> demoExports() => const [];

/// No seeded history: the first inspection creates the first report.
List<Report> demoHistoryReports() => const [];

/// No seeded CI runs: runs only appear from real inspections.
List<CiRun> demoCiRuns() => const [];
