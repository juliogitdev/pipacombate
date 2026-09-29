class_name Cenario
extends Node2D

const FAVELA_NOITE := preload("res://assets/cenario/favela_noite.png")

var _nuvens: Array[Dictionary] = []
var _estrelas: Array[Vector2] = []
var _chuva: Array[Vector2] = []
var _ouro: Array[Dictionary] = []
var _chuva_ouro_ativa := false
var _quebrao_intensidade := 0.0
var _quebrao_pulso := 0.0
var _tema := "ceu_cidade"
var _tamanho := Vector2(720, 1280)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260912
	Config.recarregada.connect(_aplicar_config)
	_aplicar_config(Config.dados)


func _process(delta: float) -> void:
	_tamanho = get_viewport_rect().size
	if _quebrao_intensidade > 0.0:
		_quebrao_pulso += delta
	var velocidade_base := float(Config.obter("cenario", "velocidade_nuvens", 12.0))
	for indice in _nuvens.size():
		var nuvem := _nuvens[indice]
		nuvem.posicao.x += velocidade_base * nuvem.profundidade * delta
		if nuvem.posicao.x - nuvem.tamanho.x > _tamanho.x:
			nuvem.posicao.x = -nuvem.tamanho.x
		_nuvens[indice] = nuvem
	if _tema == "ceu_tempestade":
		var velocidade_chuva := float(Config.obter("cenario", "chuva_velocidade", 560.0))
		for indice in _chuva.size():
			_chuva[indice] += Vector2(-velocidade_chuva * 0.18, velocidade_chuva) * delta
			if _chuva[indice].y > _tamanho.y:
				_chuva[indice] = Vector2(_rng.randf_range(0.0, _tamanho.x + 100.0), -20.0)
	if _chuva_ouro_ativa:
		for indice in _ouro.size():
			var moeda := _ouro[indice]
			moeda.posicao.y += float(Config.obter("cenario", "ouro_velocidade", 155.0)) * moeda.velocidade * delta
			moeda.posicao.x += sin(Time.get_ticks_msec() * 0.003 + moeda.fase) * 18.0 * delta
			moeda.rotacao += delta * moeda.velocidade * 3.0
			if moeda.posicao.y > _tamanho.y:
				moeda.posicao = Vector2(_rng.randf_range(0.0, _tamanho.x), _rng.randf_range(-180.0, -20.0))
			_ouro[indice] = moeda
	queue_redraw()


func _draw() -> void:
	if _tema == "favela_noite":
		_desenhar_favela_noite()
		if _chuva_ouro_ativa:
			_desenhar_ouro()
		if _quebrao_intensidade > 0.0:
			_desenhar_quebrao_canonico()
		return
	_desenhar_ceu()
	if bool(Config.obter("cenario", "mostrar_montanhas", true)):
		_desenhar_montanhas()
	if _tema == "ceu_noite":
		_desenhar_estrelas()
		_desenhar_lua()
	elif _tema == "ceu_cidade":
		_desenhar_sol()
		_desenhar_passaros()
	_desenhar_nuvens(0.0, 0.72)
	_desenhar_cidade()
	if bool(Config.obter("cenario", "mostrar_arvores", true)):
		_desenhar_arvores()
	_desenhar_nuvens(0.72, 2.0)
	_desenhar_rua()
	if _tema == "ceu_tempestade":
		_desenhar_chuva()
	if _chuva_ouro_ativa:
		_desenhar_ouro()
	if _quebrao_intensidade > 0.0:
		_desenhar_quebrao_canonico()


func _desenhar_favela_noite() -> void:
	draw_texture_rect(FAVELA_NOITE, Rect2(Vector2.ZERO, _tamanho), false)
	# Uma camada azul integra a ilustração ao restante dos efeitos do jogo.
	draw_rect(Rect2(Vector2.ZERO, _tamanho), Color(0.015, 0.035, 0.12, 0.08), true)


func iniciar_quebrao_canonico(intensidade: float) -> void:
	_quebrao_intensidade = clampf(intensidade, 0.0, 1.0)
	_quebrao_pulso = 0.0
	queue_redraw()


func finalizar_quebrao_canonico() -> void:
	_quebrao_intensidade = 0.0
	queue_redraw()


