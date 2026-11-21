import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/exit_codes.dart';

class _FakeFinding implements FindingLike {
  _FakeFinding(this.blocksRelease);

  @override
  final bool blocksRelease;
}

void main() {
  group('exitCodeForFindings', () {
    test('no findings is clean (0)', () {
      expect(exitCodeForFindings(const []), kExitClean);
    });

    test('only non-blocking findings is clean (0)', () {
      expect(
        exitCodeForFindings([
          _FakeFinding(false),
          _FakeFinding(false),
        ]),
        kExitClean,
      );
    });

    test('one blocking finding is defects (1)', () {
      expect(
        exitCodeForFindings([
          _FakeFinding(false),
          _FakeFinding(true),
        ]),
        kExitDefects,
      );
    });
  });

  group('exitCodeLabel', () {
    test('0 is clean', () {
      expect(exitCodeLabel(kExitClean), contains('Clean'));
    });

    test('1 is defects', () {
      expect(exitCodeLabel(kExitDefects), contains('Defects'));
    });

    test('2 is an inspection error', () {
      expect(exitCodeLabel(kExitError), contains('error'));
    });
  });

  group('exitCodeCiBehaviour', () {
    test('0 passes the check', () {
      expect(exitCodeCiBehaviour(kExitClean), contains('passes'));
    });

    test('1 blocks the PR', () {
      expect(exitCodeCiBehaviour(kExitDefects), contains('blocked'));
    });

    test('2 fails the check as an error', () {
      expect(exitCodeCiBehaviour(kExitError), contains('error'));
    });
  });

  test('contract constants are 0 / 1 / 2', () {
    expect(kExitClean, 0);
    expect(kExitDefects, 1);
    expect(kExitError, 2);
  });
}
