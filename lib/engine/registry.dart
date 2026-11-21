/// The rule registry: 14 versioned rules (11 defect checks + 3
/// suggestions) pinned at [kRegistryVersion].
///
/// The registry is the versioned rule set. A report records the registry
/// version that ran it; same input + same rules = same report. Editing a
/// rule's limit creates a new rule version — history is never rewritten
/// (see [Rule.withNewLimit]).
library;

import '../core/constants.dart';
import 'models.dart';

/// The default registry: all 14 rules at their v2.4.1 versions.
List<Rule> defaultRules() => [
      Rule(
        code: kRuleSubtitleSafeArea,
        name: 'Subtitle safe area',
        description:
            'Flags any subtitle whose bottom edge crosses the safe-area '
            'margin. Measured on every frame that carries a subtitle.',
        kind: FindingKind.defect,
        version: 'v1.2',
        limitLabel: '90% margin',
        limitValue: 90,
        unit: '%',
        versions: const [
          RuleVersion(
            version: 'v1.1',
            limitLabel: '85% margin',
            note: 'Widened to 90% after platform safe-area guidance.',
          ),
          RuleVersion(
            version: 'v1.0',
            limitLabel: '85% margin',
            note: 'First version.',
          ),
        ],
      ),
      Rule(
        code: kRuleAudioPeak,
        name: 'Audio peak / silence',
        description:
            'Flags any peak above the ceiling and any stretch of dead '
            'air longer than the silence limit.',
        kind: FindingKind.defect,
        version: 'v2.0',
        limitLabel: '−1.0 dBFS peak · 1.5 s silence',
        limitValue: -1.0,
        unit: 'dBFS',
        versions: const [
          RuleVersion(
            version: 'v1.1',
            limitLabel: '−1.0 dBFS peak',
            note: 'Silence check added.',
          ),
          RuleVersion(
            version: 'v1.0',
            limitLabel: '−0.5 dBFS peak',
            note: 'First version.',
          ),
        ],
      ),
      Rule(
        code: kRuleAspectRatio,
        name: 'Aspect ratio',
        description:
            'The export must match the aspect ratio declared for the '
            'project (9:16 vertical for the demo project).',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: '9:16',
        limitValue: 9 / 16,
        unit: 'ratio',
        versions: const [],
      ),
      Rule(
        code: kRuleBlackFrames,
        name: 'Black frames',
        description:
            'Flags any run of fully black frames — usually a render gap '
            'or a missing clip.',
        kind: FindingKind.defect,
        version: 'v1.1',
        limitLabel: '0 black frames',
        limitValue: 0,
        unit: 'frames',
        versions: const [
          RuleVersion(
            version: 'v1.0',
            limitLabel: '≤ 3 black frames',
            note: 'Tightened to zero after a black-frame export shipped.',
          ),
        ],
      ),
      Rule(
        code: kRuleTextOverflow,
        name: 'Text overflow',
        description:
            'Flags any on-screen text whose bounding box crosses the '
            'frame edge.',
        kind: FindingKind.defect,
        version: 'v1.3',
        limitLabel: 'No overflow',
        limitValue: 0,
        unit: 'bool',
        versions: const [
          RuleVersion(
            version: 'v1.2',
            limitLabel: 'No overflow',
            note: 'Lower-third text included in the scan.',
          ),
          RuleVersion(
            version: 'v1.1',
            limitLabel: 'No overflow',
            note: 'Title cards included in the scan.',
          ),
          RuleVersion(
            version: 'v1.0',
            limitLabel: 'No overflow',
            note: 'First version.',
          ),
        ],
      ),
      Rule(
        code: kRuleBrandLogo,
        name: 'Brand mark present',
        description:
            'The brand mark must appear at least once in the export — '
            'intro or outro.',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: 'Mark present',
        limitValue: 1,
        unit: 'bool',
        versions: const [],
      ),
      Rule(
        code: kRuleBrandColor,
        name: 'Brand colour usage',
        description:
            'Dominant colours must stay inside the brand palette. '
            'Off-palette fills and lower-thirds are flagged.',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: 'Palette only',
        limitValue: 1,
        unit: 'bool',
        versions: const [],
      ),
      Rule(
        code: kRuleCaptionSync,
        name: 'Caption sync',
        description:
            'Burned-in captions must stay within the sync tolerance of '
            'the spoken audio.',
        kind: FindingKind.defect,
        version: 'v1.1',
        limitLabel: '±120 ms',
        limitValue: 120,
        unit: 'ms',
        versions: const [
          RuleVersion(
            version: 'v1.0',
            limitLabel: '±200 ms',
            note: 'Tolerance tightened after viewer complaints.',
          ),
        ],
      ),
      Rule(
        code: kRuleTitleSafeArea,
        name: 'Title safe area',
        description:
            'Titles must stay inside the 85% title-safe area so they '
            'survive every player crop.',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: '85% margin',
        limitValue: 85,
        unit: '%',
        versions: const [],
      ),
      Rule(
        code: kRuleFrameRate,
        name: 'Frame rate',
        description:
            'The export frame rate must match the project frame rate '
            '(24 fps for the demo project).',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: '24 fps',
        limitValue: 24,
        unit: 'fps',
        versions: const [],
      ),
      Rule(
        code: kRuleMinResolution,
        name: 'Minimum resolution',
        description:
            'The short edge must be at least 1080 px — below that, the '
            'export is visibly soft on modern phones.',
        kind: FindingKind.defect,
        version: 'v1.0',
        limitLabel: '≥ 1080 px short edge',
        limitValue: 1080,
        unit: 'px',
        versions: const [],
      ),
      Rule(
        code: kRuleLoudness,
        name: 'Loudness target',
        description:
            'Integrated loudness near the −14.0 LUFS channel target '
            'keeps the export consistent with the rest of the channel. '
            'An opinion, not a defect.',
        kind: FindingKind.suggestion,
        version: 'v1.0',
        limitLabel: '−14.0 LUFS target',
        limitValue: -14.0,
        unit: 'LUFS',
        versions: const [],
      ),
      Rule(
        code: kRuleOpeningFrame,
        name: 'Opening frame brightness',
        description:
            'The opening frame is the thumbnail on most players. '
            'A very dark opening frame underperforms. An opinion, '
            'not a defect.',
        kind: FindingKind.suggestion,
        version: 'v1.0',
        limitLabel: '< 50% dark',
        limitValue: 0.5,
        unit: 'fraction',
        versions: const [],
      ),
      Rule(
        code: kRuleCaptionsFile,
        name: 'Captions file attached',
        description:
            'An .srt alongside the export improves reach and '
            'accessibility; burned-in subtitles do not replace it. '
            'An opinion, not a defect.',
        kind: FindingKind.suggestion,
        version: 'v1.0',
        limitLabel: '.srt attached',
        limitValue: 1,
        unit: 'bool',
        versions: const [],
      ),
    ];

/// Looks up a rule by code in [rules]; returns null when absent.
Rule? findRule(List<Rule> rules, String code) {
  for (final rule in rules) {
    if (rule.code == code) return rule;
  }
  return null;
}
