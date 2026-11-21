/// Canonical constants for Frame Police: the rule registry version, the
/// CI exit-code contract, scoring weights, and the seeded demo fixture.
///
/// The demo fixture is SEEDED DEMO CONTENT — labelled as demo everywhere
/// it shows. It is the product's demo story from the V7 design (Launch
/// Teaser v3, PR #142, 248 CI runs), not measured usage. No dates, user
/// counts, or shipped claims are invented anywhere in the app or README.
library;

/// The pinned rule registry version. Every report records the version
/// that ran it; same input + same registry version = same report.
const String kRegistryVersion = 'v2.4.1';

/// Number of rules in the registry: 11 defect checks + 3 suggestions.
const int kRuleCount = 14;
const int kDefectRuleCount = 11;
const int kSuggestionRuleCount = 3;

/// ---------------------------------------------------------------------------
/// CI exit-code contract (see README "CI exit-code contract")
/// ---------------------------------------------------------------------------

/// Clean: no open defects. Waived defects and suggestions never block.
const int kExitClean = 0;

/// Defects: one or more open defects — including defects fixed but not yet
/// confirmed by re-inspection. A fix is not real until re-inspection
/// confirms it, so the exit code stays 1 until then.
const int kExitDefects = 1;

/// Inspection error: the file could not be read, the probe failed, or the
/// registry version recorded in the report does not match the pinned
/// version. CI treats this as a failed check, distinct from a defect.
const int kExitError = 2;

/// ---------------------------------------------------------------------------
/// Scoring
/// ---------------------------------------------------------------------------

/// Points deducted per open defect. Two open defects score 82 — the
/// Launch Teaser v3 demo verdict. Suggestions never affect the score,
/// the exit code, or anything CI reads.
const int kPointsPerDefect = 9;

/// Maximum score.
const int kMaxScore = 100;

/// ---------------------------------------------------------------------------
/// Waivers
/// ---------------------------------------------------------------------------

/// Minimum waiver reason length in characters. A waiver needs a reason,
/// and the reason stays in the report. Waiving never deletes the finding.
const int kMinWaiverChars = 20;

/// ---------------------------------------------------------------------------
/// Rule codes
/// ---------------------------------------------------------------------------

/// Defect rules (these decide the exit code).
const String kRuleSubtitleSafeArea = 'SUB-SAFE-01';
const String kRuleAudioPeak = 'AUD-PEAK-02';
const String kRuleAspectRatio = 'ASP-RATIO-01';
const String kRuleBlackFrames = 'BLACK-FR-01';
const String kRuleTextOverflow = 'TXT-OVER-01';
const String kRuleBrandLogo = 'BRAND-LOGO-01';
const String kRuleBrandColor = 'BRAND-COL-01';
const String kRuleCaptionSync = 'CAP-SYNC-01';
const String kRuleTitleSafeArea = 'TITLE-SAFE-01';
const String kRuleFrameRate = 'FRAMERATE-01';
const String kRuleMinResolution = 'RES-MIN-01';

/// Suggestion rules (opinions with evidence — never blocking).
const String kRuleLoudness = 'SUG-LOUD-01';
const String kRuleOpeningFrame = 'SUG-OPEN-01';
const String kRuleCaptionsFile = 'SUG-CAP-01';

/// ---------------------------------------------------------------------------
/// Seeded demo fixture (labelled DEMO everywhere it shows)
/// ---------------------------------------------------------------------------

class DemoFixture {
  /// The demo export: Launch Teaser v3, 00:47, 1080x1920, 86.4 MB.
  static const String teaserName = 'Launch Teaser — v3.mp4';
  static const int teaserDurationSeconds = 47;
  static const int teaserFrames = 1128;
  static const int teaserWidth = 1080;
  static const int teaserHeight = 1920;
  static const int teaserFps = 24;
  static const int teaserSizeBytes = 86400000;

  /// The two demo defects, with their canonical evidence.
  static const String subtitleTimecode = '00:00:12:08';
  static const double subtitleBottomY = 1066;
  static const double subtitleLimitY = 1052;
  static const double subtitleFixedY = 1040;
  static const String peakTimecode = '00:00:31:22';
  static const double peakDbfs = -0.8;
  static const double peakLimitDbfs = -1.0;
  static const double peakFixedDbfs = -1.4;

  /// The demo waiver reason (108 characters).
  static const String waiverReason =
      'Client approved the lower-third placement for this cut — '
      'the safe area is advisory here, not a platform rule.';

  /// Seeded history scores (past runs, stored records — not computed).
  static const List<int> historyScores = [88, 91, 86, 96, 82];

  /// Seeded CI totals. The recent-run list is stored alongside; counts
  /// move when a real local run appends (e.g. the payoff run #249).
  static const int ciTotalRuns = 248;
  static const int ciFailedRuns = 31;
  static const int ciCleanRuns = 217;

  /// The demo PR at the top of the CI list.
  static const int demoPrNumber = 142;
  static const int demoRunNumber = 248;

  /// Seeded lifetime totals shown on Home and Account.
  static const int defectsCaught = 47;
  static const int zeroDefectExports = 12;
}
