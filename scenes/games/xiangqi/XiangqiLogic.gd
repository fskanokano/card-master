extends RefCounted
class_name XiangqiLogic
## Pure rules for Chinese Chess (9x10). No Node dependencies — testable in isolation.
## Board coords: x 0..8 (file), y 0..9 (rank). y=0 is Black back rank, y=9 is Red back rank.
## Pieces encoded as int constants below; board is Array[10][9].

# Piece types (absolute)
const EMPTY := 0
const KING := 1
const ADVISOR := 2
const ELEPHANT := 3
const HORSE := 4
const CHARIOT := 5
const CANNON := 6
const PAWN := 7

# Sides
const RED := 1
const BLACK := 2

static func piece_side(p: int) -> int:
	if p == 0:
		return 0
	return RED if p > 0 else BLACK

static func piece_type(p: int) -> int:
	return abs(p)

static func make_piece(side: int, type: int) -> int:
	return type if side == RED else -type

static func is_red(p: int) -> bool:
	return p > 0

static func is_black(p: int) -> bool:
	return p < 0

static func inside_board(x: int, y: int) -> bool:
	return x >= 0 and x < 9 and y >= 0 and y < 10

static func inside_palace(x: int, y: int, side: int) -> bool:
	if x < 3 or x > 5:
		return false
	if side == RED:
		return y >= 7 and y <= 9
	return y >= 0 and y <= 2

static func crossed_river(y: int, side: int) -> bool:
	if side == RED:
		return y < 5
	return y > 4

# Initial board
static func initial_board() -> Array:
	var b: Array = []
	for y in range(10):
		var row: Array = []
		for x in range(9):
			row.append(EMPTY)
		b.append(row)
	# Black (top)
	b[0][0] = make_piece(BLACK, CHARIOT); b[0][1] = make_piece(BLACK, HORSE); b[0][2] = make_piece(BLACK, ELEPHANT); b[0][3] = make_piece(BLACK, ADVISOR); b[0][4] = make_piece(BLACK, KING); b[0][5] = make_piece(BLACK, ADVISOR); b[0][6] = make_piece(BLACK, ELEPHANT); b[0][7] = make_piece(BLACK, HORSE); b[0][8] = make_piece(BLACK, CHARIOT)
	b[2][1] = make_piece(BLACK, CANNON); b[2][7] = make_piece(BLACK, CANNON)
	b[3][0] = make_piece(BLACK, PAWN); b[3][2] = make_piece(BLACK, PAWN); b[3][4] = make_piece(BLACK, PAWN); b[3][6] = make_piece(BLACK, PAWN); b[3][8] = make_piece(BLACK, PAWN)
	# Red (bottom)
	b[9][0] = make_piece(RED, CHARIOT); b[9][1] = make_piece(RED, HORSE); b[9][2] = make_piece(RED, ELEPHANT); b[9][3] = make_piece(RED, ADVISOR); b[9][4] = make_piece(RED, KING); b[9][5] = make_piece(RED, ADVISOR); b[9][6] = make_piece(RED, ELEPHANT); b[9][7] = make_piece(RED, HORSE); b[9][8] = make_piece(RED, CHARIOT)
	b[7][1] = make_piece(RED, CANNON); b[7][7] = make_piece(RED, CANNON)
	b[6][0] = make_piece(RED, PAWN); b[6][2] = make_piece(RED, PAWN); b[6][4] = make_piece(RED, PAWN); b[6][6] = make_piece(RED, PAWN); b[6][8] = make_piece(RED, PAWN)
	return b

static func clone_board(b: Array) -> Array:
	var out: Array = []
	for row in b:
		out.append(row.duplicate())
	return out

