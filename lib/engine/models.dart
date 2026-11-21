/// Data models for Frame Police: exports, probe data, rules, findings,
/// waivers, reports, CI runs, account, and settings.
///
/// Everything here is plain Dart with `toJson` / `fromJson` so the whole
/// state persists to local storage as JSON (see `services/store.dart`).
/// No Flutter dependency — safe to use from tests and the reporter.
library;

import '../core/constants.dart';
import 'exit_codes.dart';

/// Whether a finding decides the exit code (defect) or advises
/// (suggestion). Separate universes: suggestions never affect the exit
/// code, the score, or anything CI reads.
enum FindingKind { defect, suggestion }

/// Lifecycle of a defect finding.
///
/// * [open] — found, undecided. Blocks the release (exit 1).
/// * [fixed] — auto-fix applied, awaiting re-inspection. STILL blocks
///   the release: a fix is not real until re-inspection confirms it.
/// * [confirmed] — re-inspection verified the fix. Does not block.
/// * [waived] — waived with a reason. The reason stays in the report;
///   does not block, never deletes the finding.
enum FindingStatus { open, fixed, confirmed, waived }

/// A creative export to inspect (a video file in v0.1).
///
/// The constructor is deliberately NOT const: the `declaredAspect`
/// default calls [_aspectOf], a static method invocation, which is not
/// a constant expression — a const constructor cannot have it in its
/// initializer list. No call site constructs an [ExportFile] in a
/// const context, so dropping `const` changes nothing else.
class ExportFile {
  ExportFile({
    required this.id,
    required this.name,
    required this.durationSeconds,
    required this.frameCount,
    required this.width,
    required this.height,
    required this.fps,
    required this.sizeBytes,
    required this.addedAt,
    required this.probe,
    this.isDemo = false,
    String? declaredAspect,
  }) : declaredAspect = declaredAspect ?? _aspectOf(width, height);

  factory ExportFile.fromJson(Map<String, dynamic> json) => ExportFile(
        id: json['id'] as String,
        name: json['name'] as String,
        durationSeconds: json['durationSeconds'] as int,
        frameCount: json['frameCount'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        fps: json['fps'] as int,
        sizeBytes: json['sizeBytes'] as int,
        addedAt: DateTime.parse(json['addedAt'] as String),
        probe: ProbeData.fromJson(json['probe'] as Map<String, dynamic>),
        isDemo: json['isDemo'] as bool? ?? false,
        declaredAspect: json['declaredAspect'] as String?,
      );

  final String id;
  final String name;
  final int durationSeconds;
  final int frameCount;
  final int width;
  final int height;
  final int fps;
  final int sizeBytes;
  final DateTime addedAt;

  /// The aspect ratio the project declares for this export (e.g. `9:16`
  /// for vertical, `16:9` for landscape). The aspect-ratio rule compares
  /// the actual aspect against this — not against a fixed ratio — so a
  /// landscape export is not a defect in a landscape project. Defaults
  /// to the export's own aspect when not given.
  final String declaredAspect;

  /// Measured probe data the rules evaluate against. Seeded exports
  /// carry measured values; user-picked files get a deterministic demo
  /// probe (see `Inspector.demoProbeFor`) — labelled DEMO in the UI
  /// until the native media probe lands in phase 2.
  final ProbeData probe;

  final bool isDemo;

  String get aspectLabel => _aspectOf(width, height);

  static String _aspectOf(int w, int h) {
    final gcd = _gcd(w, h);
    return '${w ~/ gcd}:${h ~/ gcd}';
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationSeconds': durationSeconds,
        'frameCount': frameCount,
        'width': width,
        'height': height,
        'fps': fps,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'declaredAspect': declaredAspect,
        'probe': probe.toJson(),
        'isDemo': isDemo,
      };
}

/// Measured values from the frame / audio / text probes.
///
/// The rule engine evaluates ONLY against this struct — never against
/// raw media — which is what makes inspections deterministic: same
/// probe data + same registry version = same report.
class ProbeData {
  const ProbeData({
    required this.subtitleBottomY,
    required this.subtitleTimecode,
    required this.peakDbfs,
    required this.peakTimecode,
    required this.longestSilenceSeconds,
    required this.blackFrameCount,
    required this.textOverflow,
    required this.brandLogoPresent,
    required this.brandColorsOk,
    required this.captionSyncOffsetMs,
    required this.titleBottomY,
    required this.loudnessLufs,
    required this.openingFrameDarkness,
    required this.captionsFileAttached,
    this.isDemoProbe = false,
  });