func intensidade_quebrao() -> float:
	return _quebrao_intensidade


func _desenhar_quebrao_canonico() -> void:
	var pulso := (sin(_quebrao_pulso * 8.0) + 1.0) * 0.5
	var alfa := lerpf(0.12, 0.68, _quebrao_intensidade) + pulso * 0.06 * _quebrao_intensidade
	draw_rect(Rect2(Vector2.ZERO, _tamanho), Color(0.005, 0.006, 0.025, alfa), true)
	var vinheta := Color(0.18, 0.0, 0.1, 0.2 + _quebrao_intensidade * 0.35)
	for faixa in 5:
		var margem := float(faixa * 13)
		draw_rect(Rect2(margem, margem, _tamanho.x - margem * 2.0, _tamanho.y - margem * 2.0), vinheta, false, 4.0)
	if _quebrao_intensidade >= 0.55 and fmod(_quebrao_pulso, 0.72) < 0.13:
		var x := _tamanho.x * (0.22 + fmod(_quebrao_pulso * 1.71, 0.56))
		var raio := 14.0 + 25.0 * _quebrao_intensidade
		draw_line(Vector2(x, 0), Vector2(x - raio, _tamanho.y * 0.2), Color(0.75, 0.92, 1.0, 0.8), 4.0)
		draw_line(Vector2(x - raio, _tamanho.y * 0.2), Vector2(x + raio, _tamanho.y * 0.38), Color(1.0, 0.35, 0.7, 0.85), 3.0)


func _desenhar_ceu() -> void:
	var cores := _cores_do_ceu()
	var faixas := maxi(4, int(Config.obter("cenario", "faixas_gradiente", 28)))
	for indice in faixas:
		var t := float(indice) / float(maxi(1, faixas - 1))
		var y := _tamanho.y * t
		draw_rect(Rect2(0.0, y, _tamanho.x, _tamanho.y / faixas + 2.0), cores[0].lerp(cores[1], t), true)


func _desenhar_sol() -> void:
	var posicao := Vector2(_tamanho.x * 0.78, _tamanho.y * 0.16)
	for raio in range(78, 38, -8):
		var alfa := remap(float(raio), 38.0, 78.0, 0.75, 0.04)
		draw_circle(posicao, float(raio), Color(1.0, 0.88, 0.36, alfa))
	draw_circle(posicao, 38.0, Color("#ffe27a"))


func _desenhar_lua() -> void:
	var posicao := Vector2(_tamanho.x * 0.78, _tamanho.y * 0.16)
	draw_circle(posicao, 43.0, Color(0.72, 0.84, 1.0, 0.14))
	draw_circle(posicao, 31.0, Color("#e9f2ff"))
	draw_circle(posicao + Vector2(12, -8), 28.0, Color("#111b46"))


func _desenhar_estrelas() -> void:
	for indice in _estrelas.size():
		var brilho := 0.5 + sin(Time.get_ticks_msec() * 0.002 + indice) * 0.35
		var raio := 1.2 + float(indice % 3) * 0.65
		draw_circle(_estrelas[indice] * _tamanho, raio, Color(0.88, 0.94, 1.0, brilho))


func _desenhar_nuvens(profundidade_min: float, profundidade_max: float) -> void:
	var opacidade := float(Config.obter("cenario", "opacidade_nuvens", 0.78))
	for nuvem: Dictionary in _nuvens:
		if nuvem.profundidade < profundidade_min or nuvem.profundidade >= profundidade_max:
			continue
		var cor := Color(0.28, 0.32, 0.4, opacidade * 0.7) if _tema == "ceu_tempestade" else Color(1.0, 1.0, 1.0, opacidade / maxf(1.0, nuvem.profundidade))
		var p: Vector2 = nuvem.posicao
		var s: Vector2 = nuvem.tamanho
		draw_circle(p + Vector2(s.x * 0.25, s.y * 0.58), s.y * 0.34, cor)
		draw_circle(p + Vector2(s.x * 0.48, s.y * 0.42), s.y * 0.48, cor)
		draw_circle(p + Vector2(s.x * 0.72, s.y * 0.58), s.y * 0.32, cor)
		draw_rect(Rect2(p.x + s.x * 0.2, p.y + s.y * 0.55, s.x * 0.58, s.y * 0.3), cor, true)


