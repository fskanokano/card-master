extends RefCounted
class_name XiangqiAI
const XiangqiLogicRef = preload("res://scenes/games/xiangqi/XiangqiLogic.gd")
## Simple AI: material + position + negamax with alpha-beta. Good enough for human vs AI.

static func _values() -> Dictionary:
	return {
	XiangqiLogicRef.KING: 10000,
	XiangqiLogicRef.ADVISOR: 120,
	XiangqiLogicRef.ELEPHANT: 120,
	XiangqiLogicRef.HORSE: 270,
	XiangqiLogicRef.CHARIOT: 500,
	XiangqiLogicRef.CANNON: 280,
	XiangqiLogicRef.PAWN: 80,
}

static func evaluate(b: Array, perspective_side: int) -> int:
	var score: int = 0
	for y in range(10):
		for x in range(9):
			var p: int = b[y][x]
			if p == 0:
				continue
			var v: int = _values().get(XiangqiLogicRef.piece_type(p), 0)
			# Pawn bonus after crossing river
			if XiangqiLogicRef.piece_type(p) == XiangqiLogicRef.PAWN:
				if XiangqiLogicRef.crossed_river(y, XiangqiLogicRef.piece_side(p)):
					v += 30
				# Central pawn bonus
				if x >= 3 and x <= 5:
					v += 10
			if XiangqiLogicRef.piece_side(p) == perspective_side:
				score += v
			else:
				score -= v
	# Check bonus
	var enemy: int = XiangqiLogicRef.BLACK if perspective_side == XiangqiLogicRef.RED else XiangqiLogicRef.RED
	if XiangqiLogicRef.is_in_check(b, enemy):
		score += 25
	if XiangqiLogicRef.is_in_check(b, perspective_side):
		score -= 40
	return score

static func _negamax(b: Array, side: int, depth: int, alpha: int, beta: int, root_side: int) -> int:
	if depth == 0:
		return evaluate(b, root_side)
	var moves: Array = XiangqiLogicRef.all_legal_moves(b, side)
	if moves.is_empty():
		if XiangqiLogicRef.is_in_check(b, side):
			return -9000 - depth # checkmate — prefer faster mate
		return 0 # stalemate
	# Simple move ordering: captures first
	moves.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		var ca: bool = b[b2["to"].y][b2["to"].x] != 0 if false else false
		# Capture heuristic: victim value
		var cap_a: int = _values().get(XiangqiLogicRef.piece_type(b[a["to"].y][a["to"].x]), 0) if b[a["to"].y][a["to"].x] != 0 else 0
		var cap_b: int = _values().get(XiangqiLogicRef.piece_type(b[b2["to"].y][b2["to"].x]), 0) if b[b2["to"].y][b2["to"].x] != 0 else 0
		return cap_a > cap_b
	)
	var best: int = -999999
	var enemy: int = XiangqiLogicRef.BLACK if side == XiangqiLogicRef.RED else XiangqiLogicRef.RED
	for m in moves:
		var nb: Array = XiangqiLogicRef.apply_on_clone(b, m["from"].x, m["from"].y, m["to"].x, m["to"].y)
		var s: int = -_negamax(nb, enemy, depth - 1, -beta, -alpha, root_side)
		if s > best:
			best = s
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best

static func best_move(b: Array, side: int, depth: int = 2) -> Dictionary:
	var moves: Array = XiangqiLogicRef.all_legal_moves(b, side)
	if moves.is_empty():
		return {}
	if moves.size() == 1:
		return moves[0]
	# Shuffle a bit for variety when equal
	moves.shuffle()
	var best_move: Dictionary = moves[0]
	var best_score: int = -999999
	var enemy: int = XiangqiLogicRef.BLACK if side == XiangqiLogicRef.RED else XiangqiLogicRef.RED
	# Order by capture value for root too
	moves.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		var cap_a: int = _values().get(XiangqiLogicRef.piece_type(b[a["to"].y][a["to"].x]), 0) if b[a["to"].y][a["to"].x] != 0 else 0
		var cap_b: int = _values().get(XiangqiLogicRef.piece_type(b[b2["to"].y][b2["to"].x]), 0) if b[b2["to"].y][b2["to"].x] != 0 else 0
		return cap_a > cap_b
	)
	for m in moves:
		var nb: Array = XiangqiLogicRef.apply_on_clone(b, m["from"].x, m["from"].y, m["to"].x, m["to"].y)
		var s: int = -_negamax(nb, enemy, depth - 1, -999999, 999999, side)
		if s > best_score:
			best_score = s
			best_move = m
	return best_move