  factory ProbeData.fromJson(Map<String, dynamic> json) => ProbeData(
        subtitleBottomY: (json['subtitleBottomY'] as num).toDouble(),
        subtitleTimecode: json['subtitleTimecode'] as String,
        peakDbfs: (json['peakDbfs'] as num).toDouble(),
        peakTimecode: json['peakTimecode'] as String,
        longestSilenceSeconds:
            (json['longestSilenceSeconds'] as num).toDouble(),
        blackFrameCount: json['blackFrameCount'] as int,
        textOverflow: json['textOverflow'] as bool,
        brandLogoPresent: json['brandLogoPresent'] as bool,
        brandColorsOk: json['brandColorsOk'] as bool,
        captionSyncOffsetMs: (json['captionSyncOffsetMs'] as num).toDouble(),
        titleBottomY: (json['titleBottomY'] as num).toDouble(),
        loudnessLufs: (json['loudnessLufs'] as num).toDouble(),
        openingFrameDarkness: (json['openingFrameDarkness'] as num).toDouble(),
        captionsFileAttached: json['captionsFileAttached'] as bool,
        isDemoProbe: json['isDemoProbe'] as bool? ?? false,
      );

  /// Lowest subtitle bottom edge in px (frame height is the reference).
  final double subtitleBottomY;
  final String subtitleTimecode;

  /// Highest audio peak in dBFS, and where it sits.
  final double peakDbfs;
  final String peakTimecode;

  /// Longest stretch of dead air in seconds.
  final double longestSilenceSeconds;

  /// Frames that are entirely black.
  final int blackFrameCount;

  /// Whether any on-screen text overflows its frame.
  final bool textOverflow;

  /// Whether the brand mark appears in the export.
  final bool brandLogoPresent;

  /// Whether used colours stay inside the brand palette.
  final bool brandColorsOk;

  /// Caption sync offset in milliseconds (0 = in sync).
  final double captionSyncOffsetMs;

  /// Lowest title bottom edge in px.
  final double titleBottomY;

  /// Integrated loudness in LUFS.
  final double loudnessLufs;

  /// Fraction of the opening frame that is dark (0..1).
  final double openingFrameDarkness;

  /// Whether an .srt captions file sits alongside the export.
  final bool captionsFileAttached;

  /// True when the values are a deterministic demo probe rather than
  /// measured media. Labelled DEMO in the report.
  final bool isDemoProbe;

  ProbeData copyWith({
    double? subtitleBottomY,
    double? peakDbfs,
    double? longestSilenceSeconds,
    int? blackFrameCount,
    bool? textOverflow,
    bool? brandLogoPresent,
    bool? brandColorsOk,
    double? captionSyncOffsetMs,
    double? titleBottomY,
    double? loudnessLufs,
    double? openingFrameDarkness,
    bool? captionsFileAttached,
  }) =>
      ProbeData(
        subtitleBottomY: subtitleBottomY ?? this.subtitleBottomY,
        subtitleTimecode: subtitleTimecode,
        peakDbfs: peakDbfs ?? this.peakDbfs,
        peakTimecode: peakTimecode,
        longestSilenceSeconds:
            longestSilenceSeconds ?? this.longestSilenceSeconds,
        blackFrameCount: blackFrameCount ?? this.blackFrameCount,
        textOverflow: textOverflow ?? this.textOverflow,
        brandLogoPresent: brandLogoPresent ?? this.brandLogoPresent,
        brandColorsOk: brandColorsOk ?? this.brandColorsOk,
        captionSyncOffsetMs: captionSyncOffsetMs ?? this.captionSyncOffsetMs,
        titleBottomY: titleBottomY ?? this.titleBottomY,
        loudnessLufs: loudnessLufs ?? this.loudnessLufs,
        openingFrameDarkness: openingFrameDarkness ?? this.openingFrameDarkness,
        captionsFileAttached: captionsFileAttached ?? this.captionsFileAttached,
        isDemoProbe: isDemoProbe,
      );