func _desenhar_cidade() -> void:
	var altura := _tamanho.y * float(Config.obter("cenario", "altura_cidade_pct", 20.0)) / 100.0
	var base := _tamanho.y - _tamanho.y * float(Config.obter("cenario", "altura_rua_pct", 9.0)) / 100.0
	var cor := Color("#11182d") if _tema != "ceu_cidade" else Color("#31506d")
	var x := -12.0
	var indice := 0
	while x < _tamanho.x:
		var largura := 48.0 + float((indice * 19) % 46)
		var predio_altura := altura * (0.4 + float((indice * 37) % 55) / 100.0)
		draw_rect(Rect2(x, base - predio_altura, largura, predio_altura), cor, true)
		for coluna in range(1, maxi(2, int(largura / 18.0))):
			for andar in range(1, maxi(2, int(predio_altura / 24.0))):
				if (coluna + andar + indice) % 3 != 0:
					continue
				var janela_cor := Color(1.0, 0.78, 0.26, 0.72) if _tema != "ceu_cidade" else Color(0.68, 0.9, 1.0, 0.45)
				draw_rect(Rect2(x + coluna * 16.0, base - andar * 22.0, 6.0, 9.0), janela_cor, true)
		x += largura + 7.0
		indice += 1


func _desenhar_montanhas() -> void:
	var base := _tamanho.y * 0.78
	var cor_fundo := Color("#657f96") if _tema == "ceu_cidade" else Color("#182348")
	var cor_frente := Color("#486b78") if _tema == "ceu_cidade" else Color("#111a36")
	var fundo := PackedVector2Array([Vector2(0, base)])
	for indice in 9:
		var x := float(indice) * _tamanho.x / 8.0
		var y := base - (95.0 + float((indice * 53) % 125))
		fundo.append(Vector2(x, y))
	fundo.append(Vector2(_tamanho.x, base))
	draw_colored_polygon(fundo, cor_fundo)
	var frente := PackedVector2Array([Vector2(0, base + 45.0)])
	for indice in 7:
		var x := float(indice) * _tamanho.x / 6.0
		var y := base - (35.0 + float((indice * 71) % 90))
		frente.append(Vector2(x, y))
	frente.append(Vector2(_tamanho.x, base + 45.0))
	draw_colored_polygon(frente, cor_frente)


func _desenhar_passaros() -> void:
	var quantidade := int(Config.obter("cenario", "quantidade_passaros", 6))
	var deslocamento := fmod(Time.get_ticks_msec() * 0.018, _tamanho.x + 180.0)
	for indice in quantidade:
		var p := Vector2(fmod(deslocamento + indice * 137.0, _tamanho.x + 100.0) - 50.0, 120.0 + float((indice * 67) % 260))
		var asa := 6.0 + sin(Time.get_ticks_msec() * 0.008 + indice) * 3.0
		draw_arc(p + Vector2(-7, 0), 9.0, PI + 0.25, TAU - 0.25, 8, Color(0.08, 0.16, 0.24, 0.72), 2.2, true)
		draw_arc(p + Vector2(7, 0), 9.0, PI + 0.25, TAU - 0.25, 8, Color(0.08, 0.16, 0.24, 0.72), 2.2 + asa * 0.03, true)


func _desenhar_arvores() -> void:
	var base := _tamanho.y - _tamanho.y * float(Config.obter("cenario", "altura_rua_pct", 9.0)) / 100.0
	for indice in 8:
		var x := 28.0 + indice * (_tamanho.x - 56.0) / 7.0
		var altura := 38.0 + float((indice * 23) % 28)
		draw_rect(Rect2(x - 3.0, base - altura, 6.0, altura), Color("#493728"), true)
		var copa := Color("#2f7d55") if _tema == "ceu_cidade" else Color("#163a38")
		draw_circle(Vector2(x, base - altura), 17.0, copa)
		draw_circle(Vector2(x - 11.0, base - altura + 8.0), 13.0, copa.darkened(0.08))
		draw_circle(Vector2(x + 11.0, base - altura + 8.0), 13.0, copa.lightened(0.05))