## Generate pseudo-legal moves (without self-check filter) for piece at (x,y).
static func pseudo_moves(b: Array, x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p: int = b[y][x]
	if p == EMPTY:
		return out
	var side: int = piece_side(p)
	var typ: int = piece_type(p)
	match typ:
		KING:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				if not inside_board(nx, ny): continue
				if not inside_palace(nx, ny, side): continue
				if b[ny][nx] != EMPTY and piece_side(b[ny][nx]) == side: continue
				out.append(Vector2i(nx, ny))
		ADVISOR:
			for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				if not inside_board(nx, ny): continue
				if not inside_palace(nx, ny, side): continue
				if b[ny][nx] != EMPTY and piece_side(b[ny][nx]) == side: continue
				out.append(Vector2i(nx, ny))
		ELEPHANT:
			for d in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				if not inside_board(nx, ny): continue
				# Cannot cross river
				if crossed_river(ny, side): continue
				var mx: int = x + d.x / 2; var my: int = y + d.y / 2
				if b[my][mx] != EMPTY: continue # blocked eye
				if b[ny][nx] != EMPTY and piece_side(b[ny][nx]) == side: continue
				out.append(Vector2i(nx, ny))
		HORSE:
			var moves: Array = [[1, 2, 0, 1], [2, 1, 1, 0], [2, -1, 1, 0], [1, -2, 0, -1], [-1, -2, 0, -1], [-2, -1, -1, 0], [-2, 1, -1, 0], [-1, 2, 0, 1]]
			for m in moves:
				var nx: int = x + m[0]; var ny: int = y + m[1]
				if not inside_board(nx, ny): continue
				var bx: int = x + m[2]; var by: int = y + m[3]
				if b[by][bx] != EMPTY: continue # hobbling leg
				if b[ny][nx] != EMPTY and piece_side(b[ny][nx]) == side: continue
				out.append(Vector2i(nx, ny))
		CHARIOT:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				while inside_board(nx, ny):
					if b[ny][nx] == EMPTY:
						out.append(Vector2i(nx, ny))
					else:
						if piece_side(b[ny][nx]) != side:
							out.append(Vector2i(nx, ny))
						break
					nx += d.x; ny += d.y
		CANNON:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				# Non-capture: slide like chariot until blocked
				while inside_board(nx, ny) and b[ny][nx] == EMPTY:
					out.append(Vector2i(nx, ny))
					nx += d.x; ny += d.y
				if not inside_board(nx, ny):
					continue
				# Need exactly one screen then capture
				nx += d.x; ny += d.y
				while inside_board(nx, ny):
					if b[ny][nx] != EMPTY:
						if piece_side(b[ny][nx]) != side:
							out.append(Vector2i(nx, ny))
						break
					nx += d.x; ny += d.y
		PAWN:
			var forward: int = -1 if side == RED else 1
			var nx: int = x; var ny: int = y + forward
			if inside_board(nx, ny) and (b[ny][nx] == EMPTY or piece_side(b[ny][nx]) != side):
				out.append(Vector2i(nx, ny))
			if crossed_river(y, side):
				for dx in [-1, 1]:
					nx = x + dx; ny = y
					if inside_board(nx, ny) and (b[ny][nx] == EMPTY or piece_side(b[ny][nx]) != side):
						out.append(Vector2i(nx, ny))
	return out

static func find_king(b: Array, side: int) -> Vector2i:
	for y in range(10):
		for x in range(9):
			if b[y][x] != EMPTY and piece_type(b[y][x]) == KING and piece_side(b[y][x]) == side:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func kings_face_each_other(b: Array) -> bool:
	var rk := find_king(b, RED)
	var bk := find_king(b, BLACK)
	if rk.x == -1 or bk.x == -1:
		return false
	if rk.x != bk.x:
		return false
	var x: int = rk.x
	var y_min: int = min(rk.y, bk.y) + 1
	var y_max: int = max(rk.y, bk.y)
	for y in range(y_min, y_max):
		if b[y][x] != EMPTY:
			return false
	return true

static func is_in_check(b: Array, side: int) -> bool:
	if kings_face_each_other(b):
		return true
	var kpos := find_king(b, side)
	if kpos.x == -1:
		return false
	var enemy: int = BLACK if side == RED else RED
	for y in range(10):
		for x in range(9):
			if b[y][x] == EMPTY or piece_side(b[y][x]) != enemy:
				continue
			var moves: Array[Vector2i] = pseudo_moves(b, x, y)
			for m in moves:
				if m == kpos:
					# For chariot/cannon the pseudo already handles blocking; but cannon screen logic is correct
					return true
	return false

## Apply move on a cloned board and return it (no validation).
static func apply_on_clone(b: Array, fx: int, fy: int, tx: int, ty: int) -> Array:
	var nb := clone_board(b)
	nb[ty][tx] = nb[fy][fx]
	nb[fy][fx] = EMPTY
	return nb

static func is_legal(b: Array, fx: int, fy: int, tx: int, ty: int, side: int) -> bool:
	if not inside_board(fx, fy) or not inside_board(tx, ty):
		return false
	var p: int = b[fy][fx]
	if p == EMPTY or piece_side(p) != side:
		return false
	if b[ty][tx] != EMPTY and piece_side(b[ty][tx]) == side:
		return false
	var moves: Array[Vector2i] = pseudo_moves(b, fx, fy)
	var found := false
	for m in moves:
		if m.x == tx and m.y == ty:
			found = true
			break
	if not found:
		return false
	var nb := apply_on_clone(b, fx, fy, tx, ty)
	if kings_face_each_other(nb):
		return false
	if is_in_check(nb, side):
		return false
	return true

static func all_legal_moves(b: Array, side: int) -> Array:
	# Array of {"from": Vector2i, "to": Vector2i}
	var out: Array = []
	for y in range(10):
		for x in range(9):
			if b[y][x] == EMPTY or piece_side(b[y][x]) != side:
				continue
			var pseudos: Array[Vector2i] = pseudo_moves(b, x, y)
			for to in pseudos:
				if is_legal(b, x, y, to.x, to.y, side):
					out.append({"from": Vector2i(x, y), "to": to})
	return out

static func is_checkmate(b: Array, side: int) -> bool:
	if not is_in_check(b, side):
		return false
	return all_legal_moves(b, side).is_empty()

static func is_stalemate_no_moves(b: Array, side: int) -> bool:
	return all_legal_moves(b, side).is_empty()
