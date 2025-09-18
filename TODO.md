# TODO List for TummyTrack Updates

## B. Update _saveTummyTimeSession
- [x] Add _getPressedButtons() function in tummytime_screen.dart
- [x] Update _saveTummyTimeSession to save 'matras_buttons' as list instead of 'matras_button'

## C. Small Fixes
- [ ] Change _getBabySessionsStream in history_screen.dart to orderBy('date', descending: true)
- [ ] Update _showSessionDetails in history_screen.dart to display joined list of matras buttons
- [ ] Add loading indicator with StreamBuilder in matras grid in tummytime_screen.dart

## Followup
- [ ] Test the changes
- [ ] Verify no errors
