/// Saving report exports and the full data export.
///
/// Uses `file_picker`'s save dialog on native platforms; on web the
/// same call triggers a browser download. The full data export bundles
/// reports, rules, and waivers into one .zip via `package:archive`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../engine/models.dart';
import '../engine/reporter.dart';

class ReportExportService {
  /// Saves [content] as [fileName] via the system save dialog (native)
  /// or a browser download (web). Returns the saved path, or null when
  /// the user cancels.
  Future<String?> saveText(String fileName, String content) async {
    final bytes = utf8.encode(content);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save report',
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// Saves a report in [format] with a sensible file name.
  Future<String?> saveReport(Report report, ReportFormat format) async {
    final safeName = report.exportName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName =
        'frame-police_${safeName}_exit${report.exitCode}.${format.fileExtension}';
    return saveText(fileName, Reporter.render(report, format));
  }

  /// Saves the workflow YAML (CI setup screen).
  Future<String?> saveWorkflowYaml() =>
      saveText('frame-police.yml', kCiWorkflowYaml);

  /// Bundles everything — reports, rules, CI runs — into one .zip and
  /// saves it (Data controls → Export everything).
  Future<String?> saveFullExport({
    required List<Report> reports,
    required List<Rule> rules,
    required List<CiRun> ciRuns,
    required List<ExportFile> exports,
  }) async {
    final archive = Archive();
    void addJson(String name, Object value) {
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(value),
      );
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson(
      'reports.json',
      reports.map((r) => r.toJson()).toList(),
    );
    addJson(
      'rules.json',
      rules.map((r) => r.toJson()).toList(),
    );
    addJson(
      'ci-runs.json',
      ciRuns.map((r) => r.toJson()).toList(),
    );
    addJson(
      'exports.json',
      exports.map((e) => e.toJson()).toList(),
    );
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return null;
    return FilePicker.platform.saveFile(
      dialogTitle: 'Export everything',
      fileName: 'frame-police-export.zip',
      bytes: Uint8List.fromList(zipBytes),
    );
  }
}
