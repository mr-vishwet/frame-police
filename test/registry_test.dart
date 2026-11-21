import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/registry.dart';

void main() {
  group('default registry', () {
    late List<Rule> rules;

    setUp(() => rules = defaultRules());

    test('has 14 rules: 11 defects + 3 suggestions', () {
      expect(rules.length, kRuleCount);
      expect(rules.where((r) => r.isDefect).length, kDefectRuleCount);
      expect(
        rules.where((r) => !r.isDefect).length,
        kSuggestionRuleCount,
      );
    });

    test('all rule codes are unique', () {
      final codes = rules.map((r) => r.code).toSet();
      expect(codes.length, rules.length);
    });

    test('all rules are enabled by default', () {
      expect(rules.every((r) => r.enabled), isTrue);
    });

    test('contains the canonical defect rules', () {
      expect(findRule(rules, kRuleSubtitleSafeArea), isNotNull);
      expect(findRule(rules, kRuleAudioPeak), isNotNull);
      expect(findRule(rules, kRuleAspectRatio), isNotNull);
      expect(findRule(rules, kRuleBlackFrames), isNotNull);
      expect(findRule(rules, kRuleTextOverflow), isNotNull);
    });

    test('contains the three suggestion rules', () {
      expect(findRule(rules, kRuleLoudness), isNotNull);
      expect(findRule(rules, kRuleOpeningFrame), isNotNull);
      expect(findRule(rules, kRuleCaptionsFile), isNotNull);
    });

    test('subtitle rule is v1.2 at the 90% margin', () {
      final rule = findRule(rules, kRuleSubtitleSafeArea)!;
      expect(rule.version, 'v1.2');
      expect(rule.limitValue, 90);
      expect(rule.limitLabel, '90% margin');
    });

    test('findRule returns null for an unknown code', () {
      expect(findRule(rules, 'NOPE-01'), isNull);
    });
  });

  group('rule versioning', () {
    test('editing a limit bumps the version and keeps history', () {
      final rule = findRule(defaultRules(), kRuleSubtitleSafeArea)!;
      final updated = rule.withNewLimit(
        newValue: 85,
        newLabel: '85% margin',
        note: 'Limit changed from 90% margin to 85% margin.',
      );
      expect(updated.version, 'v1.3');
      expect(updated.limitValue, 85);
      expect(updated.limitLabel, '85% margin');
      // The old version moves into history; nothing is rewritten.
      expect(updated.versions.first.version, 'v1.2');
      expect(updated.versions.first.limitLabel, '90% margin');
      expect(updated.versions.length, rule.versions.length + 1);
    });

    test('the original rule is unchanged by withNewLimit', () {
      final rule = findRule(defaultRules(), kRuleSubtitleSafeArea)!;
      rule.withNewLimit(
        newValue: 85,
        newLabel: '85% margin',
        note: 'test',
      );
      expect(rule.version, 'v1.2');
      expect(rule.limitValue, 90);
    });
  });

  group('rule JSON round-trip', () {
    test('toJson/fromJson preserves a rule', () {
      final rule = findRule(defaultRules(), kRuleAudioPeak)!;
      final restored = Rule.fromJson(rule.toJson());
      expect(restored.code, rule.code);
      expect(restored.version, rule.version);
      expect(restored.limitValue, rule.limitValue);
      expect(restored.versions.length, rule.versions.length);
      expect(restored.enabled, rule.enabled);
    });
  });
}
