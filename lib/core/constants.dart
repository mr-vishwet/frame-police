/// Canonical constants for Frame Police: the rule registry version, the
/// CI exit-code contract, scoring weights, and the lifetime totals.
///
/// No seeded demo numbers live here: counters start at zero and only
/// move when real inspections run. No dates, user counts, or shipped
/// claims are invented anywhere in the app or README.
library;

/// The pinned rule registry version. Every report records the version
/// that ran it; same input + same registry version = same report.
const String kRegistryVersion = 'v2.4.1';

/// Number of rules in the registry: 11 defect checks + 3 suggestions.
const int kRuleCount = 14;
/// The defect rule count.
const int kDefectRuleCount = 11;
/// The suggestion rule count.
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

/// Points deducted per open defect. Two open defects score 82.
/// Suggestions never affect the score, the exit code, or anything CI
/// reads.
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
/// The audio peak rule code.
const String kRuleAudioPeak = 'AUD-PEAK-02';
/// The aspect ratio rule code.
const String kRuleAspectRatio = 'ASP-RATIO-01';
/// The black frames rule code.
const String kRuleBlackFrames = 'BLACK-FR-01';
/// The text overflow rule code.
const String kRuleTextOverflow = 'TXT-OVER-01';
/// The brand logo rule code.
const String kRuleBrandLogo = 'BRAND-LOGO-01';
/// The brand color rule code.
const String kRuleBrandColor = 'BRAND-COL-01';
/// The caption sync rule code.
const String kRuleCaptionSync = 'CAP-SYNC-01';
/// The title safe area rule code.
const String kRuleTitleSafeArea = 'TITLE-SAFE-01';
/// The frame rate rule code.
const String kRuleFrameRate = 'FRAMERATE-01';
/// The min resolution rule code.
const String kRuleMinResolution = 'RES-MIN-01';

/// Suggestion rules (opinions with evidence — never blocking).
const String kRuleLoudness = 'SUG-LOUD-01';
/// The opening frame rule code.
const String kRuleOpeningFrame = 'SUG-OPEN-01';
/// The captions file rule code.
const String kRuleCaptionsFile = 'SUG-CAP-01';

/// Lifetime totals start at zero and only move when real inspections
/// run. The demo fixture that used to live here (Launch Teaser v3,
/// PR #142, 248 CI runs, 47 defects caught) was deleted in the
/// real-data conversion.
