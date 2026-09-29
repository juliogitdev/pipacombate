class_name Pipa
extends Node2D

signal queda_finalizada(pipa: Pipa, atacante_id: String)
signal queda_iniciada(pipa: Pipa, atacante_id: String)
signal marco_vida_atingido(pipa: Pipa, valor: int, definicao: Dictionary)

enum Estado { NOVA, VOANDO, CAINDO, INATIVA }
enum EstadoIA { PATRULHANDO, APROXIMANDO, ATACANDO, ESCAPANDO, REPOSICIONANDO, DEFENDENDO }

var unique_id := ""
var apelido := ""
var hp := 100.0
var hp_max := 100.0
var velocidade := Vector2.ZERO
var alvo := Vector2.ZERO
var fase_vento := 0.0
var direcao_lateral := 1.0
var cor_principal := Color.WHITE
var cor_detalhe := Color.WHITE
var skin_atual := "classica"
var _inicializada := false
var pontos := 0.0
var estado := Estado.NOVA
var cortes := 0
var _tempo_queda := 0.0
var _atacante_id := ""
var _estilo_vida: StyleBoxFlat
var _escudo_restante := 0.0
var _boost_restante := 0.0
var _gigante_restante := 0.0
var _escala_base := 1.0
var _alvo_caca: Pipa
var _marcos_recebidos: Dictionary = {}
var _poder_label_restante := 0.0
var _vip := false
var _lider := false
var _pulso_coroa := 0.0
var _quebrao_restante := 0.0
var _quebrao_duracao := 0.0
var _quebrao_origem := Vector2.ZERO
var _quebrao_direcao := 1.0
var _quebrao_intensidade := 0.0
var _estado_ia := EstadoIA.PATRULHANDO
var _tempo_estado_ia := 0.0
var _tita := false
var _tita_tipo := ""
var _rosas_ciclo := 0
var _nivel_arte_presente := 0

@onready var arte_pipa: Sprite2D = $ArtePipa
@onready var nome_label: Label = $Nome
@onready var vida: ProgressBar = $Vida
@onready var vida_texto: Label = $VidaTexto
@onready var corpo: Polygon2D = $Corpo
@onready var detalhe: Polygon2D = $Detalhe
@onready var detalhe_esquerdo: Polygon2D = $DetalheEsquerdo
@onready var faixa: Polygon2D = $Faixa
@onready var marca: Polygon2D = $Marca
@onready var avatar: Sprite2D = $Avatar
@onready var inicial: Label = $Inicial
@onready var poder_label: Label = $PoderLabel
@onready var vip_label: Label = $VipLabel


func configurar(usuario: Dictionary) -> void:
	var entrando_na_arena := estado != Estado.VOANDO
	unique_id = str(usuario.get("uniqueId", "anonimo"))
	apelido = str(usuario.get("apelido", unique_id))
	nome_label.text = _nome_exibicao()
	inicial.text = nome_label.text.left(1).to_upper()
	if not _inicializada:
		_inicializada = true
		AvatarCache.avatar_pronto.connect(_ao_avatar_pronto)
	var avatar_url := str(usuario.get("avatar", ""))
	if not entrando_na_arena:
		AvatarCache.solicitar(unique_id, avatar_url)
		return
	estado = Estado.VOANDO
	visible = true
	modulate = Color.WHITE
	rotation = 0.0
	_escala_base = float(Config.obter("pipas", "escala_padrao", 0.92))
	scale = Vector2.ONE * _escala_base
	velocidade = Vector2.ZERO
	pontos = 0.0
	cortes = 0
	_tempo_queda = 0.0
	_atacante_id = ""
	_escudo_restante = 0.0
	_boost_restante = 0.0
	_gigante_restante = 0.0
	_escala_base = float(Config.obter("pipas", "escala_padrao", 0.92))
	_vip = false
	_lider = false
	_quebrao_restante = 0.0
	_estado_ia = EstadoIA.PATRULHANDO
	_tempo_estado_ia = 0.0
	_rosas_ciclo = 0
	_nivel_arte_presente = 0
	vip_label.hide()
	_alvo_caca = null
	_marcos_recebidos.clear()
	_poder_label_restante = 0.0
	poder_label.hide()
	avatar.texture = null
	inicial.show()
	vida.show()
	vida_texto.show()
	hp_max = float(Config.obter("arena", "hp_base", 100.0))
	hp = hp_max
	vida.max_value = hp_max
	vida.value = hp
	fase_vento = randf_range(0.0, TAU)
	direcao_lateral = -1.0 if randf() < 0.5 else 1.0
	_aplicar_variacao_visual()
	_atualizar_arte_pipa()
	_escala_base = _escala_por_pontos()
	scale = Vector2.ONE * _escala_base
	_estilo_vida = vida.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_atualizar_vida()
	AvatarCache.solicitar(unique_id, avatar_url)


func aplicar_pontos(novos_pontos: float) -> void:
	if novos_pontos <= 0.0:
		return
	pontos += novos_pontos
	_atualizar_escala_progressao()
	var hp_anterior := hp_max
	hp_max = minf(
		float(Config.obter("dano", "hp_maximo_teto", 5000.0)),
		float(Config.obter("arena", "hp_base", 100.0)) + pontos * float(Config.obter("dano", "hp_por_ponto", 0.5))
	)
	hp += hp_max - hp_anterior
	_atualizar_vida()


