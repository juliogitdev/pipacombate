extends Node2D

const PIPA_CENA := preload("res://Pipa.tscn")

var _pipas: Dictionary = {}
var _pool: Array[Pipa] = []
var _limites := Rect2()
var _faiscas: Array[Dictionary] = []
var _impactos: Array[Dictionary] = []
var _ultimo_contato: Dictionary = {}
var _ultimo_som_contato_msec := 0
var _banner_restante := 0.0
var _combate_acumulado := 0.0
var _participantes_batalha: Dictionary = {}
var _batalha_encerrada := false
var _inicio_batalha_msec := 0
var _combos_pendentes: Dictionary = {}
var _monitor_acumulado := 0.0
var _presente_restante := 0.0
var _ranking_dados: Array = []
var _ranking_api_msec := 0
var _ranking_local_acumulado := 0.0
var _pontuacao_ciclo: Dictionary = {}
var _cortes_ciclo: Dictionary = {}
var _tempo_ciclo_restante := 0.0
var _conquista_restante := 0.0
var _reset_ciclo_pendente := false
var _tentativas_reset := 0
var _lider_uid := ""
var _presente_uid := ""
var _vips_ciclo: Dictionary = {}
var _quebroes_pendentes: Dictionary = {}
var _fila_quebroes: Array[String] = []
var _quebrao_ativo: Dictionary = {}
var _cooldown_quebrao: Dictionary = {}
var _quebrao_fx_acumulado := 0.0

@onready var _api: Node = $ApiClient
@onready var _pipas_node: Node2D = $Pipas
@onready var _status: Label = $Hud/Status
@onready var _ranking: Label = $Hud/Ranking
@onready var _banner: Label = $Hud/Banner
@onready var _vitoria: Node = $Vitoria
@onready var _comandos: Node = $Comandos
@onready var _cenario: Node = $Cenario


func _ready() -> void:
	_aplicar_config_janela()
	_api.status_alterado.connect(func(texto: String) -> void: _status.text = "LIVE: %s" % texto)
	_api.ranking_atualizado.connect(_atualizar_ranking)
	_api.reset_ciclo_concluido.connect(_ao_reset_ciclo_concluido)
	Config.recarregada.connect(_ao_recarregar_config)
	_vitoria.nova_batalha_solicitada.connect(_solicitar_reinicio_ciclo)
	_comandos.comando_recebido.connect(_executar_comando)
	Eventos.banner_solicitado.connect(_mostrar_banner_evento)
	Eventos.cenario_solicitado.connect(_cenario.definir_tema_temporario)
	Eventos.lista_alterada.connect(_atualizar_eventos_hud)
	Eventos.evento_ativado.connect(_cenario.ativar_evento)
	Eventos.evento_finalizado.connect(_cenario.finalizar_evento)
	_ao_recarregar_config(Config.dados)
	_inicio_batalha_msec = Time.get_ticks_msec()
	_reiniciar_relogio_ciclo()
	AvatarCache.avatar_pronto.connect(_ao_avatar_ranking_pronto)
	# Pipas demonstrativas deixam a primeira execução visual mesmo sem o mock.
	if bool(Config.obter("arena", "mostrar_pipas_demo", false)):
		_criar_ou_renovar({"uniqueId": "demo_azul", "apelido": "Demo Azul"})
		_criar_ou_renovar({"uniqueId": "demo_rosa", "apelido": "Demo Rosa"})
	_atualizar_ranking_local()