  Map<String, dynamic> toJson() => {
        'subtitleBottomY': subtitleBottomY,
        'subtitleTimecode': subtitleTimecode,
        'peakDbfs': peakDbfs,
        'peakTimecode': peakTimecode,
        'longestSilenceSeconds': longestSilenceSeconds,
        'blackFrameCount': blackFrameCount,
        'textOverflow': textOverflow,
        'brandLogoPresent': brandLogoPresent,
        'brandColorsOk': brandColorsOk,
        'captionSyncOffsetMs': captionSyncOffsetMs,
        'titleBottomY': titleBottomY,
        'loudnessLufs': loudnessLufs,
        'openingFrameDarkness': openingFrameDarkness,
        'captionsFileAttached': captionsFileAttached,
        'isDemoProbe': isDemoProbe,
      };
}

/// One entry in a rule's version history. Editing a limit creates a new
/// version — history is never rewritten.
class RuleVersion {
  const RuleVersion({
    required this.version,
    required this.limitLabel,
    required this.note,
  });

  factory RuleVersion.fromJson(Map<String, dynamic> json) => RuleVersion(
        version: json['version'] as String,
        limitLabel: json['limitLabel'] as String,
        note: json['note'] as String,
      );

  final String version;
  final String limitLabel;
  final String note;

  Map<String, dynamic> toJson() => {
        'version': version,
        'limitLabel': limitLabel,
        'note': note,
      };
}

/// A versioned rule in the registry.
class Rule {
  const Rule({
    required this.code,
    required this.name,
    required this.description,
    required this.kind,
    required this.version,
    required this.limitLabel,
    required this.limitValue,
    required this.unit,
    required this.versions,
    this.enabled = true,
  });

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        kind: FindingKind.values.firstWhere(
          (k) => k.name == (json['kind'] as String),
        ),
        version: json['version'] as String,
        limitLabel: json['limitLabel'] as String,
        limitValue: (json['limitValue'] as num).toDouble(),
        unit: json['unit'] as String,
        versions: (json['versions'] as List<dynamic>)
            .map((v) => RuleVersion.fromJson(v as Map<String, dynamic>))
            .toList(),
        enabled: json['enabled'] as bool? ?? true,
      );

  final String code;
  final String name;
  final String description;
  final FindingKind kind;
  final String version;

  /// Human-readable limit, e.g. `90% margin` / `y ≤ 1,052 px`.
  final String limitLabel;

  /// Numeric limit the engine compares against (units in [unit]).
  final double limitValue;
  final String unit;
  final List<RuleVersion> versions;
  final bool enabled;

  bool get isDefect => kind == FindingKind.defect;

  /// Returns a copy with a new limit, versioned: the old version moves
  /// into [versions] and the rule's version bumps (v1.2 → v1.3).
  Rule withNewLimit({
    required double newValue,
    required String newLabel,
    required String note,
  }) {
    final parts = version.split('.');
    final major = int.parse(parts[0].substring(1));
    final minor = int.parse(parts[1]) + 1;
    final newVersion = 'v$major.$minor';
    return Rule(
      code: code,
      name: name,
      description: description,
      kind: kind,
      version: newVersion,
      limitLabel: newLabel,
      limitValue: newValue,
      unit: unit,
      versions: [
        RuleVersion(
          version: version,
          limitLabel: limitLabel,
          note: note,
        ),
        ...versions,
      ],
      enabled: enabled,
    );
  }