func aplicar_presente(detalhes: Dictionary) -> void:
	var nome := str(detalhes.get("giftName", ""))
	var quantidade := maxi(1, int(detalhes.get("quantidade", 1)))
	var diamantes := maxi(1, int(detalhes.get("diamantes", 1)))
	var mapa: Dictionary = Config.obter("presentes", "por_gift", {})
	var regra: Dictionary = mapa.get(nome, {})
	if nome.to_lower().contains("rosa"):
		_rosas_ciclo += quantidade
		_nivel_arte_presente = 10 if _rosas_ciclo >= 10 else (5 if _rosas_ciclo >= 5 else 1)
		_atualizar_arte_pipa()
	var bonus_hp := float(regra.get("hp", float(Config.obter("presentes", "hp_por_diamante", 40.0)) * diamantes)) * quantidade
	hp_max = minf(float(Config.obter("dano", "hp_maximo_teto", 5000.0)), hp_max + bonus_hp)
	hp = minf(hp_max, hp + bonus_hp)
	_atualizar_vida()
	_vip = true
	vip_label.show()
	var efeito := str(regra.get("efeito", ""))
	if bool(Config.obter("pipas", "skin_por_presente", true)):
		match efeito:
			"ESCUDO": _aplicar_skin("gelo")
			"GIGANTE", "DERRUBA_TRES": _aplicar_skin("ouro")
			_: _aplicar_skin("neon")
	if efeito == "ESCUDO":
		_escudo_restante = float(regra.get("segundos", Config.obter("efeitos", "escudo_seg", 8.0)))
	elif efeito == "GIGANTE":
		_gigante_restante = float(Config.obter("efeitos", "gigante_seg", 22.0))
		_escala_base = _escala_por_pontos() * float(Config.obter("efeitos", "gigante_escala", 1.55))
	elif efeito in ["CACA_E_DERRUBA", "DERRUBA_TRES"]:
		_boost_restante = float(Config.obter("efeitos", "boost_corte_seg", 4.0))
	_mostrar_poder(_nome_do_poder(efeito), maxf(2.5, float(Config.obter("efeitos", "boost_corte_seg", 4.0))))
	Audio.tocar_presente(efeito)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * _escala_base * 1.18, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE * _escala_base, 0.35).set_trans(Tween.TRANS_ELASTIC)


func curar_por_likes(quantidade: int) -> void:
	var cura := minf(
		float(Config.obter("likes", "cura_max_por_evento", 35.0)),
		maxi(0, quantidade) * float(Config.obter("likes", "vida_por_like", 0.35))
	)
	hp = minf(hp_max, hp + cura)
	_atualizar_vida()


func _atualizar_vida() -> void:
	vida.max_value = hp_max
	vida.value = hp
	vida_texto.text = "%d / %d HP" % [ceili(hp), ceili(hp_max)]
	var proporcao := hp / maxf(1.0, hp_max)
	if proporcao > 0.6:
		_estilo_vida.bg_color = Color("#36d96b")
	elif proporcao > 0.25:
		_estilo_vida.bg_color = Color("#ffd23f")
	else:
		_estilo_vida.bg_color = Color("#ff3b4f")
	vida.add_theme_stylebox_override("fill", _estilo_vida)
	_verificar_marcos()


func receber_dano(dano_base: float, atacante_id: String) -> bool:
	if estado != Estado.VOANDO or dano_base <= 0.0 or _escudo_restante > 0.0:
		return false
	var reducao_por_mil := float(Config.obter("dano", "reducao_dano_por_1000pts_pct", 15.0)) / 100.0
	var reducao := clampf(floorf(pontos / 1000.0) * reducao_por_mil, 0.0, 0.8)
	hp = maxf(0.0, hp - dano_base * (1.0 - reducao))
	_atualizar_vida()
	if hp <= 0.0:
		_iniciar_queda(atacante_id)
		return true
	return false


func registrar_corte() -> void:
	cortes += 1


func esta_voando() -> bool:
	return estado == Estado.VOANDO


func multiplicador_corte() -> float:
	var multiplicador := float(Config.obter("efeitos", "boost_corte_mult", 3.0)) if _boost_restante > 0.0 else 1.0
	if _tita:
		multiplicador *= float(Config.obter("pipas", "tita_cerol_mult", 1.18))
	return multiplicador


func cor_da_linha() -> Color:
	if _lider:
		return Color("#ffe66d")
	if _vip:
		return Color("#52ffe5")
	if _tita:
		match _tita_tipo:
			"fogo": return Color("#ff6b1a")
			"gelo": return Color("#62e7ff")
			_: return Color("#ff4fd8")
	var progresso := clampf(pontos / float(Config.obter("pipas", "pontos_linha_neon", 600.0)), 0.0, 1.0)
	return cor_principal.lerp(Color("#9ffcff"), progresso * 0.55).lightened(0.28)


func espessura_da_linha() -> float:
	return float(Config.obter("movimento", "linha_espessura", 2.0)) + (1.2 if _vip else 0.0) + (0.8 if _lider else 0.0) + (1.15 if _tita else 0.0)


func eh_tita() -> bool:
	return _tita


func tipo_tita() -> String:
	return _tita_tipo


func definir_lider(ativo: bool) -> bool:
	if _lider == ativo:
		return false
	_lider = ativo
	_pulso_coroa = 0.0
	queue_redraw()
	return true


func eh_vip() -> bool:
	return _vip


func ativar_vip() -> void:
	_vip = true
	vip_label.show()
	queue_redraw()


func iniciar_quebrao(duracao: float, intensidade: float = 0.0) -> bool:
	if estado != Estado.VOANDO or _quebrao_restante > 0.0:
		return false
	_quebrao_duracao = maxf(1.2, duracao)
	_quebrao_restante = _quebrao_duracao
	_quebrao_intensidade = clampf(intensidade, 0.0, 1.0)
	_quebrao_origem = global_position
	_quebrao_direcao = direcao_lateral
	_escudo_restante = maxf(_escudo_restante, _quebrao_duracao + 0.4)
	velocidade = Vector2.ZERO
	var escala_intensidade := lerpf(1.0, 1.32, clampf(intensidade, 0.0, 1.0))
	scale = Vector2.ONE * _escala_base * escala_intensidade
	_mostrar_poder("⚡ QUEBRÃO! ⚡", _quebrao_duracao)
	queue_redraw()
	return true


