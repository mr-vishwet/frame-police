/// One-tap auto-fix definitions — the V7 breakpoint: "the linter that
/// fixes".
///
/// Every defect rule has a fix. A fix is previewed before/after inline
/// and applied in one tap; the finding then waits for re-inspection,
/// which confirms it (or re-opens it if the fix did not hold). The exit
/// code stays 1 until re-inspection confirms every fix.
library;

import '../core/constants.dart';
import 'models.dart';

/// The auto-fix for a defect rule code, or null for suggestion rules
/// (suggestions are opinions — there is nothing to fix).
AutoFix? fixForRule(String ruleCode) {
  switch (ruleCode) {
    case kRuleSubtitleSafeArea:
      return const AutoFix(
        label: 'Auto-fix: nudge the subtitle up 14 px',
        detail: 'Moves the subtitle bottom edge inside the safe area. '
            'Previewed before/after, one tap to apply.',
        afterLabel: 'y = 1,040 px — inside the safe area',
      );
    case kRuleAudioPeak:
      return const AutoFix(
        label: 'Auto-fix: limiter at −1.0 dBFS on the master',
        detail: 'The peak is a single drum hit at the drop. The limiter '
            'tames it without touching the rest of the mix.',
        afterLabel: 'Peak −1.4 dBFS — inside the limit',
      );
    case kRuleAspectRatio:
      return const AutoFix(
        label: 'Auto-fix: re-crop to the project aspect',
        detail: 'Re-crops the working copy to the declared aspect ratio. '
            'The original file is untouched.',
        afterLabel: 'Matches the declared aspect',
      );
    case kRuleBlackFrames:
      return const AutoFix(
        label: 'Auto-fix: trim the black frames',
        detail: 'Cuts the fully black frames from the working copy. '
            'Re-inspection verifies none remain.',
        afterLabel: '0 black frames',
      );
    case kRuleTextOverflow:
      return const AutoFix(
        label: 'Auto-fix: shrink the text to fit',
        detail: 'Scales the overflowing text block until its bounding box '
            'sits inside the frame.',
        afterLabel: 'Text inside the frame',
      );
    case kRuleBrandLogo:
      return const AutoFix(
        label: 'Auto-fix: add the brand mark to the outro',
        detail: 'Places the brand mark on the closing frame of the '
            'working copy.',
        afterLabel: 'Mark present',
      );
    case kRuleBrandColor:
      return const AutoFix(
        label: 'Auto-fix: remap to the brand palette',
        detail: 'Remaps the off-palette fills to the nearest brand '
            'colour.',
        afterLabel: 'Palette only',
      );
    case kRuleCaptionSync:
      return const AutoFix(
        label: 'Auto-fix: re-sync the captions',
        detail: 'Shifts the caption track onto the spoken audio.',
        afterLabel: '0 ms offset',
      );
    case kRuleTitleSafeArea:
      return const AutoFix(
        label: 'Auto-fix: move the title inside the safe area',
        detail: 'Repositions the title block inside the title-safe area.',
        afterLabel: 'Inside the title-safe area',
      );
    case kRuleFrameRate:
      return const AutoFix(
        label: 'Auto-fix: conform to 24 fps',
        detail: 'Re-times the working copy to the project frame rate.',
        afterLabel: '24 fps',
      );
    case kRuleMinResolution:
      return const AutoFix(
        label: 'Auto-fix: upscale to the minimum',
        detail: 'Upscales the working copy so the short edge meets the '
            '1080 px minimum. Upscaling cannot add detail — re-export '
            'at full resolution when you can.',
        afterLabel: '1080 px short edge',
      );
    default:
      return null;
  }
}