func _aplicar_config_janela() -> void:
	Engine.max_fps = maxi(1, int(Config.obter("janela", "fps", 60)))
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen := bool(Config.obter("janela", "fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var largura := maxi(320, int(Config.obter("janela", "largura", 720)))
		var altura := maxi(426, int(Config.obter("janela", "altura", 960)))
		DisplayServer.window_set_size(Vector2i(largura, altura))


func _process(delta: float) -> void:
	var limite := int(Config.obter("arena", "eventos_por_frame", 8))
	for evento in _api.retirar_eventos(limite):
		_aplicar_evento(evento)
	_atualizar_combos()
	_atualizar_quebroes(delta)
	_atualizar_ciclo(delta)
	# Dictionary.values() devolve Array sem tipo no Godot. Convertemos uma vez por
	# frame para não disparar erro de tipo em simular(Array[Pipa]).
	var pipas_ativas: Array[Pipa] = []
	for valor: Variant in _pipas.values():
		var pipa_tipagem := valor as Pipa
		if pipa_tipagem != null:
			pipas_ativas.append(pipa_tipagem)
	for pipa: Pipa in pipas_ativas:
		pipa.simular(delta, _limites, pipas_ativas)
	_combate_acumulado += delta
	var intervalo_combate := float(Config.obter("combate", "intervalo_simulacao_seg", 0.033))
	if _combate_acumulado >= intervalo_combate:
		_resolver_cortes(_combate_acumulado)
		_combate_acumulado = 0.0
	_atualizar_faiscas(delta)
	_atualizar_impactos(delta)
	_limitar_efeitos()
	_atualizar_monitor(delta)
	_ranking_local_acumulado += delta
	if _ranking_local_acumulado >= 1.0:
		_ranking_local_acumulado = 0.0
		if Time.get_ticks_msec() - _ranking_api_msec > 10000:
			_atualizar_ranking_local()
	_banner_restante = maxf(0.0, _banner_restante - delta)
	_banner.visible = _banner_restante > 0.0
	_presente_restante = maxf(0.0, _presente_restante - delta)
	$Hud/PresenteCard.visible = _presente_restante > 0.0
	_conquista_restante = maxf(0.0, _conquista_restante - delta)
	$Hud/ConquistaBanner.visible = _conquista_restante > 0.0
	queue_redraw()


func _draw() -> void:
	draw_rect(_limites, Color(1, 1, 1, 0.08), true)
	for pipa: Pipa in _pipas.values():
		if pipa.esta_voando():
			_desenhar_linha(pipa)
	for faisca: Dictionary in _faiscas:
		var cauda: Vector2 = faisca.posicao - faisca.velocidade.normalized() * faisca.raio * 3.5
		draw_line(cauda, faisca.posicao, faisca.cor, faisca.raio, true)
		draw_circle(faisca.posicao, faisca.raio * 0.72, Color(1.0, 0.96, 0.62, faisca.cor.a))
	for impacto: Dictionary in _impactos:
		var progresso: float = 1.0 - impacto.vida / impacto.vida_max
		var raio: float = lerpf(5.0, float(Config.obter("combate", "impacto_raio_max", 24.0)), progresso)
		var alfa: float = 1.0 - progresso
		draw_arc(impacto.posicao, raio, 0.0, TAU, 24, Color(1.0, 0.72, 0.08, alfa), 4.0, true)
		draw_line(impacto.posicao + Vector2(-raio, 0), impacto.posicao + Vector2(raio, 0), Color(1, 0.95, 0.7, alfa), 3.0, true)
		draw_line(impacto.posicao + Vector2(0, -raio), impacto.posicao + Vector2(0, raio), Color(1, 0.95, 0.7, alfa), 3.0, true)


func _desenhar_linha(pipa: Pipa) -> void:
	var cor := pipa.cor_da_linha()
	cor.a = 0.68
	var pontos := _obter_linha(pipa)
	draw_polyline(pontos, cor, minf(2.2, pipa.espessura_da_linha()), true)


func _desenhar_cerol_tita(pipa: Pipa, pontos: PackedVector2Array, cor: Color) -> void:
	# Pequenas lâminas luminosas acompanham a linha e deixam o cerol legível.
	for indice in range(2, pontos.size() - 1, 2):
		var direcao := (pontos[indice + 1] - pontos[indice - 1]).normalized()
		var normal := Vector2(-direcao.y, direcao.x)
		var oscilacao := sin(pipa.fase_vento * 6.0 + indice * 1.7)
		var centro := pontos[indice] + normal * oscilacao * 2.5
		var cor_lamina := Color("#fff5ad") if indice % 4 == 0 else cor.lightened(0.28)
		draw_line(centro - normal * 5.0, centro + normal * 5.0, cor_lamina, 2.2, true)
		draw_circle(centro, 2.2 + maxf(0.0, oscilacao), Color(1.0, 0.95, 0.62, 0.86))


func _obter_linha(pipa: Pipa) -> PackedVector2Array:
	var largura := get_viewport_rect().size.x
	var hash_ancora := absi(hash(pipa.unique_id + "|base_linha"))
	var posicao_pct := lerpf(0.06, 0.94, float(hash_ancora % 1000) / 999.0)
	var altura_base := 18.0 + float((hash_ancora / 1000) % 54)
	var ancora := Vector2(largura * posicao_pct, _limites.end.y + altura_base)
	var alvo := pipa.position + pipa.velocidade * 0.18
	var meio := (ancora + alvo) * 0.5
	var curvatura := float(Config.obter("movimento", "linha_curvatura", 16.0))
	var onda := sin(pipa.fase_vento * 1.7 + hash(pipa.unique_id + "|onda")) * float(Config.obter("movimento", "linha_onda", 3.5))
	meio.x += curvatura * pipa.direcao_lateral + onda
	meio.y += sin(pipa.fase_vento * 0.9 + hash(pipa.unique_id + "|altura")) * 8.0
	var pontos := PackedVector2Array()
	var segmentos := maxi(4, int(Config.obter("movimento", "linha_segmentos", 12)))
	for indice in segmentos + 1:
		var t := float(indice) / float(segmentos)
		pontos.append(ancora.bezier_interpolate(meio, meio, alvo, t))
	return pontos


func _resolver_cortes(delta: float) -> void:
	var ativas: Array[Pipa] = []
	var linhas: Dictionary = {}
	var areas: Dictionary = {}
	for pipa: Pipa in _pipas.values():
		if pipa.esta_voando():
			ativas.append(pipa)
			var linha := _obter_linha(pipa)
			linhas[pipa] = linha
			areas[pipa] = _area_da_linha(linha)
	for primeiro in range(ativas.size()):
		for segundo in range(primeiro + 1, ativas.size()):
			var a := ativas[primeiro]
			var b := ativas[segundo]
			if not (areas[a] as Rect2).intersects(areas[b] as Rect2):
				continue
			var cruzamento: Variant = _primeiro_cruzamento(linhas[a], linhas[b])
			if cruzamento == null:
				continue
			var altura_corte_pct := float(Config.obter("combate", "corte_altura_max_pct", 58.0)) / 100.0
			var limite_corte_y := _limites.position.y + _limites.size.y * altura_corte_pct
			if cruzamento.y > limite_corte_y:
				continue
			var velocidade_a := a.velocidade.length()
			var velocidade_b := b.velocidade.length()
			var atacante := a if velocidade_a + absf(a.velocidade.x) * 0.4 >= velocidade_b + absf(b.velocidade.x) * 0.4 else b
			var alvo := b if atacante == a else a
			var vetor_relativo := atacante.velocidade - alvo.velocidade
			var fator_velocidade := clampf(vetor_relativo.length() / maxf(1.0, float(Config.obter("arena", "velocidade_max", 115.0))), 0.0, 1.6)
			var vetor_corte := (atacante.position - alvo.position).normalized()
			var fator_angulo := 0.0
			if vetor_relativo.length_squared() > 0.01:
				var direcao_relativa := vetor_relativo.normalized()
				fator_angulo = clampf(absf(sin(direcao_relativa.angle_to(vetor_corte))), 0.0, 1.0)
			var dano := float(Config.obter("arena", "atrito_dps", 18.0)) * delta
			dano *= (1.0 + fator_velocidade * 0.85 + fator_angulo * 0.75)
			dano *= float(Config.obter("combate", "dano_contato_mult", 3.8))
			dano *= atacante.multiplicador_corte() * Eventos.modificador("corte_mult") * Eventos.modificador("dano_mult")
			if alvo.receber_dano(dano, atacante.unique_id):
				atacante.registrar_corte()
			_disparar_faisca(cruzamento, atacante.cor_detalhe, atacante.unique_id, alvo.unique_id)


func _primeiro_cruzamento(a: PackedVector2Array, b: PackedVector2Array) -> Variant:
	for ia in range(a.size() - 1):
		for ib in range(b.size() - 1):
			var ponto: Variant = Geometry2D.segment_intersects_segment(a[ia], a[ia + 1], b[ib], b[ib + 1])
			if ponto != null:
				return ponto
	return null


func _area_da_linha(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var minimo := pontos[0]
	var maximo := pontos[0]
	for ponto in pontos:
		minimo = minimo.min(ponto)
		maximo = maximo.max(ponto)
	return Rect2(minimo, maximo - minimo).grow(2.0)


func _disparar_faisca(posicao: Vector2, cor: Color, atacante_id: String, alvo_id: String) -> void:
	var chave := "%s|%s" % [atacante_id, alvo_id]
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - float(_ultimo_contato.get(chave, 0.0)) < float(Config.obter("combate", "intervalo_faisca_seg", 0.12)):
		return
	_ultimo_contato[chave] = agora
	var agora_msec := Time.get_ticks_msec()
	var intervalo_som_msec := int(float(Config.obter("som", "intervalo_som_contato_seg", 0.42)) * 1000.0)
	if agora_msec - _ultimo_som_contato_msec >= intervalo_som_msec:
		_ultimo_som_contato_msec = agora_msec
		Audio.tocar("contato")
	var duracao_impacto := float(Config.obter("combate", "impacto_duracao_seg", 0.42))
	_impactos.append({"posicao": posicao, "vida": duracao_impacto, "vida_max": duracao_impacto})
	var quantidade := int(Config.obter("combate", "faisca_quantidade", 7))
	for _indice in quantidade:
		var direcao := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var cores_fogo := [Color("#fff4a3"), Color("#ffd23f"), Color("#ff8c1a"), Color("#ff4d00")]
		_faiscas.append({
			"posicao": posicao,
			"velocidade": direcao * randf_range(25.0, float(Config.obter("combate", "faisca_velocidade", 75.0))),
			"vida": float(Config.obter("combate", "faisca_duracao_seg", 0.35)),
			"vida_max": float(Config.obter("combate", "faisca_duracao_seg", 0.35)),
			"raio": randf_range(2.0, 5.0),
			"cor": cores_fogo[randi() % cores_fogo.size()].lerp(cor, 0.12)
		})


func _atualizar_faiscas(delta: float) -> void:
	for indice in range(_faiscas.size() - 1, -1, -1):
		var faisca := _faiscas[indice]
		faisca.vida -= delta
		if faisca.vida <= 0.0:
			_faiscas.remove_at(indice)
			continue
		faisca.posicao += faisca.velocidade * delta
		faisca.velocidade *= 0.92
		faisca.cor.a = faisca.vida / faisca.vida_max
		_faiscas[indice] = faisca


func _atualizar_impactos(delta: float) -> void:
	for indice in range(_impactos.size() - 1, -1, -1):
		_impactos[indice].vida -= delta
		if _impactos[indice].vida <= 0.0:
			_impactos.remove_at(indice)


func _limitar_efeitos() -> void:
	var max_faiscas := int(Config.obter("robustez", "max_faiscas", 360))
	var max_impactos := int(Config.obter("robustez", "max_impactos", 80))
	while _faiscas.size() > max_faiscas:
		_faiscas.remove_at(0)
	while _impactos.size() > max_impactos:
		_impactos.remove_at(0)


func _atualizar_monitor(delta: float) -> void:
	var monitor: Label = $Hud/Desempenho
	monitor.visible = bool(Config.obter("robustez", "mostrar_monitor", false))
	if not monitor.visible:
		return
	_monitor_acumulado += delta
	if _monitor_acumulado < float(Config.obter("robustez", "monitor_intervalo_seg", 1.0)):
		return
	_monitor_acumulado = 0.0
	monitor.text = "FPS %d  •  PIPAS %d\nFILA %d  •  DESCARTADOS %d\nFX %d" % [
		Engine.get_frames_per_second(), _pipas.size(), _api.tamanho_fila(),
		_api.eventos_descartados(), _faiscas.size() + _impactos.size()
	]


func _aplicar_evento(evento: Dictionary) -> void:
	var tipo := str(evento.get("tipo", ""))
	if tipo == "PRESENTE":
		_agregar_presente(evento)
		return
	Eventos.registrar_evento_live(evento)
	if tipo in ["COMENTARIO", "LIKE", "PRESENTE", "SEGUIDOR", "COMPARTILHAMENTO"]:
		var usuario: Variant = evento.get("usuario", {})
		if usuario is Dictionary:
			var pipa := _criar_ou_renovar(usuario)
			if pipa == null:
				return
			if tipo == "COMENTARIO":
				Audio.tocar("comentario")
			var pontos_recebidos := float(evento.get("pontos", 0)) * Eventos.modificador("pontos_mult")
			pipa.aplicar_pontos(pontos_recebidos)
			_somar_pontos_ciclo(pipa.unique_id, pontos_recebidos)
			if tipo == "LIKE":
				var dados_like: Variant = evento.get("detalhes", {})
				if dados_like is Dictionary:
					pipa.curar_por_likes(int(dados_like.get("quantidade", 1)))
			elif tipo in ["SEGUIDOR", "COMPARTILHAMENTO"]:
				pipa.ativar_escudo()
				_banner.text = "@%s %s A LIVE!" % [pipa.unique_id, "SEGUIU" if tipo == "SEGUIDOR" else "COMPARTILHOU"]
				_banner_restante = 1.8
				Audio.tocar("escudo")


func _agregar_presente(evento: Dictionary) -> void:
	var usuario: Dictionary = evento.get("usuario", {})
	var detalhes: Dictionary = evento.get("detalhes", {})
	var uid := str(usuario.get("uniqueId", ""))
	var gift_id := str(detalhes.get("giftId", detalhes.get("giftName", "desconhecido")))
	if uid.is_empty():
		return
	var chave := "%s|%s" % [uid, gift_id]
	var quantidade := maxi(1, int(detalhes.get("quantidade", 1)))
	if _combos_pendentes.has(chave):
		var combo: Dictionary = _combos_pendentes[chave]
		combo.evento = evento.duplicate(true)
		combo.quantidade = maxi(int(combo.quantidade), quantidade)
		combo.pontos = maxf(float(combo.pontos), float(evento.get("pontos", 0.0)))
		combo.ultimo_msec = Time.get_ticks_msec()
		_combos_pendentes[chave] = combo
	else:
		_combos_pendentes[chave] = {
			"evento": evento.duplicate(true), "quantidade": quantidade,
			"pontos": float(evento.get("pontos", 0.0)), "ultimo_msec": Time.get_ticks_msec()
		}


func _atualizar_combos() -> void:
	var janela_msec := int(float(Config.obter("presentes", "combo_janela_seg", 0.55)) * 1000.0)
	var agora := Time.get_ticks_msec()
	var prontos: Array[String] = []
	for chave: String in _combos_pendentes.keys():
		if agora - int(_combos_pendentes[chave].ultimo_msec) >= janela_msec:
			prontos.append(chave)
	for chave in prontos:
		var combo: Dictionary = _combos_pendentes[chave]
		_combos_pendentes.erase(chave)
		_aplicar_presente_agregado(combo)


func _aplicar_presente_agregado(combo: Dictionary) -> void:
	var evento: Dictionary = combo.evento
	var usuario: Dictionary = evento.get("usuario", {})
	var detalhes: Dictionary = evento.get("detalhes", {}).duplicate(true)
	detalhes.quantidade = int(combo.quantidade)
	evento.detalhes = detalhes
	Eventos.registrar_evento_live(evento)
	var pipa := _criar_ou_renovar(usuario)
	if pipa == null:
		return
	var nome_gift := str(detalhes.get("giftName", "Presente"))
	var mapa: Dictionary = Config.obter("presentes", "por_gift", {})
	var regra: Dictionary = mapa.get(nome_gift, {})
	var pontos_evento := float(combo.pontos)
	if bool(Config.obter("presentes", "usar_pontuacao_local", false)):
		pontos_evento = float(regra.get("pontos", Config.obter("presentes", "pontos_por_diamante", 1.0))) * int(combo.quantidade)
	var pontos_finais := pontos_evento * Eventos.modificador("pontos_mult")
	pipa.aplicar_pontos(pontos_finais)
	_somar_pontos_ciclo(pipa.unique_id, pontos_finais)
	pipa.aplicar_presente(detalhes)
	_vips_ciclo[pipa.unique_id] = true
	var efeito := str(regra.get("efeito", ""))
	if efeito == "CACA_E_DERRUBA":
		var alvo := _inimigo_mais_proximo(pipa)
		if alvo != null:
			pipa.iniciar_caca(alvo)
	elif efeito == "DERRUBA_TRES":
		if not bool(Config.obter("quebrao", "ativado", true)):
			_derrubar_proximos(pipa, int(Config.obter("presentes", "derruba_tres_max_alvos", 3)))
	_mostrar_card_presente(pipa, nome_gift, int(combo.quantidade), efeito)
	_presente_restante = float(Config.obter("presentes", "banner_compacto_seg", 2.2))
	_agendar_quebrao(pipa, int(combo.quantidade), nome_gift)


func _mostrar_card_presente(pipa: Pipa, nome_gift: String, quantidade: int, efeito: String) -> void:
	var card: Control = $Hud/PresenteCard
	_presente_uid = pipa.unique_id
	card.get_node("Icone").text = _icone_presente(nome_gift)
	card.get_node("Titulo").hide()
	card.get_node("Detalhe").text = "×%d" % quantidade
	card.get_node("Avatar").texture = pipa.avatar.texture
	card.visible = true
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.78, 0.78)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.14)


func _icone_presente(nome_gift: String) -> String:
	match nome_gift.to_lower():
		"rosa": return "🌹"
		"rosquinha": return "🍩"
		"perfume": return "💎"
		"mini dino": return "🦖"
	return "🎁"


func _agendar_quebrao(pipa: Pipa, quantidade: int, nome_gift: String) -> void:
	if not bool(Config.obter("quebrao", "ativado", true)):
		return
	var uid := pipa.unique_id
	var agora := Time.get_ticks_msec()
	var espera_msec := int(float(Config.obter("presentes", "banner_compacto_seg", 2.2)) * 1000.0)
	if _quebroes_pendentes.has(uid):
		var pendente: Dictionary = _quebroes_pendentes[uid]
		pendente.quantidade = int(pendente.get("quantidade", 0)) + quantidade
		pendente.gifts = int(pendente.get("gifts", 0)) + 1
		pendente.pronto_msec = agora + espera_msec
		pendente.nome_gift = nome_gift
		_quebroes_pendentes[uid] = pendente
		return
	_quebroes_pendentes[uid] = {
		"uid": uid, "quantidade": quantidade, "gifts": 1, "nome_gift": nome_gift,
		"pronto_msec": maxi(agora + espera_msec, int(_cooldown_quebrao.get(uid, 0)))
	}
	_fila_quebroes.append(uid)


func _atualizar_quebroes(delta: float) -> void:
	if not bool(Config.obter("quebrao", "ativado", true)):
		$Hud/QuebraoCard.hide()
		_cenario.finalizar_quebrao_canonico()
		_quebroes_pendentes.clear()
		_fila_quebroes.clear()
		_quebrao_ativo.clear()
		return
	if _quebrao_ativo.is_empty():
		_tentar_iniciar_proximo_quebrao()
		return
	var uid := str(_quebrao_ativo.get("uid", ""))
	var pipa := _pipas.get(uid) as Pipa
	var fase := str(_quebrao_ativo.get("fase", ""))
	_quebrao_ativo.tempo = maxf(0.0, float(_quebrao_ativo.get("tempo", 0.0)) - delta)
	if fase == "anuncio":
		if float(_quebrao_ativo.tempo) <= 0.0:
			var intensidade := float(_quebrao_ativo.get("intensidade", 0.0))
			var duracao_ataque := float(Config.obter("quebrao", "duracao_ataque_seg", 2.8)) * lerpf(1.0, 1.55, intensidade)
			if pipa == null:
				pipa = _criar_ou_renovar(_participantes_batalha.get(uid, {"uniqueId": uid, "apelido": uid}))
			if pipa == null or not pipa.iniciar_quebrao(duracao_ataque, intensidade):
				_quebrao_ativo.tempo = 0.25
				return
			_quebrao_ativo.fase = "ataque"
			_quebrao_ativo.tempo = duracao_ataque
			_quebrao_ativo.duracao = float(_quebrao_ativo.tempo)
			_quebrao_fx_acumulado = 0.0
			Audio.tocar("quebrao")
			$Hud/QuebraoCard.hide()
	elif fase == "ataque":
		_atualizar_fx_quebrao(delta, pipa)
		var alvos: Array = _quebrao_ativo.get("alvos", [])
		var proximo := int(_quebrao_ativo.get("proximo_alvo", 0))
		var duracao := maxf(0.1, float(_quebrao_ativo.get("duracao", 2.8)))
		var decorrido := duracao - float(_quebrao_ativo.tempo)
		while proximo < alvos.size() and decorrido >= duracao * float(proximo + 1) / float(alvos.size() + 1):
			var alvo := _pipas.get(str(alvos[proximo])) as Pipa
			if alvo != null and alvo.esta_voando():
				alvo.forcar_queda(uid)
				_quebrao_ativo.cortes = int(_quebrao_ativo.get("cortes", 0)) + 1
			proximo += 1
			_quebrao_ativo.proximo_alvo = proximo
		if float(_quebrao_ativo.tempo) <= 0.0 or pipa == null:
			_mostrar_resultado_quebrao()
	elif fase == "resultado" and float(_quebrao_ativo.tempo) <= 0.0:
		$Hud/QuebraoCard.hide()
		_cenario.finalizar_quebrao_canonico()
		_cooldown_quebrao[uid] = Time.get_ticks_msec() + int(float(Config.obter("quebrao", "cooldown_usuario_seg", 12.0)) * 1000.0)
		_quebrao_ativo.clear()


func _tentar_iniciar_proximo_quebrao() -> void:
	if _presente_restante > 0.0:
		return
	while not _fila_quebroes.is_empty() and not _quebroes_pendentes.has(_fila_quebroes[0]):
		_fila_quebroes.pop_front()
	if _fila_quebroes.is_empty():
		return
	var agora := Time.get_ticks_msec()
	var uid: String = _fila_quebroes[0]
	var pendente: Dictionary = _quebroes_pendentes[uid]
	if agora < maxi(int(pendente.get("pronto_msec", 0)), int(_cooldown_quebrao.get(uid, 0))):
		return
	var pipa := _pipas.get(uid) as Pipa
	if pipa == null:
		pipa = _criar_ou_renovar(_participantes_batalha.get(uid, {"uniqueId": uid, "apelido": uid}))
	if pipa == null or not pipa.esta_voando():
		return
	var quantidade := maxi(1, int(pendente.get("quantidade", 1)))
	var intensidade := _calcular_intensidade_quebrao(quantidade)
	var bonus := quantidade / maxi(1, int(Config.obter("quebrao", "presentes_por_alvo_extra", 5)))
	var max_alvos := int(Config.obter("quebrao", "max_alvos", 5)) + int(round(intensidade * 5.0))
	var limite := mini(max_alvos, int(Config.obter("quebrao", "alvos_base", 2)) + bonus)
	var alvos := _selecionar_alvos_quebrao(pipa, limite)
	_quebrao_ativo = {
		"uid": uid, "fase": "anuncio", "tempo": float(Config.obter("quebrao", "aviso_seg", 1.4)),
		"alvos": alvos, "proximo_alvo": 0, "cortes": 0,
		"quantidade": quantidade, "intensidade": intensidade
	}
	_fila_quebroes.pop_front()
	_quebroes_pendentes.erase(uid)
	_cenario.iniciar_quebrao_canonico(intensidade)
	_mostrar_aviso_quebrao(pipa, alvos.size())


func _calcular_intensidade_quebrao(quantidade: int) -> float:
	var max_combo := maxf(2.0, float(Config.obter("quebrao", "rosas_intensidade_maxima", 50.0)))
	return clampf(log(float(maxi(1, quantidade)) + 1.0) / log(max_combo + 1.0), 0.08, 1.0)


func _nome_intensidade_quebrao(intensidade: float) -> String:
	if intensidade >= 0.92:
		return "EVENTO CANÔNICO"
	if intensidade >= 0.68:
		return "CATACLISMO"
	if intensidade >= 0.4:
		return "TEMPESTADE"
	return "TURBO"


func _atualizar_fx_quebrao(delta: float, pipa: Pipa) -> void:
	if pipa == null:
		return
	var intensidade := float(_quebrao_ativo.get("intensidade", 0.0))
	_quebrao_fx_acumulado += delta
	var intervalo := lerpf(0.22, 0.055, intensidade)
	while _quebrao_fx_acumulado >= intervalo:
		_quebrao_fx_acumulado -= intervalo
		var angulo := randf_range(0.0, TAU)
		var distancia := randf_range(16.0, 56.0 + intensidade * 55.0)
		var posicao := pipa.position + Vector2.RIGHT.rotated(angulo) * distancia
		var duracao := lerpf(0.35, 0.9, intensidade)
		_faiscas.append({
			"posicao": posicao,
			"velocidade": posicao.direction_to(pipa.position) * randf_range(80.0, 210.0),
			"vida": duracao, "vida_max": duracao,
			"raio": randf_range(3.0, 7.0 + intensidade * 5.0),
			"cor": Color("#fff176") if randi() % 2 == 0 else Color("#ff2f92")
		})


func _selecionar_alvos_quebrao(origem: Pipa, limite: int) -> Array[String]:
	var candidatos: Array[Pipa] = []
	for candidato: Pipa in _pipas.values():
		if candidato != origem and candidato.esta_voando():
			candidatos.append(candidato)
	candidatos.sort_custom(func(a: Pipa, b: Pipa) -> bool:
		return origem.position.distance_squared_to(a.position) < origem.position.distance_squared_to(b.position))
	var resultado: Array[String] = []
	for indice in mini(limite, candidatos.size()):
		resultado.append(candidatos[indice].unique_id)
	return resultado


func _mostrar_aviso_quebrao(pipa: Pipa, alvos: int) -> void:
	var card: Control = $Hud/QuebraoCard
	var intensidade := float(_quebrao_ativo.get("intensidade", 0.0))
	var quantidade := int(_quebrao_ativo.get("quantidade", 1))
	card.get_node("Titulo").text = "⚡ QUEBRÃO DE @%s! ⚡" % pipa.unique_id
	card.get_node("Detalhe").text = "MERGULHO ARMADO • %d ALVOS" % alvos
	card.get_node("Detalhe").text = "%s ×%d • %d ALVOS" % [_nome_intensidade_quebrao(intensidade), quantidade, alvos]
	card.show()
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK)
	Audio.tocar("quebrao_aviso")