func esta_em_quebrao() -> bool:
	return _quebrao_restante > 0.0


func ativar_escudo(duracao: float = -1.0) -> void:
	_escudo_restante = duracao if duracao > 0.0 else float(Config.obter("efeitos", "escudo_seg", 8.0))
	queue_redraw()


func aplicar_recompensa_marco(definicao: Dictionary) -> void:
	var recompensa := str(definicao.get("recompensa", ""))
	var duracao := float(definicao.get("duracao_seg", 6.0))
	match recompensa:
		"ESCUDO":
			ativar_escudo(duracao)
		"BOOST":
			_boost_restante = maxf(_boost_restante, duracao)
		"LENDARIO":
			ativar_escudo(duracao)
			_boost_restante = maxf(_boost_restante, duracao)
			_gigante_restante = maxf(_gigante_restante, duracao)
			_escala_base = _escala_por_pontos() * float(Config.obter("efeitos", "gigante_escala", 1.55))
			scale = Vector2.ONE * _escala_base
	_mostrar_poder(str(definicao.get("nome", "CONQUISTA")), duracao)


func iniciar_caca(novo_alvo: Pipa) -> void:
	_alvo_caca = novo_alvo
	_boost_restante = maxf(_boost_restante, float(Config.obter("efeitos", "boost_corte_seg", 4.0)))
	queue_redraw()


func desativar() -> void:
	estado = Estado.INATIVA
	visible = false


func forcar_queda(atacante_id: String) -> void:
	if estado == Estado.VOANDO:
		hp = 0.0
		_atualizar_vida()
		_iniciar_queda(atacante_id)


func _ao_avatar_pronto(uid: String, textura: ImageTexture) -> void:
	if uid != unique_id:
		return
	avatar.texture = textura
	var tamanho := textura.get_size()
	if tamanho.x > 0.0 and tamanho.y > 0.0:
		var tamanho_ideal := 28.0
		avatar.scale = Vector2(tamanho_ideal / tamanho.x, tamanho_ideal / tamanho.y)
	avatar.position = Vector2(0, 6.0)
	inicial.hide()


func simular(delta: float, limites: Rect2, outros: Array[Pipa] = []) -> void:
	if estado == Estado.CAINDO:
		_tempo_queda += delta
		velocidade.y += float(Config.obter("combate", "queda_gravidade", 520.0)) * delta
		velocidade.x += sin(_tempo_queda * 11.0) * float(Config.obter("combate", "queda_balanco", 42.0)) * delta
		global_position += velocidade * delta
		rotation += delta * direcao_lateral * (4.5 + _tempo_queda * 3.0)
		var progresso_queda := clampf(_tempo_queda / float(Config.obter("combate", "queda_duracao_seg", 1.2)), 0.0, 1.0)
		scale = Vector2.ONE * _escala_base * lerpf(1.0, 0.68, progresso_queda)
		modulate.a = 1.0 - maxf(0.0, (progresso_queda - 0.68) / 0.32)
		fase_vento += delta * 4.0
		queue_redraw()
		if _tempo_queda >= float(Config.obter("combate", "queda_duracao_seg", 1.2)):
			estado = Estado.INATIVA
			queda_finalizada.emit(self, _atacante_id)
		return
	if estado != Estado.VOANDO:
		return
	if _quebrao_restante > 0.0:
		_simular_quebrao(delta, limites)
		return

	_poder_label_restante = maxf(0.0, _poder_label_restante - delta)
	_pulso_coroa += delta
	poder_label.visible = _poder_label_restante > 0.0
	_escudo_restante = maxf(0.0, _escudo_restante - delta)
	_boost_restante = maxf(0.0, _boost_restante - delta)
	if _boost_restante <= 0.0:
		_alvo_caca = null
	if _gigante_restante > 0.0:
		_gigante_restante = maxf(0.0, _gigante_restante - delta)
		if _gigante_restante <= 0.0:
			_escala_base = _escala_por_pontos()
			create_tween().tween_property(self, "scale", Vector2.ONE * _escala_base, 0.45).set_trans(Tween.TRANS_BACK)

	fase_vento += delta * float(Config.obter("movimento", "frequencia_oscilacao", 1.35))
	var margem_troca := float(Config.obter("movimento", "troca_lado_distancia", 75.0))
	if direcao_lateral > 0.0 and global_position.x >= limites.end.x - margem_troca:
		direcao_lateral = -1.0
	elif direcao_lateral < 0.0 and global_position.x <= limites.position.x + margem_troca:
		direcao_lateral = 1.0

	_atualizar_estado_ia(outros, limites, delta)
	var ancora := _obter_ancora(limites)
	var forca_total := Vector2.ZERO
	forca_total += _calcular_forca_vento()
	forca_total += _calcular_forca_linha(ancora)
	forca_total += _calcular_forca_borda(limites)
	forca_total += _calcular_forca_centro(limites)
	forca_total += _calcular_forca_separacao(outros)
	forca_total += _calcular_forca_ia(outros, limites)

	if _alvo_caca != null and is_instance_valid(_alvo_caca) and _alvo_caca.esta_voando():
		forca_total += global_position.direction_to(_alvo_caca.global_position) * float(Config.obter("presentes", "caca_forca", 310.0))

	forca_total.x += direcao_lateral * float(Config.obter("movimento", "impulso_lateral", 125.0)) * 0.05 * Eventos.modificador("vento_mult")
	forca_total.y += sin(fase_vento * 0.85) * 7.5

	var arrasto := exp(-float(Config.obter("movimento", "arrasto", 1.8)) * delta)
	velocidade += forca_total * delta
	velocidade *= arrasto
	velocidade = velocidade.limit_length(float(Config.obter("arena", "velocidade_max", 115.0)))
	global_position += velocidade * delta
	global_position = _restringir_posicao(global_position, limites)

	var inclinacao_max := deg_to_rad(float(Config.obter("movimento", "inclinacao_max_graus", 13.0)))
	var rotacao_alvo := clampf(velocidade.y / 160.0, -1.0, 1.0) * inclinacao_max
	rotation = lerp_angle(rotation, rotacao_alvo, clampf(delta * 4.0, 0.0, 1.0))
	if hp / maxf(1.0, hp_max) < 0.2:
		vida.modulate.a = 0.55 + sin(fase_vento * 8.0) * 0.45
	else:
		vida.modulate.a = 1.0
	queue_redraw()


