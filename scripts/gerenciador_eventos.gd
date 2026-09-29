extends Node

signal evento_ativado(id: String, definicao: Dictionary)
signal evento_finalizado(id: String, definicao: Dictionary)
signal banner_solicitado(texto: String, duracao: float)
signal cenario_solicitado(tema: String)
signal lista_alterada(texto: String)

var _definicoes: Dictionary = {}
var _ativos: Dictionary = {}
var _modificadores: Dictionary = {}
var _ultimo_inicio_msec := -1000000
var _hud_acumulado := 0.0
var _tempo_sessao := 0.0
var _ultimo_tempo_por_evento: Dictionary = {}
var _recursos: Dictionary = {"diamantes": 0.0}


func _ready() -> void:
	Config.recarregada.connect(_carregar_config)
	_carregar_config(Config.dados)


func _process(delta: float) -> void:
	_hud_acumulado += delta
	_tempo_sessao += delta
	var finalizados: Array[String] = []
	for id: String in _ativos.keys():
		var ativo: Dictionary = _ativos[id]
		ativo.restante = float(ativo.restante) - delta
		_ativos[id] = ativo
		if ativo.restante <= 0.0:
			finalizados.append(id)
	for id in finalizados:
		_finalizar(id)
	if not _ativos.is_empty() and _hud_acumulado >= 0.5:
		_hud_acumulado = 0.0
		_emitir_lista()
	_verificar_gatilhos_de_tempo()


func ativar(id: String, ignorar_cooldown: bool = false) -> bool:
	if not _definicoes.has(id) or _ativos.has(id):
		return false
	var agora := Time.get_ticks_msec()
	var cooldown_msec := int(float(Config.obter("eventos", "cooldown_global_seg", 3.0)) * 1000.0)
	if not ignorar_cooldown and agora - _ultimo_inicio_msec < cooldown_msec:
		return false
	var definicao: Dictionary = _definicoes[id]
	if bool(definicao.get("exclusivo", false)):
		var grupo := str(definicao.get("grupo", ""))
		for ativo_id: String in _ativos.keys().duplicate():
			var outro: Dictionary = _ativos[ativo_id].definicao
			if str(outro.get("grupo", "")) == grupo:
				_finalizar(ativo_id)
	if _ativos.size() >= int(Config.obter("eventos", "max_simultaneos", 2)):
		return false
	_ultimo_inicio_msec = agora
	_ativos[id] = {
		"definicao": definicao,
		"restante": float(definicao.get("duracao_seg", 30.0)),
		"iniciado_msec": agora
	}
	_recalcular_modificadores()
	evento_ativado.emit(id, definicao)
	banner_solicitado.emit(str(definicao.get("banner", definicao.get("nome", id))), 2.5)
	_atualizar_cenario()
	_emitir_lista()
	return true


func modificador(nome: String, padrao: float = 1.0) -> float:
	return float(_modificadores.get(nome, padrao))


func esta_ativo(id: String) -> bool:
	return _ativos.has(id)


func registrar_evento_live(evento: Dictionary) -> void:
	if not bool(Config.obter("eventos", "gatilhos_automaticos", true)):
		return
	if str(evento.get("tipo", "")) != "PRESENTE":
		return
	var detalhes: Dictionary = evento.get("detalhes", {})
	var diamantes := float(detalhes.get("diamantes", 0)) * maxi(1, int(detalhes.get("quantidade", 1)))
	_recursos.diamantes = float(_recursos.get("diamantes", 0.0)) + diamantes
	for id: String in _definicoes.keys():
		var definicao: Dictionary = _definicoes[id]
		for gatilho: Variant in definicao.get("gatilhos", []):
			if not gatilho is Dictionary:
				continue
			var tipo := str(gatilho.get("tipo", ""))
			if tipo == "presente" and diamantes >= float(gatilho.get("min_diamantes", INF)):
				ativar(id)
			elif tipo == "meta":
				var recurso := str(gatilho.get("recurso", ""))
				var valor := float(gatilho.get("valor", INF))
				if float(_recursos.get(recurso, 0.0)) >= valor and ativar(id):
					_recursos[recurso] = float(_recursos.get(recurso, 0.0)) - valor


func ativos() -> Array[String]:
	var resultado: Array[String] = []
	resultado.assign(_ativos.keys())
	return resultado


func encerrar_todos() -> void:
	for id: String in _ativos.keys().duplicate():
		_finalizar(id)
	_atualizar_cenario()
	_emitir_lista()


func _finalizar(id: String) -> void:
	if not _ativos.has(id):
		return
	var definicao: Dictionary = _ativos[id].definicao
	_ativos.erase(id)
	_recalcular_modificadores()
	evento_finalizado.emit(id, definicao)
	_atualizar_cenario()
	_emitir_lista()


func _recalcular_modificadores() -> void:
	_modificadores.clear()
	for ativo: Dictionary in _ativos.values():
		var modificadores: Dictionary = ativo.definicao.get("modificadores", {})
		for chave: String in modificadores.keys():
			if chave.ends_with("_mult"):
				_modificadores[chave] = float(_modificadores.get(chave, 1.0)) * float(modificadores[chave])
			else:
				_modificadores[chave] = modificadores[chave]


func _atualizar_cenario() -> void:
	var tema := "favela_noite" if bool(Config.obter("cenario", "usar_fundo_favela", true)) else str(Config.obter("cenario", "tema", "ceu_cidade"))
	var inicio_mais_recente := -1
	for ativo: Dictionary in _ativos.values():
		var definicao: Dictionary = ativo.definicao
		if definicao.has("cenario") and int(ativo.iniciado_msec) > inicio_mais_recente:
			inicio_mais_recente = int(ativo.iniciado_msec)
			tema = str(definicao.cenario)
	cenario_solicitado.emit(tema)


func _carregar_config(_dados: Dictionary) -> void:
	_definicoes = Config.obter("eventos", "lista", {}).duplicate(true)
	_recalcular_modificadores()


func _verificar_gatilhos_de_tempo() -> void:
	if not bool(Config.obter("eventos", "gatilhos_automaticos", true)):
		return
	for id: String in _definicoes.keys():
		var definicao: Dictionary = _definicoes[id]
		for gatilho: Variant in definicao.get("gatilhos", []):
			if not gatilho is Dictionary or str(gatilho.get("tipo", "")) != "tempo":
				continue
			var intervalo := float(gatilho.get("cada_seg", 0.0))
			var ultimo := float(_ultimo_tempo_por_evento.get(id, 0.0))
			if intervalo > 0.0 and _tempo_sessao - ultimo >= intervalo and ativar(id):
				_ultimo_tempo_por_evento[id] = _tempo_sessao


func _emitir_lista() -> void:
	if _ativos.is_empty():
		lista_alterada.emit("")
		return
	var linhas := PackedStringArray(["EVENTOS ATIVOS"])
	for id: String in _ativos.keys():
		var ativo: Dictionary = _ativos[id]
		var nome := str(ativo.definicao.get("nome", id)).to_upper()
		linhas.append("• %s  %ds" % [nome, ceili(float(ativo.restante))])
	if modificador("pontos_mult") != 1.0:
		linhas.append("PONTOS ×%.1f" % modificador("pontos_mult"))
	if modificador("dano_mult") * modificador("corte_mult") != 1.0:
		linhas.append("CORTE ×%.1f" % (modificador("dano_mult") * modificador("corte_mult")))
	lista_alterada.emit("\n".join(linhas))
