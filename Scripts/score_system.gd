class_name ScoreSystem
extends RefCounted

## Sistema de Pontuação e Regras de Combo (SRS Adicionais Seção 2.1)
## Responsável pelo cálculo matemático da pontuação base, multiplicador de combo consecutivo,
## penalidades de alvos amigos/civis, tempo de decaimento e precisão balística.

signal pontuacao_alterada(pontuacao_atual: int, delta_pontos: int)
signal combo_alterado(combo_atual: int, multiplicador: float)
signal acerto_processado(tipo_alvo: int, pontos_ganhos: int, multiplicador: float)

# Configurações normativas de pontuação (SRS 2.1)
var base_enemy_points: int = 100
var base_friendly_penalty: int = -200
var max_combo_multiplier: float = 4.0
var combo_multiplier_step: float = 0.5
var combo_timeout: float = 4.0
var allow_negative_score: bool = false

# Estado dinâmico
var score: int = 0
var combo: int = 0
var combo_multiplier: float = 1.0
var combo_decay_timer: float = 0.0

var total_shots: int = 0
var total_hits: int = 0
var enemy_hits: int = 0
var friendly_hits: int = 0


## Processa impacto em alvo conforme as regras normativas (SRS 2.1)
## tipo_alvo: 0 = ENEMY, 1 = FRIENDLY
func registrar_acerto(tipo_alvo: int, pontos_base_custom: int = 0) -> Dictionary:
	total_hits += 1
	var delta_pontos: int = 0
	var mult_aplicado: float = 1.0

	if tipo_alvo == 0:
		# Acerto em Inimigo (ENEMY):
		# +100 pontos base, incrementa streak de combo
		enemy_hits += 1
		combo += 1
		combo_multiplier = minf(max_combo_multiplier, 1.0 + float(combo - 1) * combo_multiplier_step)
		combo_decay_timer = combo_timeout
		mult_aplicado = combo_multiplier

		var pontos_base = pontos_base_custom if pontos_base_custom > 0 else base_enemy_points
		delta_pontos = calcular_pontos_ganhos(pontos_base, mult_aplicado)
		score += delta_pontos

		pontuacao_alterada.emit(score, delta_pontos)
		combo_alterado.emit(combo, combo_multiplier)
		acerto_processado.emit(tipo_alvo, delta_pontos, mult_aplicado)
	else:
		# Acerto em Amigo/Civil (FRIENDLY):
		# -200 pontos de penalidade, reseta streak e multiplicador para 1.0x
		friendly_hits += 1
		_reset_combo()

		var penalidade = pontos_base_custom if pontos_base_custom < 0 else base_friendly_penalty
		delta_pontos = penalidade
		if allow_negative_score:
			score += delta_pontos
		else:
			score = maxi(0, score + delta_pontos)

		pontuacao_alterada.emit(score, delta_pontos)
		acerto_processado.emit(tipo_alvo, delta_pontos, 1.0)

	return {
		"tipo_alvo": tipo_alvo,
		"delta_pontos": delta_pontos,
		"multiplicador": mult_aplicado,
		"score_atual": score,
		"combo_atual": combo
	}


## Fórmula: Pontos Ganhos = Pontos Base * Multiplicador de Combo (SRS 2.1)
func calcular_pontos_ganhos(pontos_base: int, multiplicador: float) -> int:
	return int(round(float(pontos_base) * multiplicador))


## Disparo no vazio / erro (SRS 2.1)
## Reduz gradualmente o tempo do combo
func registrar_erro(reducao_segundos: float = 1.0) -> void:
	if combo > 0:
		combo_decay_timer = maxf(0.0, combo_decay_timer - reducao_segundos)
		if combo_decay_timer <= 0.0:
			_reset_combo()


func register_miss(reduction_seconds: float = 1.0) -> void:
	registrar_erro(reduction_seconds)


## Registra tiros efetuados para cálculo de precisão (SRS 2.2)
func registrar_disparo(quantidade: int = 1) -> void:
	total_shots += quantidade


func register_shot(count: int = 1) -> void:
	registrar_disparo(count)


## Atualiza temporizador do combo a cada frame
func atualizar_tempo(delta: float) -> void:
	if combo > 0:
		combo_decay_timer -= delta
		if combo_decay_timer <= 0.0:
			_reset_combo()


func _reset_combo() -> void:
	combo = 0
	combo_multiplier = 1.0
	combo_decay_timer = 0.0
	combo_alterado.emit(0, 1.0)


## Precisão (%) = (Total de Acertos / Total de Tiros Disparados) * 100 (SRS 2.2)
func calcular_precisao() -> float:
	if total_shots <= 0:
		return 0.0
	return (float(total_hits) / float(total_shots)) * 100.0


func get_accuracy() -> float:
	return calcular_precisao()


## Zera pontuações e estatísticas
func zerar() -> void:
	var old_score = score
	score = 0
	combo = 0
	combo_multiplier = 1.0
	combo_decay_timer = 0.0

	total_shots = 0
	total_hits = 0
	enemy_hits = 0
	friendly_hits = 0

	pontuacao_alterada.emit(0, -old_score)
	combo_alterado.emit(0, 1.0)


func reset() -> void:
	zerar()