func _obter_ancora(limites: Rect2) -> Vector2:
	var largura := limites.size.x
	var hash_ancora := absi(hash(unique_id + "|base_linha"))
	var posicao_pct := lerpf(0.06, 0.94, float(hash_ancora % 1000) / 999.0)
	var altura_base := 18.0 + float((hash_ancora / 1000) % 54)
	return Vector2(limites.position.x + largura * posicao_pct, limites.end.y + altura_base)


func _calcular_forca_vento() -> Vector2:
	var intensidade := 1.0 + (0.12 if _vip else 0.0) + (0.08 if _tita else 0.0)
	var vento_base_x := sin(fase_vento * 0.65) * 24.0
	var vento_base_y := cos(fase_vento * 0.52 + hash(unique_id) * 0.01) * 9.0
	var rajada_x := sin(fase_vento * 1.35 + hash(unique_id + "|rajada_x")) * 18.0
	var rajada_y := cos(fase_vento * 1.1 + hash(unique_id + "|rajada_y")) * 10.0
	return Vector2(
		(vento_base_x + rajada_x + direcao_lateral * 10.0) * intensidade,
		(vento_base_y + rajada_y) * intensidade * 0.55
	)


func _calcular_forca_linha(ancora: Vector2) -> Vector2:
	var distancia := global_position.distance_to(ancora)
	var limite := 520.0
	var excesso := maxf(0.0, distancia - limite)
	var forca := Vector2.ZERO
	if excesso > 0.0:
		var direcao := (ancora - global_position).normalized()
		var elasticidade := 0.36 + float(Config.obter("movimento", "linha_curvatura", 16.0)) * 0.01
		forca += direcao * excesso * elasticidade
	var centralizacao := clampf(1.0 - distancia / maxf(1.0, limite), 0.0, 1.0)
	if centralizacao > 0.0:
		forca += (ancora - global_position) * centralizacao * 0.11
	return forca


func _calcular_forca_borda(limites: Rect2) -> Vector2:
	var zona_x := maxf(110.0, limites.size.x * 0.18)
	var zona_y := maxf(80.0, limites.size.y * 0.18)
	var forca := Vector2.ZERO
	var reintegra_x := 0.18
	var reintegra_y := 0.14
	if global_position.x < limites.position.x + zona_x:
		var afastamento := limites.position.x + zona_x - global_position.x
		forca.x += afastamento * reintegra_x
	if global_position.x > limites.end.x - zona_x:
		var afastamento := global_position.x - (limites.end.x - zona_x)
		forca.x -= afastamento * reintegra_x
	if global_position.y < limites.position.y + zona_y:
		var afastamento := limites.position.y + zona_y - global_position.y
		forca.y += afastamento * reintegra_y
	if global_position.y > limites.end.y - zona_y:
		var afastamento := global_position.y - (limites.end.y - zona_y)
		forca.y -= afastamento * reintegra_y
	return forca


func _calcular_forca_centro(limites: Rect2) -> Vector2:
	var centro := Vector2(
		lerpf(limites.position.x, limites.end.x, 0.5),
		lerpf(limites.position.y, limites.end.y, 0.5)
	)
	var deslocamento := centro - global_position
	return deslocamento * 0.002


func _calcular_forca_separacao(outros: Array[Pipa]) -> Vector2:
	var forca := Vector2.ZERO
	if outros.is_empty():
		return forca
	var raio := 120.0
	for outro: Pipa in outros:
		if outro == self or not outro.esta_voando():
			continue
		var distancia := global_position.distance_to(outro.global_position)
		if distancia <= 0.0 or distancia > raio:
			continue
		var direcao := (global_position - outro.global_position).normalized()
		var peso := (1.0 - distancia / raio) * 26.0
		forca += direcao * peso
	return forca


