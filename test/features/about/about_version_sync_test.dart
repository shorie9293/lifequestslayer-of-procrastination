import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';

/// ドリフト防止の不変条件:
/// pubspec.yaml の version: 行と kAboutInfo.version は常に一致せよ。
void main() {
  test('kAboutInfo.version は pubspec.yaml の version と一致する', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml に version 行が無い');
    expect(kAboutInfo.version, match!.group(1));
  });
}
