extends RefCounted
class_name ApplePalette
## CardMaster — Enterprise Dark-Luxury palette.
## 深海黑 + 鎏金 + 羊皮纸棋盘，面向商业化顶级水准。
## 保留类名 ApplePalette 以兼容既有引用，实际为全新的企业级色板。

# ── App shell ──────────────────────────────────────────────
const BG: Color = Color("#0A0E14")                    # ink — app canvas
const BG_DEEP: Color = Color("#06080D")               # deeper ink
const BG_ELEVATED: Color = Color("#121821")           # elevated surface
const BG_GROUPED: Color = Color("#161E2A")            # card surface
const SURFACE_GLASS: Color = Color("#FFFFFF", 0.06)   # glass fill
const SURFACE_GLASS_STRONG: Color = Color("#FFFFFF", 0.09)

# ── Lines / dividers ─────────────────────────────────────
const SEPARATOR: Color = Color("#FFFFFF", 0.08)
const SEPARATOR_STRONG: Color = Color("#FFFFFF", 0.13)
const HAIRLINE_GOLD: Color = Color("#D4A574", 0.22)
const HAIRLINE_GOLD_STRONG: Color = Color("#D4A574", 0.38)
const SHADOW: Color = Color("#000000", 0.42)
const SHADOW_SOFT: Color = Color("#000000", 0.22)
const GLOW_GOLD: Color = Color("#D4A574", 0.16)
const GLOW_TEAL: Color = Color("#2EC4B6", 0.14)

# ── Typography ───────────────────────────────────────────
const LABEL: Color = Color("#F2EDE6")                 # warm white
const LABEL_SECONDARY: Color = Color("#9AA3B2")       # muted slate
const LABEL_TERTIARY: Color = Color("#6B7585")
const LABEL_DIM: Color = Color("#4A5566")
const LABEL_ON_DARK: Color = Color("#E8EEF6")
const LABEL_GOLD: Color = Color("#D4A574")
const LABEL_GOLD_BRIGHT: Color = Color("#F0C98A")

# ── Brand / Accent ───────────────────────────────────────
const BLUE: Color = Color("#D4A574")                  # repurposed: gold is primary CTA
const BLUE_PRESSED: Color = Color("#B88A5A")
const GOLD: Color = Color("#D4A574")
const GOLD_BRIGHT: Color = Color("#F0C98A")
const GOLD_DEEP: Color = Color("#8C6A3A")
const CHAMPAGNE: Color = Color("#F5E6CC")
const TEAL: Color = Color("#2EC4B6")
const TEAL_DEEP: Color = Color("#1A9E93")
const TEAL_SOFT: Color = Color("#2EC4B6", 0.12)

# Keep old names for compat
const GRAY_FILL: Color = Color("#1E2937")
const GRAY_FILL_PRESSED: Color = Color("#243447")

# ── Status ───────────────────────────────────────────────
const GREEN: Color = Color("#2EC4B6")
const RED: Color = Color("#E8583A")
const ORANGE: Color = Color("#E8A838")
const SUCCESS: Color = Color("#2EC4B6")
const WARNING: Color = Color("#E8A838")
const DANGER: Color = Color("#E8583A")

# ── Board — luxury wood / parchment ──────────────────────
const BOARD_PAPER: Color = Color("#F7F0E0")           # warm parchment
const BOARD_PAPER_MID: Color = Color("#EDE1C6")
const BOARD_PAPER_SHADOW: Color = Color("#D9C9A3")
const BOARD_FRAME: Color = Color("#1A1208")           # dark walnut frame
const BOARD_FRAME_HIGHLIGHT: Color = Color("#D4A574")
const BOARD_LINE: Color = Color("#2B1E0F", 0.72)
const BOARD_LINE_SOFT: Color = Color("#2B1E0F", 0.28)
const BOARD_RIVER_TINT: Color = Color("#2EC4B6", 0.06)
const BOARD_RIVER_INK: Color = Color("#2B1E0F", 0.42)
const BOARD_DOT: Color = Color("#2B1E0F", 0.55)

# ── Piece ────────────────────────────────────────────────
const PIECE_RED: Color = Color("#C0392B")
const PIECE_RED_RING: Color = Color("#E74C3C")
const PIECE_RED_INLAY: Color = Color("#FFF6EE")
const PIECE_BLACK: Color = Color("#1A1F2B")
const PIECE_BLACK_RING: Color = Color("#2F3A4A")
const PIECE_BLACK_INLAY: Color = Color("#EEF2F7")
const PIECE_SHADOW: Color = Color("#000000", 0.26)
const PIECE_GOLD_RING: Color = Color("#D4A574")

# ── Lobby cover tints ────────────────────────────────────
const COVER_XIANGQI_A: Color = Color("#1B2A3A")
const COVER_XIANGQI_B: Color = Color("#3A2A1A")
const COVER_CHESS_A: Color = Color("#1E2E2A")
const COVER_CHESS_B: Color = Color("#2A2E3A")
const COVER_GO_A: Color = Color("#2A2420")
const COVER_GO_B: Color = Color("#1A2332")