  Rule copyWith({bool? enabled}) => Rule(
        code: code,
        name: name,
        description: description,
        kind: kind,
        version: version,
        limitLabel: limitLabel,
        limitValue: limitValue,
        unit: unit,
        versions: versions,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'description': description,
        'kind': kind.name,
        'version': version,
        'limitLabel': limitLabel,
        'limitValue': limitValue,
        'unit': unit,
        'versions': versions.map((v) => v.toJson()).toList(),
        'enabled': enabled,
      };
}

/// A one-tap auto-fix for a defect finding.
class AutoFix {
  const AutoFix({
    required this.label,
    required this.detail,
    required this.afterLabel,
  });

  factory AutoFix.fromJson(Map<String, dynamic> json) => AutoFix(
        label: json['label'] as String,
        detail: json['detail'] as String,
        afterLabel: json['afterLabel'] as String,
      );

  final String label;
  final String detail;

  /// What the measured value becomes after the fix, e.g. `y = 1,040 px`.
  final String afterLabel;

  Map<String, dynamic> toJson() => {
        'label': label,
        'detail': detail,
        'afterLabel': afterLabel,
      };
}

/// A waiver: a defect overridden by a human, with a reason, on record.
class Waiver {
  const Waiver({
    required this.reason,
    required this.tag,
    required this.createdAt,
    required this.waivedBy,
  });

  factory Waiver.fromJson(Map<String, dynamic> json) => Waiver(
        reason: json['reason'] as String,
        tag: json['tag'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        waivedBy: json['waivedBy'] as String,
      );

  final String reason;
  final String tag;
  final DateTime createdAt;
  final String waivedBy;

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'tag': tag,
        'createdAt': createdAt.toIso8601String(),
        'waivedBy': waivedBy,
      };
}

/// A single finding: one rule, one verdict, with evidence.
///
/// Every defect carries timecode, measured value, and limit — measured,
/// not guessed. Suggestions carry the same evidence shape.
class Finding implements FindingLike {
  const Finding({
    required this.id,
    required this.ruleCode,
    required this.ruleVersion,
    required this.title,
    required this.kind,
    required this.timecode,
    required this.measuredLabel,
    required this.measuredValue,
    required this.limitLabel,
    required this.limitValue,
    required this.detail,
    this.status = FindingStatus.open,
    this.fix,
    this.waiver,
  });

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        id: json['id'] as String,
        ruleCode: json['ruleCode'] as String,
        ruleVersion: json['ruleVersion'] as String,
        title: json['title'] as String,
        kind: FindingKind.values.firstWhere(
          (k) => k.name == (json['kind'] as String),
        ),
        timecode: json['timecode'] as String,
        measuredLabel: json['measuredLabel'] as String,
        measuredValue: (json['measuredValue'] as num).toDouble(),
        limitLabel: json['limitLabel'] as String,
        limitValue: (json['limitValue'] as num).toDouble(),
        detail: json['detail'] as String,
        status: FindingStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String),
        ),
        fix: json['fix'] == null
            ? null
            : AutoFix.fromJson(json['fix'] as Map<String, dynamic>),
        waiver: json['waiver'] == null
            ? null
            : Waiver.fromJson(json['waiver'] as Map<String, dynamic>),
      );

  final String id;
  final String ruleCode;
  final String ruleVersion;
  final String title;
  final FindingKind kind;
  final String timecode;
  final String measuredLabel;
  final double measuredValue;
  final String limitLabel;
  final double limitValue;
  final String detail;
  final FindingStatus status;
  final AutoFix? fix;
  final Waiver? waiver;

  bool get isDefect => kind == FindingKind.defect;

  /// Blocks the release: open, or fixed-but-unconfirmed. Waived and
  /// confirmed findings never block.
  bool get blocksRelease =>
      isDefect &&
      (status == FindingStatus.open || status == FindingStatus.fixed);

  Finding copyWith({FindingStatus? status, Waiver? waiver}) => Finding(
        id: id,
        ruleCode: ruleCode,
        ruleVersion: ruleVersion,
        title: title,
        kind: kind,
        timecode: timecode,
        measuredLabel: measuredLabel,
        measuredValue: measuredValue,
        limitLabel: limitLabel,
        limitValue: limitValue,
        detail: detail,
        status: status ?? this.status,
        fix: fix,
        waiver: waiver ?? this.waiver,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleCode': ruleCode,
        'ruleVersion': ruleVersion,
        'title': title,
        'kind': kind.name,
        'timecode': timecode,
        'measuredLabel': measuredLabel,
        'measuredValue': measuredValue,
        'limitLabel': limitLabel,
        'limitValue': limitValue,
        'detail': detail,
        'status': status.name,
        'fix': fix?.toJson(),
        'waiver': waiver?.toJson(),
      };
}

