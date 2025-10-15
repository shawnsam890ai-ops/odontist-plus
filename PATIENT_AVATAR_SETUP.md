# How to Add the Patient Avatar Icon

## Quick Steps

1. **Save the patient avatar image** you provided earlier to:
   ```
   assets/images/patient_avatar.png
   ```

2. **The card will automatically use it** - no code changes needed!

## Current Behavior

- ✅ If `patient_avatar.png` exists → Shows your custom patient icon
- ✅ If missing → Shows a fallback person icon (Icons.person)
- ✅ Card is fully responsive and auto-scalable

## Technical Details

The `PatientOverviewCard` widget:
- Checks if the asset exists at runtime
- Uses `rootBundle.load()` to verify the asset
- Falls back gracefully to a built-in icon if not found
- Displays total patient count from `PatientProvider`
- Scales between 140-260px width based on available space

## Alternative: Use a Different Icon

If you want to use a different icon source, edit:
```dart
lib/ui/pages/dashboard_page.dart
```

In the `_PatientOverviewCardWrapper` class, change the `avatar` parameter.
