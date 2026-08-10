extends RefCounted
class_name ApplePalette
## Semantic colors derived from Apple Human Interface Guidelines.
## Light appearance defaults; dark appearance can be derived by swapping
## background/grouped values — kept as constants for determinism in Godot.

# Backgrounds
const BG: Color = Color("#F2F2F7")                 # systemGroupedBackground
const BG_GROUPED: Color = Color("#FFFFFF")          # secondaryGroupedBackground (card)
const BG_ELEVATED: Color = Color("#FFFFFF")         # elevated card / sheet

# Text
const LABEL: Color = Color("#000000")               # label (87% opacity in real HIG — use full for contrast)
const LABEL_SECONDARY: Color = Color("#3C3C43", 0.6) # secondaryLabel (60%)
const LABEL_TERTIARY: Color = Color("#3C3C43", 0.3)  # tertiaryLabel (30%)

# Accent
const BLUE: Color = Color("#007AFF")                # systemBlue
const BLUE_PRESSED: Color = Color("#0051D5")
const GRAY_FILL: Color = Color("#E5E5EA")           # systemGray5 — subtle fill for secondary button
const GRAY_FILL_PRESSED: Color = Color("#D1D1D6")

# Separators & chrome
const SEPARATOR: Color = Color("#3C3C43", 0.18)     # separator (opaque variant of 0.08)
const SHADOW: Color = Color("#000000", 0.08)

# Status
const GREEN: Color = Color("#34C759")
const RED: Color = Color("#FF3B30")
const ORANGE: Color = Color("#FF9500")

# Board materials (Apple-like: warm paper, ink)
const BOARD_PAPER: Color = Color("#FAF7F0")
const BOARD_LINE: Color = Color("#1C1C1E", 0.55)
const BOARD_LINE_SOFT: Color = Color("#1C1C1E", 0.22)
const BOARD_RIVER_TINT: Color = Color("#007AFF", 0.04)
