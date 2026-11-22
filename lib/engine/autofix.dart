/// Fix guidance — what to change in your editor, with the exact
/// numbers.
///
/// Frame Police cannot edit media: there is no auto-fix that rewrites
/// a video file. Every defect rule carries guidance instead — the
/// measured value, the limit, and the concrete change that clears it.
/// The finding stays open until the user re-exports and re-inspects a
/// new file; re-inspection is what confirms a fix.
///
/// [fixForRule] takes the [Finding] when one is available so the
/// guidance carries the exact measured and limit values (e.g. "lower
/// the peak from −0.6 dBFS to at most −1.0 dBFS"). Called without a
/// finding — as the engine does when it builds the finding — it returns
/// the same guidance without the measured values.
library;

import '../core/constants.dart';
import '../core/format.dart';
import 'models.dart';

/// What a re-export + re-inspection means for the finding, appended to
/// every guidance detail.
const _reinspectNote =
    ' Re-export and re-inspect — the finding stays open until a new '
    'inspection passes.';

String _px(double value) => '${formatInt(value.round())} px';

/// The fix guidance for a defect rule code, or null for suggestion
/// rules (suggestions are opinions — there is nothing to fix).
///
/// Pass the [finding] to get guidance with its exact measured and
/// limit values.
AutoFix? fixForRule(String ruleCode, {Finding? finding}) {
  final f = finding;
  switch (ruleCode) {
    case kRuleSubtitleSafeArea: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: move the subtitle up',
          detail: 'In your editor, move the subtitle so its bottom edge '
              'sits inside the safe area.$_reinspectNote',
          afterLabel: 'Inside the safe area',
        );
      }
      final breach = (f.measuredValue - f.limitValue).round();
      return AutoFix(
        label: 'Fix in your editor: nudge the subtitle up $breach px',
        detail: 'In your editor, move the subtitle so its bottom edge '
            'is at most ${_px(f.limitValue)} — it is at '
            '${_px(f.measuredValue)} at ${f.timecode}.'
            '$_reinspectNote',
        afterLabel: 'y ≤ ${_px(f.limitValue)}',
      );
    }
    case kRuleAudioPeak: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: tame the peak',
          detail: 'In your editor, lower the peak to at most the limit — '
              'a limiter on the master tames a single hot peak without '
              'touching the rest of the mix. Or trim the dead air if '
              'silence is the defect.$_reinspectNote',
          afterLabel: 'Inside the limit',
        );
      }
      // AUD-PEAK-02 fires for two defects: a hot peak (limit −1.0
      // dBFS) or dead air (limit 1.5 s). The limit value tells them
      // apart.
      if (f.limitValue < 0) {
        final over = f.measuredValue - f.limitValue;
        return AutoFix(
          label: 'Fix in your editor: lower the peak by '
              '${over.toStringAsFixed(1)} dB',
          detail: 'In your editor, lower the peak at ${f.timecode} from '
              '${formatDbfs(f.measuredValue)} to at most '
              '${formatDbfs(f.limitValue)} — a limiter on the master at '
              '${formatDbfs(f.limitValue)} tames it without touching '
              'the rest of the mix.$_reinspectNote',
          afterLabel: 'Peak at most ${formatDbfs(f.limitValue)}',
        );
      }
      return AutoFix(
        label: 'Fix in your editor: cut the dead air',
        detail: 'A stretch of dead air lasts '
            '${f.measuredValue.toStringAsFixed(1)} s — longer than the '
            '${f.limitValue.toStringAsFixed(1)} s limit. Trim it in '
            'your editor.$_reinspectNote',
        afterLabel: '≤ ${f.limitValue.toStringAsFixed(1)} s silence',
      );
    }
    case kRuleAspectRatio: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: re-export at the project aspect',
          detail: 'Re-crop in your editor to the aspect the project '
              'declares, then re-export.$_reinspectNote',
          afterLabel: 'Matches the declared aspect',
        );
      }
      return AutoFix(
        label: 'Fix in your editor: re-export at ${f.limitLabel}',
        detail: 'The export is ${f.measuredLabel}; the project declares '
            '${f.limitLabel}. Re-crop in your editor and re-export.'
            '$_reinspectNote',
        afterLabel: 'Matches ${f.limitLabel}',
      );
    }
    case kRuleBlackFrames: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: trim the black frames',
          detail: 'Cut the fully black frames — usually a render gap or '
              'a missing clip — then re-export.$_reinspectNote',
          afterLabel: '0 black frames',
        );
      }
      final count = f.measuredValue.toInt();
      return AutoFix(
        label: 'Fix in your editor: trim the $count black frame'
            '${count == 1 ? '' : 's'}',
        detail: 'Cut the $count fully black frame${count == 1 ? '' : 's'} '
            '— usually a render gap or a missing clip — then re-export.'
            '$_reinspectNote',
        afterLabel: '0 black frames',
      );
    }
    case kRuleTextOverflow: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: shrink the text to fit',
          detail: 'Scale the overflowing text block until its bounding '
              'box sits inside the frame, then re-export.'
              '$_reinspectNote',
          afterLabel: 'Text inside the frame',
        );
      }
      return AutoFix(
        label: 'Fix in your editor: shrink the text to fit',
        detail: 'A text bounding box crosses the frame edge at '
            '${f.timecode}. Scale the text block until it sits inside '
            'the frame, then re-export.$_reinspectNote',
        afterLabel: 'Text inside the frame',
      );
    }
    case kRuleBrandLogo:
      return const AutoFix(
        label: 'Fix in your editor: add the brand mark',
        detail: 'The brand mark does not appear anywhere in the export. '
            'Place it on the closing frame, then re-export.'
            '$_reinspectNote',
        afterLabel: 'Mark present',
      );
    case kRuleBrandColor:
      return const AutoFix(
        label: 'Fix in your editor: remap to the brand palette',
        detail: 'A fill or lower-third uses a colour outside the brand '
            'palette. Remap it to the nearest brand colour, then '
            're-export.$_reinspectNote',
        afterLabel: 'Palette only',
      );
    case kRuleCaptionSync: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: re-sync the captions',
          detail: 'Shift the caption track onto the spoken audio, then '
              're-export.$_reinspectNote',
          afterLabel: 'Inside the tolerance',
        );
      }
      final offset = f.measuredValue.abs().toStringAsFixed(0);
      final tolerance = f.limitValue.toStringAsFixed(0);
      return AutoFix(
        label: 'Fix in your editor: shift the captions by $offset ms',
        detail: 'Burned-in captions sit $offset ms off the spoken audio '
            '— outside the ±$tolerance ms tolerance. Shift the caption '
            'track onto the audio, then re-export.$_reinspectNote',
        afterLabel: 'Within ±$tolerance ms',
      );
    }
    case kRuleTitleSafeArea: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: move the title inside the safe area',
          detail: 'Reposition the title block inside the title-safe '
              'area, then re-export.$_reinspectNote',
          afterLabel: 'Inside the title-safe area',
        );
      }
      final breach = (f.measuredValue - f.limitValue).round();
      return AutoFix(
        label: 'Fix in your editor: move the title up $breach px',
        detail: 'In your editor, move the title so its bottom edge is '
            'at most ${_px(f.limitValue)} — it is at '
            '${_px(f.measuredValue)}.$_reinspectNote',
        afterLabel: 'y ≤ ${_px(f.limitValue)}',
      );
    }
    case kRuleFrameRate: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: conform to the project frame rate',
          detail: 'Re-time the export to the project frame rate, then '
              're-export.$_reinspectNote',
          afterLabel: 'Project frame rate',
        );
      }
      return AutoFix(
        label: 'Fix in your editor: conform to ${f.limitLabel}',
        detail: 'The export is ${f.measuredLabel}; the project is '
            '${f.limitLabel}. Re-time in your editor and re-export.'
            '$_reinspectNote',
        afterLabel: f.limitLabel,
      );
    }
    case kRuleMinResolution: {
      if (f == null) {
        return const AutoFix(
          label: 'Fix in your editor: re-export at full resolution',
          detail: 'The short edge is below the 1080 px minimum. '
              'Re-export at full resolution — upscaling cannot add '
              'detail.$_reinspectNote',
          afterLabel: '1080 px short edge',
        );
      }
      final shortEdge = f.measuredValue.toInt();
      final minimum = f.limitValue.toStringAsFixed(0);
      return AutoFix(
        label: 'Fix in your editor: re-export at full resolution',
        detail: 'The short edge is $shortEdge px — below the $minimum px '
            'minimum. Re-export at full resolution; upscaling cannot '
            'add detail.$_reinspectNote',
        afterLabel: '$minimum px short edge',
      );
    }
    default:
      return null;
  }
}
