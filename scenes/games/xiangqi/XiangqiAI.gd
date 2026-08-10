extends RefCounted
class_name XiangqiAI
## Simple AI: material + position + negamax with alpha-beta. Good enough for human vs AI.

const VALUES: Dictionary = {
	XiangqiLogic.KING: 10000,
	XiangqiLogic.ADVISOR: 120,
	XiangqiLogic.ELEPHANT: 120,
	XiangqiLogic.HORSE: 270,
	XiangqiLogic.CHARIOT: 500,
	XiangqiLogic.CANNON: 280,
	XiangqiLogic.PAWN: 80,
}

static func evaluate(b: Array, perspective_side: int) -> int:
	var score: int = 0
	for y in range(10):
		for x in range(9):
			var p: int = b[y][x]
			if p == 0:
				continue
			var v: int = VALUES.get(XiangqiLogic.piece_type(p), 0)
			# Pawn bonus after crossing river
			if XiangqiLogic.piece_type(p) == XiangqiLogic.PAWN:
				if XiangqiLogic.crossed_river(y, XiangqiLogic.piece_side(p)):
					v += 30
				# Central pawn bonus
				if x >= 3 and x <= 5:
					v += 10
			if XiangqiLogic.piece_side(p) == perspective_side:
				score += v
			else:
				score -= v
	# Check bonus
	var enemy: int = XiangqiLogic.BLACK if perspective_side == XiangqiLogic.RED else XiangqiLogic.RED
	if XiangqiLogic.is_in_check(b, enemy):
		score += 25
	if XiangqiLogic.is_in_check(b, perspective_side):
		score -= 40
	return score

static func _negamax(b: Array, side: int, depth: int, alpha: int, beta: int, root_side: int) -> int:
	if depth == 0:
		return evaluate(b, root_side)
	var moves: Array = XiangqiLogic.all_legal_moves(b, side)
	if moves.is_empty():
		if XiangqiLogic.is_in_check(b, side):
			return -9000 - depth # checkmate — prefer faster mate
		return 0 # stalemate
	# Simple move ordering: captures first
	moves.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		var ca: bool = b[b2["to"].y][b2["to"].x] != 0 if false else false
		# Capture heuristic: victim value
		var cap_a: int = VALUES.get(XiangqiLogic.piece_type(b[a["to"].y][a["to"].x]), 0) if b[a["to"].y][a["to"].x] != 0 else 0
		var cap_b: int = VALUES.get(XiangqiLogic.piece_type(b[b2["to"].y][b2["to"].x]), 0) if b[b2["to"].y][b2["to"].x] != 0 else 0
		return cap_a > cap_b
	)
	var best: int = -999999
	var enemy: int = XiangqiLogic.BLACK if side == XiangqiLogic.RED else XiangqiLogic.RED
	for m in moves:
		var nb: Array = XiangqiLogic.apply_on_clone(b, m["from"].x, m["from"].y, m["to"].x, m["to"].y)
		var s: int = -_negamax(nb, enemy, depth - 1, -beta, -alpha, root_side)
		if s > best:
			best = s
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best

static func best_move(b: Array, side: int, depth: int = 2) -> Dictionary:
	var moves: Array = XiangqiLogic.all_legal_moves(b, side)
	if moves.is_empty():
		return {}
	if moves.size() == 1:
		return moves[0]
	# Shuffle a bit for variety when equal
	moves.shuffle()
	var best_move: Dictionary = moves[0]
	var best_score: int = -999999
	var enemy: int = XiangqiLogic.BLACK if side == XiangqiLogic.RED else XiangqiLogic.RED
	# Order by capture value for root too
	moves.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		var cap_a: int = VALUES.get(XiangqiLogic.piece_type(b[a["to"].y][a["to"].x]), 0) if b[a["to"].y][a["to"].x] != 0 else 0
		var cap_b: int = VALUES.get(XiangqiLogic.piece_type(b[b2["to"].y][b2["to"].x]), 0) if b[b2["to"].y][b2["to"].x] != 0 else 0
		return cap_a > cap_b
	)
	for m in moves:
		var nb: Array = XiangqiLogic.apply_on_clone(b, m["from"].x, m["from"].y, m["to"].x, m["to"].y)
		var s: int = -_negamax(nb, enemy, depth - 1, -999999, 999999, side)
		if s > best_score:
			best_score = s
			best_move = m
	return best_move
