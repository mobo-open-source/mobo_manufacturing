# Text Styling Guide for Odoo Manufacturing App

This guide explains how to implement consistent Manrope font styling throughout the app using the centralized text utilities.

## Available Utilities

### 1. AppTextStyles (Comprehensive)
Located: `lib/shared/utils/text_styles.dart`

**Features:**
- Complete text styling system with theme awareness
- Context-aware styles that adapt to dark/light themes
- Pre-defined styles for all UI components
- Helper methods for dynamic styling

**Usage Examples:**
```dart
import '../../shared/utils/text_styles.dart';

// App bar titles
Text('Settings', style: AppTextStyles.appBarTitle(context))

// Card titles
Text('Language & Region', style: AppTextStyles.cardTitle(context))

// List tile titles and subtitles
Text('Dark Mode', style: AppTextStyles.listTileTitle(context))
Text('Switch between themes', style: AppTextStyles.listTileSubtitle(context))

// Custom styling
Text('Custom Text', style: AppTextStyles.custom(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: Colors.blue,
))
```

### 2. AppText (Simple)
Located: `lib/shared/utils/app_text.dart`

**Features:**
- Simple utility for quick Manrope font application
- Direct text widget creation
- Basic style presets
- Extension methods for existing Text widgets

**Usage Examples:**
```dart
import '../../shared/utils/app_text.dart';

// Create text with Manrope font
AppText.manrope('Hello World', 
  fontSize: 16, 
  fontWeight: FontWeight.w600,
  color: Colors.black87,
)

// Use predefined styles
Text('Title', style: AppText.heading4)
Text('Body text', style: AppText.bodyMedium)

// Apply to existing Text widgets
Text('Existing text').withManrope(
  fontSize: 14,
  fontWeight: FontWeight.w500,
)
```

## Implementation Steps

### Step 1: Add Import
Add the import to your Dart file:
```dart
import '../../shared/utils/text_styles.dart';
// OR
import '../../shared/utils/app_text.dart';
```

### Step 2: Replace Existing Text Styles

**Before:**
```dart
Text(
  'Settings',
  style: GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  ),
)
```

**After (using AppTextStyles):**
```dart
Text(
  'Settings',
  style: AppTextStyles.appBarTitle(context),
)
```

**After (using AppText):**
```dart
AppText.manrope(
  'Settings',
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: Colors.black87,
)
```

### Step 3: Common Replacements

| Component | Old Style | New Style (AppTextStyles) |
|-----------|-----------|---------------------------|
| App Bar Title | `GoogleFonts.inter(...)` | `AppTextStyles.appBarTitle(context)` |
| Card Title | `GoogleFonts.montserrat(...)` | `AppTextStyles.cardTitle(context)` |
| List Tile Title | `GoogleFonts.inter(...)` | `AppTextStyles.listTileTitle(context)` |
| List Tile Subtitle | `GoogleFonts.inter(...)` | `AppTextStyles.listTileSubtitle(context)` |
| Button Text | `GoogleFonts.inter(...)` | `AppTextStyles.buttonMedium` |
| Body Text | `GoogleFonts.inter(...)` | `AppTextStyles.bodyMedium` |
| Caption Text | `GoogleFonts.inter(...)` | `AppTextStyles.caption` |

## Files to Update

### Priority 1 (Main UI Components)
1. `lib/Dashboard/pages/configuration.dart`
2. `lib/Dashboard/pages/settings.dart` ✅ (Already updated)
3. `lib/Dashboard/pages/dashboard_mo.dart`
4. `lib/Dashboard/pages/profile_form.dart`

### Priority 2 (Login & Setup)
5. `lib/LoginPage/login_page.dart`
6. `lib/LoginPage/pages/server_setup.dart`
7. `lib/LoginPage/widgets/login_form.dart`

### Priority 3 (Manufacturing Screens)
8. `lib/Dashboard/pages/manufacturing_order/manufacturing_order_screen.dart`
9. `lib/Dashboard/pages/manufacturing_order/manufacturing_order_form.dart`
10. `lib/Dashboard/pages/manufacturing_order/work_order_screen.dart`

### Priority 4 (Widgets & Components)
11. `lib/Dashboard/widgets/*.dart`
12. `lib/shared/widgets/*.dart`
13. `lib/core/widgets/*.dart`

## Search and Replace Patterns

### Find and Replace in VS Code/IDE

**Pattern 1: GoogleFonts.inter**
```
Find: GoogleFonts\.inter\(
Replace: AppText.manropeStyle(
```

**Pattern 2: GoogleFonts.montserrat**
```
Find: GoogleFonts\.montserrat\(
Replace: AppText.manropeStyle(
```

**Pattern 3: GoogleFonts.manrope**
```
Find: GoogleFonts\.manrope\(
Replace: AppText.manropeStyle(
```

### Bulk Update Script (Optional)
You can create a script to automatically update files:

```bash
#!/bin/bash
# Update all Dart files to use AppText utility

find lib -name "*.dart" -type f -exec sed -i 's/GoogleFonts\.inter(/AppText.manropeStyle(/g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's/GoogleFonts\.montserrat(/AppText.manropeStyle(/g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's/GoogleFonts\.manrope(/AppText.manropeStyle(/g' {} \;
```

## Benefits

1. **Consistency**: All text uses the same Manrope font family
2. **Maintainability**: Central location for text styling changes
3. **Theme Support**: Automatic adaptation to dark/light themes
4. **Performance**: Reduced code duplication and imports
5. **Scalability**: Easy to add new text styles or modify existing ones

## Best Practices

1. **Use Context-Aware Styles**: Prefer `AppTextStyles` methods that take context for theme awareness
2. **Consistent Naming**: Use semantic names (title, subtitle, body) rather than size-based names
3. **Avoid Hardcoded Colors**: Use theme colors or context-aware methods
4. **Test Both Themes**: Ensure text looks good in both light and dark modes
5. **Document Custom Styles**: Add comments for any custom styling decisions

## Troubleshooting

### Common Issues:

1. **Import Errors**: Ensure the correct relative path to the utilities
2. **Context Errors**: Some methods require BuildContext - pass it from the widget
3. **Color Issues**: Use theme-aware colors instead of hardcoded values
4. **Font Loading**: Ensure google_fonts package is properly configured

### Quick Fixes:

```dart
// If context is not available
Text('Title', style: AppText.heading4.copyWith(color: Colors.black87))

// If you need theme awareness without context
final isDark = Theme.of(context).brightness == Brightness.dark;
Text('Title', style: AppText.heading4.copyWith(
  color: isDark ? Colors.white : Colors.black87,
))
```

## Migration Checklist

- [ ] Import text utilities in all relevant files
- [ ] Replace GoogleFonts.inter with AppText.manropeStyle
- [ ] Replace GoogleFonts.montserrat with AppText.manropeStyle  
- [ ] Replace GoogleFonts.manrope with AppText.manropeStyle
- [ ] Update hardcoded TextStyle with predefined styles
- [ ] Test in both light and dark themes
- [ ] Verify text readability and consistency
- [ ] Remove unused GoogleFonts imports
- [ ] Update any custom text styling to use utilities

This systematic approach ensures consistent Manrope font usage throughout the entire application while maintaining code quality and theme compatibility.
