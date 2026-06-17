import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/profile/bmi.dart';

/// The localised WHO-category label for [category]. Kept out of [BmiCategory]
/// itself so the pure BMI model stays free of UI/localization dependencies.
String bmiCategoryLabel(AppLocalizations l10n, BmiCategory category) =>
    switch (category) {
      BmiCategory.underweight => l10n.bmiCategoryUnderweight,
      BmiCategory.normal => l10n.bmiCategoryNormal,
      BmiCategory.overweight => l10n.bmiCategoryOverweight,
      BmiCategory.obese => l10n.bmiCategoryObese,
    };
