# Implementation Plan - CogniQ Points Economy

This plan details the design and implementation of the universal Points Economy for CogniQ. It shifts the game from a system where hints are awarded directly per game to a points-based system where points are the global currency.

## User Review Required

> [!NOTE]
> - **Hint Conversion & Preservation**: Existing players will keep their current hint balances for all games. Point balance will start at 0, and points will apply to all new hint purchases.
> - **Point Value Rules**:
>   - **10 points** earned per level clear (applies to normal levels; daily challenges still award daily stars and hints as before or we can also grant points).
>   - **80 points** earned per rewarded video ad.
>   - **60 points** consumed to buy a hint for any game of the user's choice.
> - **Purchase UI**:
>   - A dialog/bottom sheet will show the user's current point balance and allow purchasing hints for any game.
>   - The purchase quantity can be adjusted using standard `+` and `-` buttons or typed directly into a text input.
>   - When attempting to use a hint in-game with a balance of `0`, the "Buy Hints" dialog will pop up automatically.

## Proposed Changes

### Component 1: State Management (PointManager)
---
#### [NEW] [point_manager.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/utils/point_manager.dart)
Create a point manager class to persist and query points balance using SharedPreferences.
- `static Future<int> getPoints()`
- `static Future<void> addPoints(int amount)`
- `static Future<bool> consumePoints(int amount)`

### Component 2: Adjust Reward System
---
#### [MODIFY] [hint_manager.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/utils/hint_manager.dart)
- Update `onLevelCleared` to award `10 points` using `PointManager.addPoints(10)` instead of a free hint every 5 levels.
- Update `onLevelCleared` to return `true` on every level completion to trigger the level completion snackbar/toast, which we will rename to show points earned.

#### [MODIFY] [ad_manager.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/utils/ad_manager.dart)
- If necessary, review rewarded ad integration to ensure it is generic and awards 80 points. (Currently it executes a callback `onRewardGranted(amount)`. We will adjust the call site to award 80 points).

### Component 3: UI Implementation
---
#### [NEW] [buy_hints_dialog.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/screens/buy_hints_dialog.dart)
Implement a beautiful, responsive hint purchasing dialog using standard outfit styling:
- **Drop-down** to select target game (pre-filled if opened from a specific game).
- **Text field** allowing users to type the hint count to purchase.
- **Increment/Decrement buttons** to adjust the count.
- **Dynamic Cost Display** showing the points cost (e.g. `120 points`).
- **Validation** ensuring input is a valid positive integer and user has sufficient points.
- **Ad Watch Option**: A shortcut button in this dialog to watch a rewarded ad directly to earn 80 points.

#### [MODIFY] [home_screen.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/screens/home_screen.dart)
- Replace "Earn Free Hints" profile tile action with opening the new `BuyHintsDialog` (which offers both point earnings via ads and hint purchases).
- Display point balance next to the user's name or in the top bar.

#### [MODIFY] [settings_screen.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/screens/settings_screen.dart)
- Replace the "Earn Free Hints" option with opening the `BuyHintsDialog`.

#### [MODIFY] [All Game Screens] (21 Files)
- Update the level clear callback to display `+10 Points earned!` instead of `Hint earned!`.
- Update the hint button behavior: when `hintCount == 0`, allow tapping the button to open the `BuyHintsDialog` (pre-filled with the current game) instead of disabling the button.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no syntax/type errors.

### Manual Verification
- Clear a level in a game and verify `+10 Points earned!` snackbar is shown, and points increment.
- Go to the points/hints menu, watch a rewarded ad, verify points increase by 80.
- Try purchasing hints:
  - Verify increment/decrement buttons work.
  - Verify typing a value works.
  - Verify buying updates the game's hint count and consumes points correctly.
  - Verify buying is blocked if user has insufficient points.
- Tap a hint button in a game with 0 hints, verify the buy dialog opens pre-selected to that game.