func _mostrar_resultado_quebrao() -> void:
	var uid := str(_quebrao_ativo.get("uid", ""))
	var cortes := int(_quebrao_ativo.get("cortes", 0))
	var intensidade := float(_quebrao_ativo.get("intensidade", 0.0))
	var card: Control = $Hud/QuebraoCard
	card.get_node("Titulo").text = "🏆 QUEBRÃO CONCLUÍDO!"
	card.get_node("Detalhe").text = "@%s cortou %d %s!" % [uid, cortes, "pipa" if cortes == 1 else "pipas"]
	card.get_node("Detalhe").text = "@%s cortou %d %s • %s!" % [uid, cortes, "pipa" if cortes == 1 else "pipas", _nome_intensidade_quebrao(intensidade)]
	card.show()
	card.scale = Vector2(0.82, 0.82)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
	Audio.tocar("quebrao_resultado")
	_quebrao_ativo.fase = "resultado"
	_quebrao_ativo.tempo = float(Config.obter("quebrao", "resultado_seg", 3.2))


func _cancelar_quebrao_ativo() -> void:
	$Hud/QuebraoCard.hide()
	_cenario.finalizar_quebrao_canonico()
	_quebrao_ativo.clear()


func _inimigo_mais_proximo(origem: Pipa) -> Pipa:
	var escolhido: Pipa
	var menor_distancia := INF
	for candidato: Pipa in _pipas.values():
		if candidato == origem or not candidato.esta_voando():
			continue
		var distancia := origem.position.distance_squared_to(candidato.position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			escolhido = candidato
	return escolhido


func _derrubar_proximos(origem: Pipa, quantidade: int) -> void:
	var alvos: Array[Pipa] = []
	for candidato: Pipa in _pipas.values():
		if candidato != origem and candidato.esta_voando():
			alvos.append(candidato)
	alvos.sort_custom(func(a: Pipa, b: Pipa) -> bool:
		return origem.position.distance_squared_to(a.position) < origem.position.distance_squared_to(b.position))
	for indice in mini(quantidade, alvos.size()):
		alvos[indice].receber_dano(alvos[indice].hp_max * 2.0, origem.unique_id)


func _criar_ou_renovar(usuario: Dictionary) -> Pipa:
	var uid := str(usuario.get("uniqueId", "")).strip_edges()
	if uid.is_empty():
		return null
	_participantes_batalha[uid] = usuario.duplicate(true)
	if not _pontuacao_ciclo.has(uid):
		_pontuacao_ciclo[uid] = 0.0
	if _batalha_encerrada:
		return null
	if _pipas.has(uid):
		_pipas[uid].configurar(usuario)
		return _pipas[uid]
	if _pipas.size() >= int(Config.obter("arena", "max_pipas", 40)):
		return null
	var pipa: Pipa
	if _pool.is_empty():
		pipa = PIPA_CENA.instantiate()
		_pipas_node.add_child(pipa)
		pipa.queda_finalizada.connect(_ao_finalizar_queda)
		pipa.queda_iniciada.connect(_ao_iniciar_queda)
		pipa.marco_vida_atingido.connect(_ao_marco_vida)
	else:
		pipa = _pool.pop_back()
	var topo_spawn := _limites.position.y + _limites.size.y * float(Config.obter("movimento", "zona_vertical_topo_pct", 8)) / 100.0
	var baixo_spawn := _limites.position.y + _limites.size.y * float(Config.obter("movimento", "zona_vertical_baixo_pct", 68)) / 100.0
	pipa.position = Vector2(randf_range(_limites.position.x, _limites.end.x), randf_range(topo_spawn, baixo_spawn))
	pipa.configurar(usuario)
	if _vips_ciclo.has(uid):
		pipa.ativar_vip()
	_pipas[uid] = pipa
	_atualizar_lider()
	return pipa


func _ao_finalizar_queda(pipa: Pipa, atacante_id: String) -> void:
	if _pipas.get(pipa.unique_id) == pipa:
		_pipas.erase(pipa.unique_id)
	pipa.desativar()
	_pool.append(pipa)


func _ao_iniciar_queda(pipa: Pipa, atacante_id: String) -> void:
	Audio.tocar("corte")
	var atacante: Pipa = _pipas.get(atacante_id) as Pipa
	if not atacante_id.is_empty():
		_cortes_ciclo[atacante_id] = int(_cortes_ciclo.get(atacante_id, 0)) + 1
	var nome_atacante := atacante.apelido if atacante != null else atacante_id
	_banner.text = "%s CORTOU @%s!" % [nome_atacante, pipa.unique_id]
	_banner_restante = float(Config.obter("combate", "banner_corte_seg", 1.8))
	var duracao := float(Config.obter("combate", "impacto_duracao_seg", 0.42)) * 1.8
	_impactos.append({"posicao": pipa.position, "vida": duracao, "vida_max": duracao})
	for indice in int(Config.obter("combate", "faisca_quantidade", 7)) * 3:
		var angulo := TAU * float(indice) / float(maxi(1, int(Config.obter("combate", "faisca_quantidade", 7)) * 3))
		_faiscas.append({
			"posicao": pipa.position,
			"velocidade": Vector2.RIGHT.rotated(angulo) * randf_range(65.0, 145.0),
			"vida": duracao,
			"vida_max": duracao,
			"raio": randf_range(3.0, 6.0),
			"cor": Color("#ff8c1a")
		})


func _ao_marco_vida(pipa: Pipa, valor: int, definicao: Dictionary) -> void:
	pipa.aplicar_recompensa_marco(definicao)
	var conquista: Label = $Hud/ConquistaBanner
	conquista.text = "@%s CHEGOU A %d HP!\n%s" % [pipa.unique_id, valor, str(definicao.get("nome", "CONQUISTA DESBLOQUEADA"))]
	conquista.show()
	conquista.scale = Vector2(0.68, 0.68)
	_conquista_restante = float(Config.obter("engajamento", "banner_marco_seg", 4.5))
	create_tween().tween_property(conquista, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_ELASTIC)
	Audio.tocar("marco")
	var quantidade := int(Config.obter("engajamento", "particulas_marco", 34))
	for indice in quantidade:
		var angulo := TAU * float(indice) / float(maxi(1, quantidade))
		var cor := Color("#ffd23f") if indice % 2 == 0 else pipa.cor_detalhe
		_faiscas.append({
			"posicao": pipa.position,
			"velocidade": Vector2.RIGHT.rotated(angulo) * randf_range(90.0, 210.0),
			"vida": 0.85,
			"vida_max": 0.85,
			"raio": randf_range(3.0, 7.0),
			"cor": cor
		})


func _atualizar_ciclo(delta: float) -> void:
	if not bool(Config.obter("ciclos", "ativados", true)) or _batalha_encerrada:
		return
	_tempo_ciclo_restante = maxf(0.0, _tempo_ciclo_restante - delta)
	var minutos := int(_tempo_ciclo_restante) / 60
	var segundos := int(_tempo_ciclo_restante) % 60
	$Hud/Ciclo.visible = bool(Config.obter("ciclos", "mostrar_contagem", true))
	$Hud/Ciclo.text = "CICLO %02d:%02d" % [minutos, segundos]
	if _tempo_ciclo_restante <= 0.0:
		if _ha_interacoes_pendentes():
			$Hud/Ciclo.text = "CICLO ENCERRANDO..."
			return
		_encerrar_ciclo()


func _ha_interacoes_pendentes() -> bool:
	return not _combos_pendentes.is_empty() or not _fila_quebroes.is_empty() or not _quebroes_pendentes.is_empty() or not _quebrao_ativo.is_empty() or _presente_restante > 0.0


func _encerrar_ciclo() -> void:
	if _pontuacao_ciclo.is_empty():
		_reiniciar_relogio_ciclo()
		return
	var campeao_id := ""
	var maior_pontuacao := -INF
	for uid: String in _pontuacao_ciclo.keys():
		if float(_pontuacao_ciclo[uid]) > maior_pontuacao:
			maior_pontuacao = float(_pontuacao_ciclo[uid])
			campeao_id = uid
	if campeao_id.is_empty():
		_reiniciar_relogio_ciclo()
		return
	_batalha_encerrada = true
	var perfil: Dictionary = _participantes_batalha.get(campeao_id, {})
	var nome := str(perfil.get("apelido", campeao_id)).strip_edges()
	if nome.is_empty():
		nome = campeao_id
	var textura: Texture2D = AvatarCache.obter(campeao_id)
	if _pipas.has(campeao_id) and _pipas[campeao_id].avatar.texture != null:
		textura = _pipas[campeao_id].avatar.texture
	var duracao_ciclo := float(Config.obter("ciclos", "duracao_minutos", 5.0)) * 60.0
	Audio.tocar("campeao")
	_vitoria.mostrar(nome, campeao_id, int(round(maior_pontuacao)), int(_cortes_ciclo.get(campeao_id, 0)), duracao_ciclo, textura)


func _reiniciar_relogio_ciclo() -> void:
	_tempo_ciclo_restante = maxf(1.0, float(Config.obter("ciclos", "duracao_minutos", 5.0)) * 60.0)


func _solicitar_reinicio_ciclo() -> void:
	if _reset_ciclo_pendente:
		return
	_reset_ciclo_pendente = true
	_tentativas_reset += 1
	_status.text = "LIVE: sincronizando novo ciclo..."
	if not _api.reiniciar_ranking(bool(Config.obter("ciclos", "manter_nicks_ao_resetar", true))):
		_reset_ciclo_pendente = false


func _ao_reset_ciclo_concluido(sucesso: bool, codigo: int, mensagem: String) -> void:
	_reset_ciclo_pendente = false
	if sucesso:
		print("[JOGO] Gateway confirmou o reset do ranking. Iniciando nova rodada.")
		_tentativas_reset = 0
		_iniciar_nova_batalha()
		return
	push_warning("[JOGO] Falha ao resetar ranking no Gateway. HTTP %d: %s" % [codigo, mensagem])
	_status.text = "LIVE: aguardando Gateway para reiniciar..."
	var espera := float(Config.obter("ciclos", "retry_reset_seg", 2.0))
	await get_tree().create_timer(maxf(0.5, espera)).timeout
	if _batalha_encerrada and not _reset_ciclo_pendente:
		_solicitar_reinicio_ciclo()


func _iniciar_nova_batalha() -> void:
	for pipa: Pipa in _pipas.values():
		pipa.desativar()
		if not _pool.has(pipa):
			_pool.append(pipa)
	_pipas.clear()
	_batalha_encerrada = false
	_inicio_batalha_msec = Time.get_ticks_msec()
	_pontuacao_ciclo.clear()
	_cortes_ciclo.clear()
	_lider_uid = ""
	_vips_ciclo.clear()
	_quebroes_pendentes.clear()
	_fila_quebroes.clear()
	_quebrao_ativo.clear()
	_cooldown_quebrao.clear()
	_combos_pendentes.clear()
	_ultimo_contato.clear()
	_faiscas.clear()
	_impactos.clear()
	_banner_restante = 0.0
	_presente_restante = 0.0
	_conquista_restante = 0.0
	_presente_uid = ""
	$Hud/Banner.hide()
	$Hud/PresenteCard.hide()
	$Hud/ConquistaBanner.hide()
	$Hud/QuebraoCard.hide()
	_cenario.finalizar_quebrao_canonico()
	_reiniciar_relogio_ciclo()
	_participantes_batalha.clear()


func _executar_comando(comando: Dictionary) -> void:
	var tipo := str(comando.get("cmd", ""))
	var usuario := str(comando.get("user", "teste_painel")).strip_edges()
	match tipo:
		"simular_comentario":
			_aplicar_evento({
				"tipo": "COMENTARIO", "acao": "CHAT", "pontos": 5,
				"usuario": {"uniqueId": usuario, "apelido": usuario, "avatar": ""},
				"detalhes": {"mensagem": "Teste pelo painel"}
			})
		"simular_presente":
			_aplicar_evento({
				"tipo": "PRESENTE", "acao": "SPAWN", "pontos": 10,
				"usuario": {"uniqueId": usuario, "apelido": usuario, "avatar": ""},
				"detalhes": {
					"giftName": str(comando.get("gift", "Rosa")),
					"quantidade": int(comando.get("qtd", 1)), "diamantes": 1
				}
			})
		"simular_like":
			_aplicar_evento({
				"tipo": "LIKE", "acao": "BOOST", "pontos": int(comando.get("qtd", 1)),
				"usuario": {"uniqueId": usuario, "apelido": usuario, "avatar": ""},
				"detalhes": {"quantidade": int(comando.get("qtd", 1))}
			})
		"simular_seguidor", "simular_compartilhamento":
			var evento_tipo := "SEGUIDOR" if tipo == "simular_seguidor" else "COMPARTILHAMENTO"
			_aplicar_evento({
				"tipo": evento_tipo,
				"acao": "FOLLOW" if evento_tipo == "SEGUIDOR" else "SHARE",
				"pontos": 20,
				"usuario": {"uniqueId": usuario, "apelido": usuario, "avatar": ""},
				"detalhes": {}
			})
		"nova_batalha", "zerar_partida":
			_solicitar_reinicio_ciclo()
		"escudo_geral":
			for pipa: Pipa in _pipas.values():
				pipa.ativar_escudo()
		"recarregar":
			Config.recarregar()
		"evento":
			Eventos.ativar(str(comando.get("id", "")))
		"encerrar_eventos":
			Eventos.encerrar_todos()
		"teste_estresse":
			_criar_teste_estresse()
		"teste_vitoria":
			_forcar_campeao_teste()
		"testar_som":
			Audio.tocar(str(comando.get("som", "presente")))
		_:
			push_warning("Comando desconhecido ignorado: %s" % tipo)


func _mostrar_banner_evento(texto: String, duracao: float) -> void:
	_banner.text = texto
	_banner_restante = duracao
	Audio.tocar("presente")


func _atualizar_eventos_hud(texto: String) -> void:
	$Hud/EventosAtivos.text = texto


func _criar_teste_estresse() -> void:
	var maximo := int(Config.obter("arena", "max_pipas", 40))
	for indice in maximo:
		_criar_ou_renovar({
			"uniqueId": "stress_%02d" % indice,
			"apelido": "Teste %02d" % (indice + 1),
			"avatar": ""
		})
	_atualizar_ranking_local()


func _forcar_campeao_teste() -> void:
	if _pontuacao_ciclo.is_empty():
		for pipa: Pipa in _pipas.values():
			_somar_pontos_ciclo(pipa.unique_id, maxf(1.0, pipa.pontos))
	_encerrar_ciclo()


func _somar_pontos_ciclo(uid: String, pontos: float) -> void:
	_pontuacao_ciclo[uid] = float(_pontuacao_ciclo.get(uid, 0.0)) + maxf(0.0, pontos)
	_atualizar_lider()
	_atualizar_ranking_local()


func _atualizar_lider() -> void:
	var novo_lider := ""
	var maior := -INF
	for uid: String in _pontuacao_ciclo.keys():
		var valor := float(_pontuacao_ciclo.get(uid, 0.0))
		if valor > maior:
			maior = valor
			novo_lider = uid
	if novo_lider.is_empty() and not _ranking_dados.is_empty():
		novo_lider = str(_ranking_dados[0].get("uniqueId", ""))
	if novo_lider == _lider_uid:
		for uid: String in _pipas.keys():
			_pipas[uid].definir_lider(uid == novo_lider)
		return
	var lider_anterior := _lider_uid
	_lider_uid = novo_lider
	for uid: String in _pipas.keys():
		_pipas[uid].definir_lider(uid == novo_lider)
	if not novo_lider.is_empty() and not lider_anterior.is_empty():
		Audio.tocar("lider")
		var perfil: Dictionary = _participantes_batalha.get(novo_lider, {})
		var nome := str(perfil.get("apelido", novo_lider))
		_banner.text = "👑 %s ASSUMIU A LIDERANÇA!" % nome
		_banner_restante = float(Config.obter("ranking", "banner_lider_seg", 2.2))


func _ao_recarregar_config(_dados: Dictionary) -> void:
	var tamanho := get_viewport_rect().size
	if tamanho.x <= 1.0 or tamanho.y <= 1.0:
		tamanho = DisplayServer.window_get_size()
	if tamanho.x <= 1.0 or tamanho.y <= 1.0:
		tamanho = Vector2(720.0, 960.0)
	var lateral := tamanho.x * float(Config.obter("area_jogo", "margem_lateral_pct", 4)) / 100.0
	var topo := tamanho.y * float(Config.obter("area_jogo", "margem_topo_pct", 14)) / 100.0
	var baixo := tamanho.y * float(Config.obter("area_jogo", "margem_baixo_pct", 22)) / 100.0
	_limites = Rect2(lateral, topo, maxf(1.0, tamanho.x - lateral * 2.0), maxf(1.0, tamanho.y - topo - baixo))
	$Hud/Instrucao.text = str(Config.dados.get("texto_fixo", ""))


func _atualizar_ranking(top: Array) -> void:
	_ranking_api_msec = Time.get_ticks_msec()
	# A API e os eventos chegam em ritmos diferentes. Nunca troca o placar inteiro
	# por uma fotografia atrasada: incorpora somente totais válidos e crescentes.
	for item_var: Variant in top:
		if not item_var is Dictionary:
			continue
		var item: Dictionary = item_var
		var uid := str(item.get("uniqueId", "")).strip_edges()
		var pontos_api := float(item.get("pontos", -1.0))
		if uid.is_empty() or not is_finite(pontos_api) or pontos_api < 0.0:
			continue
		_pontuacao_ciclo[uid] = maxf(float(_pontuacao_ciclo.get(uid, 0.0)), pontos_api)
		var perfil: Dictionary = _participantes_batalha.get(uid, {})
		perfil.apelido = str(item.get("nickname", item.get("nickJogo", perfil.get("apelido", uid))))
		perfil.avatar = str(item.get("avatar", perfil.get("avatar", "")))
		_participantes_batalha[uid] = perfil
	_atualizar_lider()
	_atualizar_ranking_local()


func _atualizar_ranking_local() -> void:
	var top: Array = []
	for uid: String in _pontuacao_ciclo.keys():
		var perfil: Dictionary = _participantes_batalha.get(uid, {})
		top.append({
			"uniqueId": uid, "nickname": str(perfil.get("apelido", uid)),
			"pontos": int(_pontuacao_ciclo.get(uid, 0)), "avatar": str(perfil.get("avatar", ""))
		})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.pontos) > float(b.pontos))
	_ranking_dados = top.slice(0, 3)
	_renderizar_ranking()