func _desenhar_rua() -> void:
	var altura := _tamanho.y * float(Config.obter("cenario", "altura_rua_pct", 9.0)) / 100.0
	var topo := _tamanho.y - altura
	draw_rect(Rect2(0, topo, _tamanho.x, altura), Color("#18202d"), true)
	draw_rect(Rect2(0, topo, _tamanho.x, 8), Color("#46505e"), true)
	var deslocamento := fmod(Time.get_ticks_msec() * 0.04, 90.0)
	for x in range(-90, int(_tamanho.x) + 90, 90):
		draw_rect(Rect2(float(x) + deslocamento, topo + altura * 0.55, 48, 5), Color("#ffd166"), true)


func _desenhar_chuva() -> void:
	for gota in _chuva:
		draw_line(gota, gota + Vector2(-8, 28), Color(0.62, 0.82, 1.0, 0.65), 2.0, true)


func _desenhar_ouro() -> void:
	for moeda: Dictionary in _ouro:
		var p: Vector2 = moeda.posicao
		var raio: float = moeda.raio
		var largura := maxf(2.0, absf(cos(moeda.rotacao)) * raio)
		draw_ellipse(p, largura, raio, Color("#ffb703"))
		draw_circle(p + Vector2(-largura * 0.25, -raio * 0.25), 2.0, Color("#fff4a3"))


func _cores_do_ceu() -> Array[Color]:
	match _tema:
		"ceu_noite":
			return [Color("#080e2b"), Color("#263b70")]
		"ceu_tempestade":
			return [Color("#202735"), Color("#536273")]
		_:
			return [Color("#3aa9e8"), Color("#b9e9ff")]


func _aplicar_config(_dados: Dictionary) -> void:
	_tema = "favela_noite" if bool(Config.obter("cenario", "usar_fundo_favela", true)) else str(Config.obter("cenario", "tema", "ceu_cidade"))
	_gerar_elementos()
	queue_redraw()


func definir_tema_temporario(tema: String) -> void:
	_tema = tema
	Audio.atualizar_tema(tema)
	_gerar_elementos()
	queue_redraw()


func ativar_evento(id: String, _definicao: Dictionary) -> void:
	if id != "chuva_de_ouro":
		return
	_chuva_ouro_ativa = true
	_gerar_ouro()


func finalizar_evento(id: String, _definicao: Dictionary) -> void:
	if id == "chuva_de_ouro":
		_chuva_ouro_ativa = false
		_ouro.clear()


func _gerar_elementos() -> void:
	_tamanho = get_viewport_rect().size
	_nuvens.clear()
	for indice in int(Config.obter("cenario", "quantidade_nuvens", 11)):
		var profundidade := 0.45 + float(indice % 3) * 0.38
		var escala := 0.72 + profundidade * 0.4
		_nuvens.append({
			"posicao": Vector2(_rng.randf_range(-180.0, _tamanho.x), _rng.randf_range(_tamanho.y * 0.1, _tamanho.y * 0.55)),
			"tamanho": Vector2(_rng.randf_range(105.0, 190.0), _rng.randf_range(42.0, 70.0)) * escala,
			"profundidade": profundidade
		})
	_estrelas.clear()
	for _indice in int(Config.obter("cenario", "quantidade_estrelas", 42)):
		_estrelas.append(Vector2(_rng.randf(), _rng.randf_range(0.04, 0.62)))
	_chuva.clear()
	for _indice in int(Config.obter("cenario", "chuva_quantidade", 70)):
		_chuva.append(Vector2(_rng.randf_range(0.0, _tamanho.x + 100.0), _rng.randf_range(0.0, _tamanho.y)))
	if _chuva_ouro_ativa:
		_gerar_ouro()


func _gerar_ouro() -> void:
	_ouro.clear()
	for _indice in int(Config.obter("cenario", "ouro_quantidade", 48)):
		_ouro.append({
			"posicao": Vector2(_rng.randf_range(0.0, _tamanho.x), _rng.randf_range(-_tamanho.y, _tamanho.y)),
			"velocidade": _rng.randf_range(0.72, 1.35),
			"fase": _rng.randf_range(0.0, TAU),
			"rotacao": _rng.randf_range(0.0, TAU),
			"raio": _rng.randf_range(5.0, 10.0)
		})