/// An inspection report: the verdict, the evidence, and the record.
///
/// Immutable once created — a fix or waiver produces an UPDATED report
/// (same id, new findings state, exit code recomputed), and
/// re-inspection produces a NEW report. Nothing in a report can be
/// edited after the run; the SHA-256 [fingerprint] covers the canonical
/// JSON so any tampering is detectable.
class Report {
  const Report({
    required this.id,
    required this.exportId,
    required this.exportName,
    required this.createdAt,
    required this.registryVersion,
    required this.findings,
    required this.score,
    required this.exitCode,
    required this.durationSeconds,
    required this.framesProbed,
    required this.fingerprint,
    this.demoProbe = false,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        exportId: json['exportId'] as String,
        exportName: json['exportName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        registryVersion: json['registryVersion'] as String,
        findings: (json['findings'] as List<dynamic>)
            .map((f) => Finding.fromJson(f as Map<String, dynamic>))
            .toList(),
        score: json['score'] as int,
        exitCode: json['exitCode'] as int,
        durationSeconds: json['durationSeconds'] as int,
        framesProbed: json['framesProbed'] as int,
        fingerprint: json['fingerprint'] as String,
        demoProbe: json['demoProbe'] as bool? ?? false,
      );

  final String id;
  final String exportId;
  final String exportName;
  final DateTime createdAt;
  final String registryVersion;
  final List<Finding> findings;
  final int score;
  final int exitCode;
  final int durationSeconds;
  final int framesProbed;
  final String fingerprint;
  final bool demoProbe;

  List<Finding> get defects =>
      findings.where((f) => f.isDefect).toList();
  List<Finding> get suggestions =>
      findings.where((f) => !f.isDefect).toList();
  List<Finding> get openDefects =>
      defects.where((f) => f.blocksRelease).toList();
  List<Finding> get waivedDefects =>
      defects.where((f) => f.status == FindingStatus.waived).toList();
  List<Finding> get fixedAwaiting =>
      defects.where((f) => f.status == FindingStatus.fixed).toList();

  bool get isClean => exitCode == kExitClean;

  Report copyWith({
    List<Finding>? findings,
    int? score,
    int? exitCode,
    String? fingerprint,
  }) =>
      Report(
        id: id,
        exportId: exportId,
        exportName: exportName,
        createdAt: createdAt,
        registryVersion: registryVersion,
        findings: findings ?? this.findings,
        score: score ?? this.score,
        exitCode: exitCode ?? this.exitCode,
        durationSeconds: durationSeconds,
        framesProbed: framesProbed,
        fingerprint: fingerprint ?? this.fingerprint,
        demoProbe: demoProbe,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'exportId': exportId,
        'exportName': exportName,
        'createdAt': createdAt.toIso8601String(),
        'registryVersion': registryVersion,
        'findings': findings.map((f) => f.toJson()).toList(),
        'score': score,
        'exitCode': exitCode,
        'durationSeconds': durationSeconds,
        'framesProbed': framesProbed,
        'fingerprint': fingerprint,
        'demoProbe': demoProbe,
      };
}

/// One CI run (GitHub Action). v0.1 seeds demo runs locally; the Action
/// itself is a proposed integration (see CI setup + README appendix).
class CiRun {
  const CiRun({
    required this.id,
    required this.number,
    required this.prNumber,
    required this.prTitle,
    required this.exportName,
    required this.exitCode,
    required this.registryVersion,
    required this.createdAt,
    this.isDemo = false,
  });

  factory CiRun.fromJson(Map<String, dynamic> json) => CiRun(
        id: json['id'] as String,
        number: json['number'] as int,
        prNumber: json['prNumber'] as int,
        prTitle: json['prTitle'] as String,
        exportName: json['exportName'] as String,
        exitCode: json['exitCode'] as int,
        registryVersion: json['registryVersion'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isDemo: json['isDemo'] as bool? ?? false,
      );

  final String id;
  final int number;
  final int prNumber;
  final String prTitle;
  final String exportName;
  final int exitCode;
  final String registryVersion;
  final DateTime createdAt;
  final bool isDemo;

  bool get passed => exitCode == kExitClean;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'prNumber': prNumber,
        'prTitle': prTitle,
        'exportName': exportName,
        'exitCode': exitCode,
        'registryVersion': registryVersion,
        'createdAt': createdAt.toIso8601String(),
        'isDemo': isDemo,
      };
}

/// The local account. v0.1 auth is local-only (no backend): sign-in
/// creates a local profile, the session token lives in secure storage,
/// and "sync" is a local migration of guest data. Real backend sync is
/// phase 2 — the UI says so wherever it matters.
class Account {
  const Account({
    required this.name,
    required this.email,
    required this.plan,
    required this.createdAt,
    required this.verified,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        name: json['name'] as String,
        email: json['email'] as String,
        plan: json['plan'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        verified: json['verified'] as bool? ?? false,
      );

  final String name;
  final String email;
  final String plan;
  final DateTime createdAt;
  final bool verified;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'plan': plan,
        'createdAt': createdAt.toIso8601String(),
        'verified': verified,
      };
}

/// App settings, persisted locally.
class AppSettings {
  const AppSettings({
    this.suggestionsEnabled = true,
    this.autoInspect = true,
    this.prComments = true,
    this.pinnedRegistry = kRegistryVersion,
    this.ciConnected = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        suggestionsEnabled: json['suggestionsEnabled'] as bool? ?? true,
        autoInspect: json['autoInspect'] as bool? ?? true,
        prComments: json['prComments'] as bool? ?? true,
        pinnedRegistry:
            json['pinnedRegistry'] as String? ?? kRegistryVersion,
        ciConnected: json['ciConnected'] as bool? ?? false,
      );

  final bool suggestionsEnabled;
  final bool autoInspect;
  final bool prComments;
  final String pinnedRegistry;
  final bool ciConnected;

  AppSettings copyWith({
    bool? suggestionsEnabled,
    bool? autoInspect,
    bool? prComments,
    String? pinnedRegistry,
    bool? ciConnected,
  }) =>
      AppSettings(
        suggestionsEnabled: suggestionsEnabled ?? this.suggestionsEnabled,
        autoInspect: autoInspect ?? this.autoInspect,
        prComments: prComments ?? this.prComments,
        pinnedRegistry: pinnedRegistry ?? this.pinnedRegistry,
        ciConnected: ciConnected ?? this.ciConnected,
      );

  Map<String, dynamic> toJson() => {
        'suggestionsEnabled': suggestionsEnabled,
        'autoInspect': autoInspect,
        'prComments': prComments,
        'pinnedRegistry': pinnedRegistry,
        'ciConnected': ciConnected,
      };
}
