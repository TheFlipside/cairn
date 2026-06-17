import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/health/health_source.dart';
import 'package:flutter/material.dart';

/// Colour for a sleep [stage] in charts and legends.
Color stageColor(SleepStage stage) => switch (stage) {
  SleepStage.deep => const Color(0xFF303F9F),
  SleepStage.light ||
  SleepStage.asleepUnspecified ||
  SleepStage.session => const Color(0xFF5C6BC0),
  SleepStage.rem => const Color(0xFF26A69A),
  SleepStage.awake ||
  SleepStage.inBed ||
  SleepStage.outOfBed => const Color(0xFFFFB74D),
};

/// Localised human-readable label for a sleep [stage].
String stageLabel(AppLocalizations l10n, SleepStage stage) => switch (stage) {
  SleepStage.deep => l10n.stageDeep,
  SleepStage.light => l10n.stageLight,
  SleepStage.rem => l10n.stageRem,
  SleepStage.asleepUnspecified => l10n.stageAsleep,
  SleepStage.session => l10n.stageSleep,
  SleepStage.awake => l10n.stageAwake,
  SleepStage.inBed => l10n.stageInBed,
  SleepStage.outOfBed => l10n.stageOutOfBed,
};

/// Vertical depth rank for the hypnogram Y axis (deeper sleep lower). Awake is
/// at the top, deep at the bottom; light/asleep/session share the middle band.
double stageDepth(SleepStage stage) => switch (stage) {
  SleepStage.deep => 0,
  SleepStage.light || SleepStage.asleepUnspecified || SleepStage.session => 1,
  SleepStage.rem => 2,
  SleepStage.awake || SleepStage.inBed || SleepStage.outOfBed => 3,
};

/// Localised Y-axis tick label for the hypnogram at the given [depth] (see
/// [stageDepth]), or `null` for a value with no tick.
String? hypnogramAxisLabel(AppLocalizations l10n, int depth) => switch (depth) {
  0 => l10n.stageDeep,
  1 => l10n.stageLight,
  2 => l10n.stageRem,
  3 => l10n.stageAwake,
  _ => null,
};

/// Localised abbreviated weekday label for [weekday] (`DateTime.monday` == 1
/// … `DateTime.sunday` == 7), for the sleep trend axis.
String weekdayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.weekdayMon,
  DateTime.tuesday => l10n.weekdayTue,
  DateTime.wednesday => l10n.weekdayWed,
  DateTime.thursday => l10n.weekdayThu,
  DateTime.friday => l10n.weekdayFri,
  DateTime.saturday => l10n.weekdaySat,
  _ => l10n.weekdaySun,
};
