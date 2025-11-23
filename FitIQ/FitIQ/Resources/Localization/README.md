# Localization Resources

This directory contains the localization files for the Health Restart app.

## Supported Languages

- **English (en)** - Base language
- **Spanish (es)** - Latin American focus
- **Portuguese (pt-BR)** - Brazilian Portuguese
- **French (fr)** - Standard French
- **German (de)** - Standard German

## Structure

Each `.lproj` directory contains localized resources for that language:

```
en.lproj/
├── Localizable.strings    # English strings

es.lproj/
├── Localizable.strings    # Spanish strings

pt-BR.lproj/
├── Localizable.strings    # Portuguese (Brazilian) strings

fr.lproj/
├── Localizable.strings    # French strings

de.lproj/
├── Localizable.strings    # German strings
```

## File Format

All `Localizable.strings` files follow this format:

```
/* Comment describing the section or string */
"key" = "value";
```

Example:
```
/* Common Actions */
"common.save" = "Save";
"common.cancel" = "Cancel";
```

## Key Naming Convention

Keys follow a hierarchical pattern:

```
category.subcategory.identifier
```

Examples:
- `common.save` - Common action buttons
- `navigation.nutrition` - Navigation/tab titles
- `nutrition.add_meal` - Feature-specific actions
- `profile.settings.units` - Nested feature settings

## Categories

- **common** - Universal actions (save, cancel, delete, etc.)
- **navigation** - Tab bar and navigation titles
- **goals** - Goals feature
- **nutrition** - Nutrition tracking
- **workout** - Workout tracking
- **sleep** - Sleep tracking
- **profile** - User profile and settings
- **coach** - AI coach features
- **summary** - Dashboard/summary view
- **alert** - Alert and notification messages
- **empty** - Empty state messages
- **media** - Photo and media related
- **unit** - Units of measurement
- **format** - Formatting helpers (with parameters)
- **date** - Date-related strings
- **error** - Error messages

## Adding New Strings

When adding new strings, you MUST add them to ALL language files:

1. Add to `en.lproj/Localizable.strings` (English - required)
2. Add to `es.lproj/Localizable.strings` (Spanish)
3. Add to `pt-BR.lproj/Localizable.strings` (Portuguese)
4. Add to `fr.lproj/Localizable.strings` (French)
5. Add to `de.lproj/Localizable.strings` (German)

## Translation Guidelines

### Spanish (es)
- Use informal "tú" form
- Latin American Spanish preferred
- Example: "Guardar" (Save)

### Portuguese (pt-BR)
- Brazilian Portuguese variant
- Use informal "você" form
- Example: "Salvar" (Save)

### French (fr)
- Use formal "vous" form
- Standard French (France)
- Example: "Enregistrer" (Save)

### German (de)
- Use formal "Sie" form
- Be mindful of long compound words
- Example: "Speichern" (Save)

## Verification

Before committing changes:

1. ✅ All strings added to all 5 language files
2. ✅ Keys are identical across all files
3. ✅ Syntax is correct (quotes, semicolons)
4. ✅ Comments are present for context
5. ✅ No duplicate keys within a file
6. ✅ File encoding is UTF-8

## Usage in Code

### Using L10n Helper (Recommended)

```swift
import SwiftUI

Text(L10n.Common.save)
Button(L10n.Common.cancel) { }
```

### Using String(localized:)

```swift
Text(String(localized: "common.save"))
```

### Using NSLocalizedString

```swift
Text(NSLocalizedString("common.save", comment: ""))
```

## Resources

- Full Documentation: `/docs/LOCALIZATION_GUIDE.md`
- Examples: `/docs/LOCALIZATION_EXAMPLES.md`
- Helper Class: `/FitIQ/Infrastructure/Localization/LocalizationHelper.swift`

## Testing

Test each language by:

1. Edit Scheme > Run > Options > App Language
2. Select language to test
3. Run app and verify all strings display correctly

## Contact

For translation questions or improvements, please:
1. Check the documentation first
2. Consult with native speakers for accuracy
3. Ensure consistency with existing translations
