/// Local-first persistence via `shared_preferences`.
///
/// All app state lives on-device as JSON: exports, reports, rules,
/// settings, account, CI runs, and the onboarding flag. No backend, no
/// upload. The session token is the one exception — it lives in secure
/// storage (see `secure_session.dart`).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/models.dart';

class LocalStore {
  static const _exportsKey = 'fp.exports.v1';
  static const _reportsKey = 'fp.reports.v1';
  static const _rulesKey = 'fp.rules.v1';
  static const _settingsKey = 'fp.settings.v1';
  static const _accountKey = 'fp.account.v1';
  static const _ciRunsKey = 'fp.ci_runs.v1';
  static const _ciTotalsKey = 'fp.ci_totals.v1';
  static const _onboardedKey = 'fp.onboarded.v1';
  static const _seededKey = 'fp.seeded.v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  // -- exports ----------------------------------------------------------

  Future<List<ExportFile>?> loadExports() async {
    final raw = (await _prefs()).getString(_exportsKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ExportFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveExports(List<ExportFile> exports) async {
    final raw = jsonEncode(exports.map((e) => e.toJson()).toList());
    await (await _prefs()).setString(_exportsKey, raw);
  }

  // -- reports ----------------------------------------------------------

  Future<List<Report>?> loadReports() async {
    final raw = (await _prefs()).getString(_reportsKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveReports(List<Report> reports) async {
    final raw = jsonEncode(reports.map((r) => r.toJson()).toList());
    await (await _prefs()).setString(_reportsKey, raw);
  }

  // -- rules ------------------------------------------------------------

  Future<List<Rule>?> loadRules() async {
    final raw = (await _prefs()).getString(_rulesKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Rule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRules(List<Rule> rules) async {
    final raw = jsonEncode(rules.map((r) => r.toJson()).toList());
    await (await _prefs()).setString(_rulesKey, raw);
  }

  // -- settings ---------------------------------------------------------

  Future<AppSettings?> loadSettings() async {
    final raw = (await _prefs()).getString(_settingsKey);
    if (raw == null) return null;
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await (await _prefs())
        .setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // -- account ----------------------------------------------------------

  Future<Account?> loadAccount() async {
    final raw = (await _prefs()).getString(_accountKey);
    if (raw == null) return null;
    return Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveAccount(Account? account) async {
    final prefs = await _prefs();
    if (account == null) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, jsonEncode(account.toJson()));
    }
  }

  // -- CI runs + totals -------------------------------------------------

  Future<List<CiRun>?> loadCiRuns() async {
    final raw = (await _prefs()).getString(_ciRunsKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CiRun.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCiRuns(List<CiRun> runs) async {
    final raw = jsonEncode(runs.map((r) => r.toJson()).toList());
    await (await _prefs()).setString(_ciRunsKey, raw);
  }

  /// CI totals as [total, failed, clean]. Seeded from the demo fixture.
  Future<List<int>?> loadCiTotals() async {
    final raw = (await _prefs()).getString(_ciTotalsKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e as int).toList();
  }

  Future<void> saveCiTotals(List<int> totals) async {
    await (await _prefs()).setString(_ciTotalsKey, jsonEncode(totals));
  }

  // -- lifetime counters ------------------------------------------------

  static const _countersKey = 'fp.counters.v1';

  /// Lifetime counters as [defectsCaught, zeroDefectExports].
  Future<List<int>> loadCounters() async {
    final raw = (await _prefs()).getString(_countersKey);
    if (raw == null) return const [47, 12];
    final list = jsonDecode(raw) as List<dynamic>;
    if (list.length < 2) return const [47, 12];
    return [list[0] as int, list[1] as int];
  }

  Future<void> saveCounters(List<int> counters) async {
    await (await _prefs()).setString(_countersKey, jsonEncode(counters));
  }

  // -- flags ------------------------------------------------------------

  Future<bool> isOnboarded() async =>
      (await _prefs()).getBool(_onboardedKey) ?? false;

  Future<void> setOnboarded(bool value) async =>
      (await _prefs()).setBool(_onboardedKey, value);

  Future<bool> isSeeded() async =>
      (await _prefs()).getBool(_seededKey) ?? false;

  Future<void> setSeeded(bool value) async =>
      (await _prefs()).setBool(_seededKey, value);

  /// Clears everything (delete-account path). Local reports are kept
  /// unless [deleteReports] is true — deleting the account never deletes
  /// local reports on its own.
  Future<void> clearAll({bool deleteReports = false}) async {
    final prefs = await _prefs();
    await prefs.remove(_accountKey);
    await prefs.remove(_onboardedKey);
    if (deleteReports) {
      await prefs.remove(_exportsKey);
      await prefs.remove(_reportsKey);
      await prefs.remove(_rulesKey);
      await prefs.remove(_settingsKey);
      await prefs.remove(_ciRunsKey);
      await prefs.remove(_ciTotalsKey);
      await prefs.remove(_countersKey);
      await prefs.remove(_seededKey);
    }
  }
}