func _renderizar_ranking() -> void:
	var lista: VBoxContainer = $Hud/RankingLista
	var quantidade_exibida := mini(3, _ranking_dados.size())
	var altura_painel := 51.0 + quantidade_exibida * 37.0
	var fundo: ColorRect = $Hud/RankingFundo
	fundo.offset_bottom = fundo.offset_top + altura_painel
	lista.offset_bottom = fundo.offset_bottom - 9.0
	for filho in lista.get_children():
		lista.remove_child(filho)
		filho.queue_free()
	var titulo := Label.new()
	titulo.text = "🏆  TOP DA LIVE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color("#ffd54a"))
	lista.add_child(titulo)
	var medalhas := ["🥇", "🥈", "🥉"]
	for indice in quantidade_exibida:
		var item: Dictionary = _ranking_dados[indice]
		var uid := str(item.get("uniqueId", "?"))
		var nome := str(item.get("nickname", item.get("nickJogo", uid))).strip_edges()
		if nome.is_empty() or nome == "<null>":
			nome = str(item.get("nickJogo", uid))
		var linha := HBoxContainer.new()
		linha.custom_minimum_size.y = 34.0
		linha.add_theme_constant_override("separation", 7)
		lista.add_child(linha)
		var medalha := Label.new()
		medalha.text = medalhas[indice]
		medalha.custom_minimum_size.x = 27.0
		medalha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		medalha.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		medalha.add_theme_font_size_override("font_size", 16)
		linha.add_child(medalha)
		var textura := AvatarCache.obter(uid)
		if textura != null:
			var foto := TextureRect.new()
			foto.custom_minimum_size = Vector2(29, 29)
			foto.texture = textura
			foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			linha.add_child(foto)
		else:
			var inicial_ranking := Label.new()
			inicial_ranking.text = nome.left(1).to_upper()
			inicial_ranking.custom_minimum_size = Vector2(29, 29)
			inicial_ranking.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inicial_ranking.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			inicial_ranking.add_theme_color_override("font_color", Color("#bce7ff"))
			inicial_ranking.add_theme_font_size_override("font_size", 14)
			linha.add_child(inicial_ranking)
			AvatarCache.solicitar(uid, str(item.get("avatar", "")))
		var nome_label := Label.new()
		nome_label.text = nome.left(17)
		nome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nome_label.add_theme_font_size_override("font_size", 14)
		linha.add_child(nome_label)
		var pontos_label := Label.new()
		pontos_label.text = "%d pts" % int(item.get("pontos", 0))
		pontos_label.custom_minimum_size.x = 62.0
		pontos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pontos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pontos_label.add_theme_color_override("font_color", Color("#8fe3ff"))
		pontos_label.add_theme_font_size_override("font_size", 13)
		linha.add_child(pontos_label)
	_atualizar_lider()


func _ao_avatar_ranking_pronto(_uid: String, _textura: ImageTexture) -> void:
	if _uid == _presente_uid and _presente_restante > 0.0:
		$Hud/PresenteCard/Avatar.texture = _textura
	_renderizar_ranking()