func _atualizar_estado_ia(outros: Array[Pipa], limites: Rect2, delta: float) -> void:
	var alvo := _melhor_alvo(outros)
	var distancia_alvo := INF
	if alvo != null:
		distancia_alvo = global_position.distance_to(alvo.global_position)
	var hp_relativo := hp / maxf(1.0, hp_max)
	var centro := Vector2(
		lerpf(limites.position.x, limites.end.x, 0.5),
		lerpf(limites.position.y, limites.end.y, 0.5)
	)
	var distancia_centro := global_position.distance_to(centro)
	var proximo_borda := minf(
		global_position.distance_to(Vector2(limites.position.x, global_position.y)),
		global_position.distance_to(Vector2(limites.end.x, global_position.y))
	)
	var novo_estado := EstadoIA.PATRULHANDO
	if hp_relativo <= 0.24:
		novo_estado = EstadoIA.ESCAPANDO
	elif _estado_ia == EstadoIA.ESCAPANDO and _tempo_estado_ia < 1.2:
		novo_estado = EstadoIA.ESCAPANDO
	elif alvo != null:
		if distancia_alvo < 120.0:
			novo_estado = EstadoIA.ATACANDO
		elif distancia_alvo < 260.0:
			novo_estado = EstadoIA.APROXIMANDO
		elif proximo_borda < 90.0 or distancia_centro > 160.0:
			novo_estado = EstadoIA.REPOSICIONANDO
		elif hp_relativo < 0.45:
			novo_estado = EstadoIA.DEFENDENDO
	if novo_estado != _estado_ia:
		_estado_ia = novo_estado
		_tempo_estado_ia = 0.0
	else:
		_tempo_estado_ia += delta


