/// The CI exit-code contract.
///
/// This is the product's core promise: CI reads ONLY the exit code.
/// The contract is documented in the README, shown on the CI setup
/// screen, and enforced by the inspector — the three must agree.
library;

import '../core/constants.dart';

/// Human-readable meaning of an exit code.
String exitCodeLabel(int exitCode) {
  switch (exitCode) {
    case kExitClean:
      return 'Clean — no open defects';
    case kExitDefects:
      return 'Defects — one or more open defects';
    case kExitError:
      return 'Inspection error';
    default:
      return 'Unknown exit code $exitCode';
  }
}

/// What CI does with an exit code.
String exitCodeCiBehaviour(int exitCode) {
  switch (exitCode) {
    case kExitClean:
      return 'Check passes. The PR may merge.';
    case kExitDefects:
      return 'Check fails. The PR is blocked until the check passes.';
    case kExitError:
      return 'Check fails (error, not a defect). Re-run the inspection.';
    default:
      return 'Unknown — treat as a failed check.';
  }
}

/// Derives the exit code from a finding list. Defects that are open —
/// or fixed but awaiting re-inspection — yield 1. Waived and confirmed
/// defects yield 0. Suggestions NEVER affect the exit code.
int exitCodeForFindings(Iterable<FindingLike> findings) {
  for (final finding in findings) {
    if (finding.blocksRelease) return kExitDefects;
  }
  return kExitClean;
}

/// Minimal shape the exit-code derivation needs, so tests can pass
/// lightweight fakes without building full [Finding] objects.
abstract class FindingLike {
  /// Whether this finding blocks the release.
  bool get blocksRelease;
}
