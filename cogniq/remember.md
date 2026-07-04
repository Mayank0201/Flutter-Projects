# Rulebook: Ensuring Lag-Free & High-Performance Flutter Games

This document contains mandatory rules and guidelines that the Antigravity agent (and any other coding assistants) MUST read and follow when modifying or creating games in this codebase. Following these rules prevents jitter, touch lag, and frame drops (jank) during drag, pan, or tap operations.

---

## 🚀 1. The Golden Rule: Avoid Unconditional `setState` in Gesture Loops
- **Never** call `setState()` unconditionally inside high-frequency touch callbacks such as `onPanUpdate`, `onPanStart`, or `onPointerMove`.
- **Reason**: `setState()` triggers a full rebuild of the widget's `build()` method. When called at 60Hz or 120Hz (on high-refresh-rate screens), this causes severe frame drops because the entire screen layout, text, icons, and buttons are rebuilt and repainted.
- **Rules**:
  1. If updating a drag-line or cursor position, use a `ValueNotifier` or a `repaint` listener on a `CustomPainter` instead of `setState`.
  2. If updating grid selections, compare the newly computed selection to the current state. **Only** call `setState` if a boundary is crossed and a state change actually occurred.

---

## 🎨 2. Isolate Dynamic Painters and Grids using `RepaintBoundary`
- **Rule**: Always wrap a `CustomPaint`, `GridView`, or custom grid widget where dragging or path-drawing occurs in a `RepaintBoundary`.
- **Reason**: In Flutter, a repaint boundary creates a separate display list. This prevents paint updates in the drag area from dirtying and repainting the entire screen (e.g., the AppBar, static descriptions, background decorations, and control buttons).
- **Example**:
  ```dart
  RepaintBoundary(
    child: GestureDetector(
      onPanUpdate: ...
      child: CustomPaint(
        painter: MyGamePainter(...),
      ),
    ),
  )
  ```

---

## ⚡ 3. Optimize Custom Painters
- **Rule 3a: Never return `true` unconditionally in `shouldRepaint`**
  Always implement proper comparisons in `shouldRepaint(CustomPainter oldDelegate)` to only repaint when relevant parameters change.
  ```dart
  // AVOID THIS:
  @override
  bool shouldRepaint(MyPainter oldDelegate) => true;

  // DO THIS:
  @override
  bool shouldRepaint(MyPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
           oldDelegate.currentColor != currentColor;
  }
  ```
- **Rule 3b: Leverage the `repaint` Parameter**
  Pass a `Listenable` (such as an `AnimationController` or `ValueNotifier`) directly to the `super(repaint: ...)` constructor of the `CustomPainter`.
  - This tells Flutter to repaint the canvas automatically when the listenable ticks/notifies, **without** rebuilding any parent widgets or calling `setState`.
  ```dart
  class DragLinePainter extends CustomPainter {
    final ValueNotifier<Offset?> dragNotifier;
    
    DragLinePainter({required this.dragNotifier}) : super(repaint: dragNotifier);
    
    @override
    void paint(Canvas canvas, Size size) {
      final dragOffset = dragNotifier.value;
      if (dragOffset != null) {
        // Draw drag line to dragOffset
      }
    }
  }
  ```

---

## ⏱️ 4. Avoid Animation Listeners Calling `setState`
- **Rule**: Avoid adding listeners to `AnimationController` that merely do `..addListener(() { setState(() {}); })` for drag effects.
- **Reason**: This forces a full widget tree rebuild on every frame of the animation.
- **Alternative**: Pass the animation controller directly to the `repaint` property of your `CustomPainter` (as shown in Rule 3b), or use an `AnimatedBuilder` that wraps only the minimal widget that needs updating.

---

## 💾 5. Defer Heavy Side-Effects and Disk Writes
- **Rule**: Never run database operations, disk writes (e.g. `SharedPreferences`), or heavy algorithms (like O(N²) win checks) inside `onPanUpdate` or `setState` during active dragging.
- **Action**:
  - Store temporary changes in memory.
  - Defer disk writes (`_saveState()`) and final game verification to `onPanEnd` or `onPanCancel`.
  - If a win-condition check is lightweight, you may run it, but guard/debounce it if it scales quadratically.

---

## 🔍 6. Keep Hot Paths & Paint Loops O(1)
- **Rule**: Do not perform linear scans (e.g., `list.contains()`, `list.any()`) in loops inside `paint()` methods or grid building `itemBuilder` blocks.
- **Action**:
  - Keep state tracking lists small.
  - If lookups are needed frequently (e.g., checking if a grid coordinate `(r, c)` is selected), build a `Set` or `HashSet` beforehand or maintain a parallel `Set` of selected coordinates for O(1) `.contains()` lookups.

---

## Checklist for Future Game Code Reviews
Before committing a new game, verify:
- [.] No `setState()` is executed on every frame of a drag (unless a logical tile change occurred).
- [.] Drag coordinates are passed via `ValueNotifier` or similar, rather than page-state.
- [.] Grid or canvas is wrapped in a `RepaintBoundary`.
- [.] The `CustomPainter` has a proper `shouldRepaint` implementation.
- [.] Animation ticks do not trigger page-wide rebuilds.
- [.] Disk writes (`SharedPreferences`) are deferred to `onPanEnd`.