func _melhor_alvo(outros: Array[Pipa]) -> Pipa:
	var melhor: Pipa = null
	var menor_distancia := INF
	for outro: Pipa in outros:
		if outro == self or not outro.esta_voando():
			continue
		var distancia := global_position.distance_squared_to(outro.global_position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			melhor = outro
	return melhor


func _calcular_forca_ia(outros: Array[Pipa], limites: Rect2) -> Vector2:
	var forca := Vector2.ZERO
	var alvo := _melhor_alvo(outros)
	var centro := Vector2(
		lerpf(limites.position.x, limites.end.x, 0.5),
		lerpf(limites.position.y, limites.end.y, 0.5)
	)
	match _estado_ia:
		EstadoIA.PATRULHANDO:
			forca.x += sin(fase_vento * 0.8 + hash(unique_id)) * 18.0
			forca.y += sin(fase_vento * 1.7 + hash(unique_id + "|patrulha")) * 10.0
			forca.x += direcao_lateral * 10.0
		EstadoIA.APROXIMANDO:
			if alvo != null:
				var alvo_futuro := alvo.global_position + alvo.velocidade * 0.35
				var direcao := global_position.direction_to(alvo_futuro)
				forca += direcao * 38.0
				forca += Vector2(-direcao.y, direcao.x) * sin(fase_vento * 2.0) * 8.0
		EstadoIA.ATACANDO:
			if alvo != null:
				var alvo_futuro := alvo.global_position + alvo.velocidade * 0.2
				var direcao := global_position.direction_to(alvo_futuro)
				var intensidade := lerpf(34.0, 60.0, clampf(1.0 - global_position.distance_to(alvo_futuro) / 260.0, 0.0, 1.0))
				forca += direcao * intensidade
		EstadoIA.ESCAPANDO:
			if alvo != null:
				var fuga := (global_position - alvo.global_position).normalized()
				forca += fuga * 72.0
				forca.y += sin(fase_vento * 2.5) * 14.0
		EstadoIA.REPOSICIONANDO:
			var objetivo := Vector2(
				lerpf(limites.position.x, limites.end.x, 0.5 + direcao_lateral * 0.18),
				lerpf(limites.position.y, limites.end.y, 0.44 + sin(fase_vento * 0.7) * 0.12)
			)
			var direcao := global_position.direction_to(objetivo)
			forca += direcao * 26.0
		EstadoIA.DEFENDENDO:
			if alvo != null:
				var afastamento := (global_position - alvo.global_position).normalized()
				forca += afastamento * 42.0
			forca += (centro - global_position) * 0.008
	return forca


func _restringir_posicao(posicao: Vector2, limites: Rect2) -> Vector2:
	var topo := limites.position.y + 12.0
	var baixo := limites.end.y - 12.0
	posicao.x = clampf(posicao.x, limites.position.x, limites.end.x)
	posicao.y = clampf(posicao.y, topo, baixo)
	return posicao


func _simular_quebrao(delta: float, limites: Rect2) -> void:
	_escudo_restante = maxf(0.0, _escudo_restante - delta)
	_poder_label_restante = maxf(0.0, _poder_label_restante - delta)
	poder_label.visible = _poder_label_restante > 0.0
	_quebrao_restante = maxf(0.0, _quebrao_restante - delta)
	var progresso := 1.0 - _quebrao_restante / maxf(0.001, _quebrao_duracao)
	var alcance_x := limites.size.x * 0.38
	var mergulho_y := limites.size.y * 0.42
	var deslocamento_x := sin(progresso * PI) * alcance_x * _quebrao_direcao
	var deslocamento_y := sin(progresso * PI) * mergulho_y
	global_position = _quebrao_origem + Vector2(deslocamento_x, deslocamento_y)
	global_position.x = clampf(global_position.x, limites.position.x, limites.end.x)
	global_position.y = clampf(global_position.y, limites.position.y, limites.end.y - 24.0)
	rotation = sin(progresso * TAU) * 0.42 + _quebrao_direcao * 0.16
	var pulso := 1.0 + sin(progresso * PI) * (0.16 + _quebrao_intensidade * 0.24)
	scale = Vector2.ONE * _escala_base * pulso
	fase_vento += delta * 7.0
	queue_redraw()
	if _quebrao_restante <= 0.0:
		rotation = 0.0
		scale = Vector2.ONE * _escala_base
		velocidade = Vector2(_quebrao_direcao * 45.0, -20.0)


func _iniciar_queda(atacante_id: String) -> void:
	estado = Estado.CAINDO
	_atacante_id = atacante_id
	_tempo_queda = 0.0
	velocidade = Vector2(
		-direcao_lateral * float(Config.obter("combate", "queda_impulso_lateral", 105.0)),
		-float(Config.obter("combate", "queda_impulso_vertical", 145.0))
	)
	vida.hide()
	vida_texto.hide()
	queda_iniciada.emit(self, atacante_id)


func _draw() -> void:
	# Poderes continuam ativos, mas sem aros e partículas cobrindo a arena.
	if estado == Estado.VOANDO:
		var glow := cor_principal
		glow.a = 0.18
		draw_circle(Vector2.ZERO, 34.0 + (6.0 if _tita else 0.0), glow)
		var brilho := cor_detalhe
		brilho.a = 0.24
		draw_arc(Vector2.ZERO, 28.0, -PI * 0.8, PI * 0.8, 18, brilho, 2.2, true)
		if _vip:
			var vip_glow := Color("#7ef9e2")
			vip_glow.a = 0.22
			draw_circle(Vector2.ZERO, 40.0, vip_glow)
		if _lider:
			var lider_glow := Color("#ffd76a")
			lider_glow.a = 0.16
			draw_circle(Vector2.ZERO, 42.0, lider_glow)
	if _lider and estado == Estado.VOANDO:
		_desenhar_coroa()
	var comprimento := float(Config.obter("movimento", "rabiola_comprimento", 145.0))
	var segmentos := maxi(4, int(Config.obter("movimento", "rabiola_segmentos", 12)))
	var amplitude := float(Config.obter("movimento", "rabiola_onda", 13.0))
	var frequencia := float(Config.obter("movimento", "rabiola_frequencia", 5.0))
	var velocidade_total := clampf(velocidade.length() / maxf(1.0, float(Config.obter("arena", "velocidade_max", 115.0))), 0.0, 1.0)
	var impulso_horizontal := clampf(velocidade.x / maxf(1.0, float(Config.obter("arena", "velocidade_max", 115.0))), -1.0, 1.0)
	var impulso_vertical := clampf(velocidade.y / maxf(1.0, float(Config.obter("arena", "velocidade_max", 115.0))), -1.0, 1.0)
	var pontos := PackedVector2Array()
	for indice in segmentos + 1:
		var progresso := float(indice) / float(segmentos)
		var deslocamento_x := sin(fase_vento * 2.2 - progresso * frequencia) * amplitude * (0.45 + progresso)
		deslocamento_x += impulso_horizontal * (14.0 + progresso * 18.0)
		var deslocamento_y := progresso * comprimento + impulso_vertical * (12.0 + progresso * 16.0)
		var x := deslocamento_x + (1.0 - progresso) * (direcao_lateral * 10.0)
		pontos.append(Vector2(x, 38.0 + deslocamento_y))
	var cor_rabiola := cor_da_linha()
	cor_rabiola.a = 0.72
	draw_polyline(pontos, cor_rabiola, 2.0 + velocidade_total * 0.8, true)


func _aplicar_variacao_visual() -> void:
	var paleta := [
		[Color("#ff6fa7"), Color("#ffd9eb")], [Color("#7c6bff"), Color("#d8d2ff")],
		[Color("#3ec9ff"), Color("#d8f7ff")], [Color("#25d4a3"), Color("#dffef4")],
		[Color("#ff8c64"), Color("#ffe1b5")], [Color("#8ec5ff"), Color("#edf6ff")],
		[Color("#d76dff"), Color("#ffd5fb")], [Color("#58c7a3"), Color("#d7fff0")],
		[Color("#ff7db2"), Color("#fff0b6")], [Color("#6ea8ff"), Color("#d7f0ff")],
		[Color("#6f7cff"), Color("#c5d5ff")], [Color("#ef5da8"), Color("#ffe1ef")],
		[Color("#19b5d8"), Color("#cffafe")], [Color("#f59e0b"), Color("#fef3c7")],
		[Color("#8b5cf6"), Color("#ddd6fe")], [Color("#f97316"), Color("#fed7aa")]
	]
	var skins: Array = Config.obter("pipas", "skins", ["classica"])
	if skins.is_empty():
		skins = [str(Config.obter("pipas", "skin_padrao", "classica"))]
	var indice_skin := absi(hash(unique_id)) % skins.size()
	skin_atual = str(skins[indice_skin])
	var chance_tita := clampi(int(Config.obter("pipas", "tita_chance_pct", 18)), 0, 100)
	_tita = absi(hash(unique_id + "|tita")) % 100 < chance_tita
	if _tita:
		var tipos := ["neon", "fogo", "gelo"]
		_tita_tipo = tipos[absi(hash(unique_id + "|tita_tipo")) % tipos.size()]
	else:
		_tita_tipo = ""
	var cores: Array = paleta[absi(hash(unique_id + "cores")) % paleta.size()]
	cor_principal = cores[0]
	cor_detalhe = cores[1]
	_aplicar_skin(skin_atual, false)
	if _tita:
		match _tita_tipo:
			"fogo": _aplicar_skin("chama", false)
			"gelo": _aplicar_skin("gelo", false)
			_: _aplicar_skin("neon", false)


func _aplicar_skin(nome: String, redesenhar: bool = true) -> void:
	skin_atual = nome
	match nome:
		"chama":
			cor_principal = Color("#f97316")
			cor_detalhe = Color("#facc15")
			marca.color = Color("#fff6b0")
		"gelo":
			cor_principal = Color("#3aa8ff")
			cor_detalhe = Color("#d7f3ff")
			marca.color = Color("#ebfdff")
		"ouro":
			cor_principal = Color("#c28a1b")
			cor_detalhe = Color("#fff2ad")
			marca.color = Color("#fffbe0")
		"neon":
			cor_principal = cor_principal.lightened(0.12)
			cor_detalhe = cor_detalhe.lightened(0.18)
			marca.color = Color("#f0ecff")
		"aurora":
			cor_principal = Color("#2dd4bf")
			cor_detalhe = Color("#d9f99d")
			marca.color = Color("#e6fff9")
		"candy":
			cor_principal = Color("#ff7ab6")
			cor_detalhe = Color("#ffd8ea")
			marca.color = Color("#fff0fa")
		"galaxy":
			cor_principal = Color("#6d5efc")
			cor_detalhe = Color("#a5f3fc")
			marca.color = Color("#edf4ff")
		"safira":
			cor_principal = Color("#4f46e5")
			cor_detalhe = Color("#7dd3fc")
			marca.color = Color("#e0f2fe")
		"sunset":
			cor_principal = Color("#fb7185")
			cor_detalhe = Color("#fbbf24")
			marca.color = Color("#fff7d6")
		"lilas":
			cor_principal = Color("#a78bfa")
			cor_detalhe = Color("#f5d0fe")
			marca.color = Color("#f5ecff")
		"prata":
			cor_principal = Color("#b7cce6")
			cor_detalhe = Color("#edf4ff")
			marca.color = Color("#f5f9ff")
		"solar":
			cor_principal = Color("#f59e0b")
			cor_detalhe = Color("#fde68a")
			marca.color = Color("#fff7d6")
		"royal":
			cor_principal = Color("#7c3aed")
			cor_detalhe = Color("#ddd6fe")
			marca.color = Color("#f3e8ff")
		_:
			cor_principal = cor_principal.lightened(0.06)
			cor_detalhe = cor_detalhe.lightened(0.08)
			marca.color = Color(1.0, 1.0, 1.0, 0.68)
	corpo.color = cor_principal
	detalhe.color = cor_detalhe
	detalhe_esquerdo.color = cor_principal.darkened(0.18)
	faixa.color = Color(1.0, 1.0, 1.0, 0.2 if nome in ["classica", "neon", "safira"] else 0.34)
	if redesenhar:
		queue_redraw()


func _desenhar_efeito_skin() -> void:
	var brilho := float(Config.obter("pipas", "brilho_skin", 0.85))
	match skin_atual:
		"chama":
			for indice in 5:
				var angulo := fase_vento * 2.0 + float(indice) * TAU / 5.0
				var centro := Vector2(cos(angulo) * 38.0, sin(angulo) * 31.0)
				draw_circle(centro, 8.0 + sin(fase_vento * 4.0 + indice) * 3.0, Color(1.0, 0.3, 0.02, brilho * 0.34))
		"gelo":
			for indice in 8:
				var angulo := float(indice) * TAU / 8.0 + fase_vento * 0.12
				var inicio := Vector2.RIGHT.rotated(angulo) * 43.0
				var fim := Vector2.RIGHT.rotated(angulo) * 54.0
				draw_line(inicio, fim, Color(0.75, 0.96, 1.0, brilho * 0.8), 3.0, true)
		"ouro":
			var pulso := 50.0 + sin(fase_vento * 3.0) * 4.0
			draw_arc(Vector2.ZERO, pulso, 0.0, TAU, 32, Color(1.0, 0.8, 0.14, brilho * 0.72), 4.0, true)
			for indice in 4:
				var p := Vector2.RIGHT.rotated(fase_vento + indice * PI * 0.5) * pulso
				draw_circle(p, 3.5, Color("#fff4a3"))
		"neon", "aurora", "candy", "galaxy":
			var pulso_neon := 48.0 + sin(fase_vento * 3.8) * 3.0
			var cor_arco := cor_detalhe
			cor_arco.a = brilho * 0.62
			draw_arc(Vector2.ZERO, pulso_neon, 0.0, TAU, 32, cor_arco, 3.5, true)
			for indice in 6:
				var estrela := Vector2.RIGHT.rotated(fase_vento * 0.7 + indice * TAU / 6.0) * pulso_neon
				draw_circle(estrela, 2.2 + float(indice % 2), Color(1.0, 1.0, 1.0, 0.85))
		"prata":
			var raio := 46.0 + sin(fase_vento * 2.5) * 3.0
			draw_arc(Vector2.ZERO, raio, 0.0, TAU, 30, Color("#dfeafc"), 2.5, true)
			draw_arc(Vector2.ZERO, raio * 0.78, 0.2, 0.8 * TAU, 20, Color("#edf4ff", brilho * 0.7), 1.4, true)
			for indice in 6:
				var ponto := Vector2.RIGHT.rotated(fase_vento * 1.2 + indice * TAU / 6.0) * raio
				draw_circle(ponto, 2.0 + float(indice % 2), Color("#ffffff", 0.75))
		"solar":
			var raio := 44.0 + sin(fase_vento * 4.0) * 2.0
			for indice in 8:
				var angulo := fase_vento * 1.4 + float(indice) * TAU / 8.0
				var inicio := Vector2.RIGHT.rotated(angulo) * raio
				var fim := Vector2.RIGHT.rotated(angulo) * (raio + 12.0)
				draw_line(inicio, fim, Color("#fef3c7", brilho * 0.95), 3.0, true)
			draw_arc(Vector2.ZERO, raio * 0.7, 0.0, TAU, 24, Color("#fbbf24", brilho * 0.7), 2.0, true)
		"royal":
			var raio := 42.0 + sin(fase_vento * 3.2) * 2.5
			draw_arc(Vector2.ZERO, raio, 0.14, TAU * 0.86, 28, Color("#ddd6fe", brilho * 0.8), 2.8, true)
			draw_arc(Vector2.ZERO, raio * 0.66, 0.0, TAU, 22, Color("#c4b5fd", brilho * 0.6), 1.6, true)
			for indice in 5:
				var p := Vector2.RIGHT.rotated(fase_vento * 1.1 + indice * TAU / 5.0) * raio
				draw_circle(p, 2.4, Color("#f3e8ff", 0.9))


func _escala_por_pontos() -> float:
	var base := float(Config.obter("pipas", "escala_padrao", 0.92))
	var max_bonus := float(Config.obter("pipas", "bonus_escala_max", 0.18))
	var pontos_max := maxf(1.0, float(Config.obter("pipas", "pontos_escala_max", 1500.0)))
	var escala := base + clampf(pontos / pontos_max, 0.0, 1.0) * max_bonus
	var presente_mult := 1.0
	if _nivel_arte_presente >= 10:
		presente_mult = float(Config.obter("pipas", "rosa_10_escala", 1.32))
	elif _nivel_arte_presente >= 5:
		presente_mult = float(Config.obter("pipas", "rosa_5_escala", 1.12))
	return escala * (float(Config.obter("pipas", "tita_escala", 1.18)) if _tita else 1.0) * presente_mult


func _atualizar_arte_pipa() -> void:
	var caminho := ""
	if _nivel_arte_presente > 0:
		caminho = "res://assets/pipas/presente_rosa_%d.png" % _nivel_arte_presente
	else:
		var quantidade_artes := maxi(1, int(Config.obter("pipas", "quantidade_artes", 10)))
		var indice := absi(hash(unique_id + "|arte_pipa")) % quantidade_artes + 1
		caminho = "res://assets/pipas/base_%02d.png" % indice
	if not ResourceLoader.exists(caminho):
		arte_pipa.texture = null
		arte_pipa.hide()
		_definir_poligonos_visiveis(true)
		return
	arte_pipa.texture = load(caminho) as Texture2D
	var tamanho := arte_pipa.texture.get_size()
	var alvo_px := float(Config.obter("pipas", "arte_tamanho_px", 86.0))
	if tamanho.x > 0.0 and tamanho.y > 0.0:
		var maior_lado := maxf(tamanho.x, tamanho.y)
		arte_pipa.scale = Vector2.ONE * alvo_px / maior_lado
	arte_pipa.show()
	_definir_poligonos_visiveis(false)


func _definir_poligonos_visiveis(ativos: bool) -> void:
	corpo.visible = ativos
	detalhe.visible = ativos
	detalhe_esquerdo.visible = ativos
	faixa.visible = ativos
	marca.visible = ativos


func _desenhar_aura_tita() -> void:
	var cor := cor_da_linha()
	var pulso := 55.0 + sin(fase_vento * 5.0) * 4.0
	cor.a = 0.34
	draw_arc(Vector2.ZERO, pulso, fase_vento, fase_vento + PI * 1.7, 34, cor, 5.0, true)
	for indice in 6:
		var angulo := fase_vento * 1.8 + indice * TAU / 6.0
		var p := Vector2.RIGHT.rotated(angulo) * (pulso + float(indice % 2) * 7.0)
		draw_circle(p, 2.5 + float(indice % 3), Color(1.0, 1.0, 0.82, 0.8))


func _atualizar_escala_progressao() -> void:
	if _gigante_restante > 0.0:
		return
	_escala_base = _escala_por_pontos()
	scale = Vector2.ONE * _escala_base


func _desenhar_coroa() -> void:
	var y := -118.0 - sin(_pulso_coroa * 4.0) * 3.0
	var brilho := 0.72 + sin(_pulso_coroa * 5.0) * 0.2
	draw_circle(Vector2(0, y + 9), 23.0, Color(1.0, 0.82, 0.2, 0.12))
	var coroa := PackedVector2Array([
		Vector2(-22, y + 14), Vector2(-18, y - 7), Vector2(-7, y + 3),
		Vector2(0, y - 14), Vector2(8, y + 3), Vector2(20, y - 8), Vector2(22, y + 14)
	])
	draw_colored_polygon(coroa, Color(1.0, 0.78, 0.12, brilho))
	draw_line(Vector2(-22, y + 14), Vector2(22, y + 14), Color("#fff2a8"), 4.0, true)
	for x in [-18.0, 0.0, 20.0]:
		draw_circle(Vector2(x, y - (14.0 if x == 0.0 else 8.0)), 3.5, Color("#fffbd1"))


func _nome_exibicao() -> String:
	var limpo := apelido.strip_edges()
	if limpo.is_empty():
		limpo = unique_id
	return limpo.left(18)


func _verificar_marcos() -> void:
	if estado != Estado.VOANDO:
		return
	var marcos: Dictionary = Config.obter("engajamento", "marcos_vida", {})
	var valores: Array[int] = []
	for chave: String in marcos.keys():
		valores.append(int(chave))
	valores.sort()
	for valor in valores:
		if hp_max >= valor and not _marcos_recebidos.has(valor):
			_marcos_recebidos[valor] = true
			var definicao: Dictionary = marcos.get(str(valor), {})
			marco_vida_atingido.emit(self, valor, definicao)


func _mostrar_poder(texto: String, duracao: float) -> void:
	poder_label.text = texto
	poder_label.show()
	poder_label.scale = Vector2(0.55, 0.55)
	_poder_label_restante = duracao
	create_tween().tween_property(poder_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK)


func _nome_do_poder(efeito: String) -> String:
	match efeito:
		"ESCUDO": return "ESCUDO CELESTIAL"
		"GIGANTE": return "PIPA GIGANTE"
		"CACA_E_DERRUBA": return "CAÇA DA ROSA"
		"DERRUBA_TRES": return "ATAQUE TRIPLO"
	return "PODER ATIVADO"
