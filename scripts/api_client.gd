extends Node

signal status_alterado(texto: String)
signal ranking_atualizado(top: Array)
signal reset_ciclo_concluido(sucesso: bool, codigo: int, mensagem: String)

var _cursor := 0
var _fila: Array[Dictionary] = []
var _eventos_em_andamento := false
var _ranking_em_andamento := false
var _reset_em_andamento := false
var _eventos_descartados := 0
var _inicio_requisicao_eventos_msec := 0
var _ultima_resposta_eventos_msec := 0
var _bridge_session := ""
var _requisicao_eventos_tipo := ""
var _config_assinatura := ""

@onready var _http_eventos: HTTPRequest = $HttpEventos
@onready var _http_ranking: HTTPRequest = $HttpRanking
@onready var _http_reset: HTTPRequest = $HttpResetCiclo
@onready var _timer_eventos: Timer = $TimerEventos
@onready var _timer_ranking: Timer = $TimerRanking


func _ready() -> void:
	_http_eventos.request_completed.connect(_ao_receber_eventos)
	_http_ranking.request_completed.connect(_ao_receber_ranking)
	_http_reset.request_completed.connect(_ao_resetar_ciclo)
	_timer_eventos.timeout.connect(_consultar_eventos)
	_timer_ranking.timeout.connect(_consultar_ranking)
	Config.recarregada.connect(_aplicar_config)
	_aplicar_config(Config.dados)
	_ultima_resposta_eventos_msec = Time.get_ticks_msec()
	_consultar_eventos()
	_consultar_ranking()


func _process(_delta: float) -> void:
	var agora := Time.get_ticks_msec()
	var watchdog_seg := float(Config.obter("api", "watchdog_eventos_seg", 8.0))
	if _modo_bridge():
		watchdog_seg = maxf(watchdog_seg, float(Config.obter("api", "bridge_wait_seg", 8.0)) + 7.0)
	var watchdog_msec := int(watchdog_seg * 1000.0)
	if _eventos_em_andamento and agora - _inicio_requisicao_eventos_msec > watchdog_msec:
		_http_eventos.cancel_request()
		_eventos_em_andamento = false
		status_alterado.emit("reconectando eventos...")
		_agendar_backoff(_timer_eventos)
	elif not _eventos_em_andamento and agora - _ultima_resposta_eventos_msec > watchdog_msec:
		_consultar_eventos()


func retirar_eventos(limite: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var quantidade := mini(limite, _fila.size())
	for indice in quantidade:
		saida.append(_fila[indice])
	if quantidade > 0:
		_fila = _fila.slice(quantidade)
	return saida


func tamanho_fila() -> int:
	return _fila.size()


func eventos_descartados() -> int:
	return _eventos_descartados


func reiniciar_ranking(manter_nicks: bool = true) -> bool:
	if _reset_em_andamento:
		return false
	if _modo_bridge():
		_fila.clear()
		call_deferred("_confirmar_reset_bridge")
		return true
	var base := _base_api()
	if base.is_empty():
		reset_ciclo_concluido.emit(false, 0, "URL da API não configurada")
		return false
	var url := "%s/v1/game/ranking/reset" % base
	var cabecalhos := _cabecalhos()
	cabecalhos.append("Content-Type: application/json")
	var corpo := JSON.stringify({"manterNicks": manter_nicks})
	var erro := _http_reset.request(url, cabecalhos, HTTPClient.METHOD_POST, corpo)
	_reset_em_andamento = erro == OK
	if not _reset_em_andamento:
		reset_ciclo_concluido.emit(false, 0, "Não foi possível iniciar a requisição (%d)" % erro)
	return _reset_em_andamento


func _aplicar_config(_dados: Dictionary) -> void:
	_timer_eventos.wait_time = float(Config.obter("api", "events_poll_ms", 700)) / 1000.0
	_timer_ranking.wait_time = float(Config.obter("api", "ranking_poll_ms", 6000)) / 1000.0
	_http_eventos.timeout = maxf(5.0, float(Config.obter("api", "bridge_wait_seg", 8.0)) + 5.0)
	var assinatura := "%s|%s|%s" % [_base_api(), str(Config.obter("api", "live_username", "")), str(Config.obter("api", "modo", "legado"))]
	if not _config_assinatura.is_empty() and assinatura != _config_assinatura:
		if _eventos_em_andamento:
			_http_eventos.cancel_request()
		_eventos_em_andamento = false
		_bridge_session = ""
		_cursor = 0
	_config_assinatura = assinatura


func _cabecalhos() -> PackedStringArray:
	return PackedStringArray(["x-api-key: %s" % str(Config.obter("api", "api_key", ""))])


func _base_api() -> String:
	var base := str(Config.obter("api", "base_url", "")).strip_edges().trim_suffix("/")
	if _modo_bridge():
		base = str(Config.obter("api", "public_base_url", base)).strip_edges().trim_suffix("/")
	if base.is_empty():
		return ""
	return base if base.ends_with("/api") else "%s/api" % base


func _modo_bridge() -> bool:
	return str(Config.obter("api", "modo", "legado")).to_lower() == "bridge"


func _consultar_eventos() -> void:
	if _eventos_em_andamento:
		return
	_timer_eventos.wait_time = float(Config.obter("api", "events_poll_ms", 700)) / 1000.0
	var base := _base_api()
	if base.is_empty():
		status_alterado.emit("configure a URL da API")
		_agendar_backoff(_timer_eventos)
		return
	if _modo_bridge():
		if str(Config.obter("api", "api_key", "")).strip_edges().is_empty():
			status_alterado.emit("configure a API key")
			_agendar_backoff(_timer_eventos)
			return
		if _bridge_session.is_empty():
			_registrar_bridge(base)
			return
		var espera := clampf(float(Config.obter("api", "bridge_wait_seg", 8.0)), 0.0, 15.0)
		var limite := clampi(int(Config.obter("api", "events_limit", 100)), 1, 250)
		var url := "%s/bridge/%s/poll?after=%d&wait=%.1f&limit=%d" % [base, _bridge_session.uri_encode(), _cursor, espera, limite]
		_requisicao_eventos_tipo = "bridge_poll"
		_eventos_em_andamento = _http_eventos.request(url, _cabecalhos(), HTTPClient.METHOD_GET) == OK
		if _eventos_em_andamento:
			_inicio_requisicao_eventos_msec = Time.get_ticks_msec()
		else:
			_agendar_backoff(_timer_eventos)
		return
	var limite := int(Config.obter("api", "events_limit", 100))
	var url := "%s/v1/game/events?cursor=%d&limit=%d" % [base, _cursor, limite]
	_requisicao_eventos_tipo = "legado"
	_eventos_em_andamento = _http_eventos.request(url, _cabecalhos(), HTTPClient.METHOD_GET) == OK
	if _eventos_em_andamento:
		_inicio_requisicao_eventos_msec = Time.get_ticks_msec()
	else:
		_agendar_backoff(_timer_eventos)


func _consultar_ranking() -> void:
	if _ranking_em_andamento:
		return
	if _modo_bridge():
		_timer_ranking.stop()
		return
	_timer_ranking.wait_time = float(Config.obter("api", "ranking_poll_ms", 6000)) / 1000.0
	var base := _base_api()
	if base.is_empty():
		_agendar_backoff(_timer_ranking)
		return
	var url := "%s/v1/game/ranking?limit=3" % base
	_ranking_em_andamento = _http_ranking.request(url, _cabecalhos(), HTTPClient.METHOD_GET) == OK
	if not _ranking_em_andamento:
		_agendar_backoff(_timer_ranking)


func _ao_receber_eventos(resultado: int, codigo: int, _cabecalhos_resposta: PackedStringArray, corpo: PackedByteArray) -> void:
	_eventos_em_andamento = false
	_ultima_resposta_eventos_msec = Time.get_ticks_msec()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		if _modo_bridge() and codigo == 404:
			_bridge_session = ""
		if codigo == 401 or codigo == 403:
			status_alterado.emit("API key inválida")
		else:
			status_alterado.emit("API desconectada (%d)" % codigo)
		_agendar_backoff(_timer_eventos)
		return
	var resposta: Variant = JSON.parse_string(corpo.get_string_from_utf8())
	if not resposta is Dictionary:
		_agendar_backoff(_timer_eventos)
		return
	if _requisicao_eventos_tipo == "bridge_register":
		_processar_registro_bridge(resposta)
		return
	var eventos: Variant = resposta.get("events", resposta.get("eventos", []))
	if eventos is Array and not eventos.is_empty():
		var fila_maxima := int(Config.obter("arena", "fila_maxima", 1000))
		for evento: Variant in eventos:
			if not evento is Dictionary:
				continue
			var convertido: Dictionary = _normalizar_evento_bridge(evento) if _modo_bridge() else evento
			if not convertido.is_empty() and _fila.size() < fila_maxima:
				_fila.append(convertido)
			elif not convertido.is_empty():
				_eventos_descartados += 1
			_cursor = maxi(_cursor, int(evento.get("seq", evento.get("id", _cursor))))
	_cursor = maxi(_cursor, int(resposta.get("cursor", resposta.get("next_cursor", resposta.get("last_seq", _cursor)))))
	var ao_vivo := bool(resposta.get("live", true))
	var status_live := str(resposta.get("statusLive", resposta.get("connection_state", "ONLINE"))).to_upper()
	status_alterado.emit("ONLINE" if ao_vivo and status_live in ["ONLINE", "CONNECTED", "LIVE"] else "API OK • LIVE OFFLINE")
	_timer_eventos.start(float(Config.obter("api", "events_poll_ms", 700)) / 1000.0)


func _ao_receber_ranking(resultado: int, codigo: int, _cabecalhos_resposta: PackedStringArray, corpo: PackedByteArray) -> void:
	_ranking_em_andamento = false
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_agendar_backoff(_timer_ranking)
		return
	var resposta: Variant = JSON.parse_string(corpo.get_string_from_utf8())
	if resposta is Dictionary:
		var top: Variant = resposta.get("top", [])
		if top is Array:
			ranking_atualizado.emit(top)


func _ao_resetar_ciclo(resultado: int, codigo: int, _cabecalhos_resposta: PackedStringArray, corpo: PackedByteArray) -> void:
	_reset_em_andamento = false
	var sucesso := resultado == HTTPRequest.RESULT_SUCCESS and codigo == 200
	var mensagem := corpo.get_string_from_utf8().strip_edges()
	if mensagem.is_empty():
		mensagem = "Reset confirmado" if sucesso else "Falha de comunicação com o Gateway"
	reset_ciclo_concluido.emit(sucesso, codigo, mensagem)
	if sucesso:
		_fila.clear()
		_consultar_ranking()


func _agendar_backoff(timer: Timer) -> void:
	timer.stop()
	timer.start(float(Config.obter("api", "backoff_ms", 2000)) / 1000.0)


func _registrar_bridge(base: String) -> void:
	var usuario := str(Config.obter("api", "live_username", "")).strip_edges().trim_prefix("@")
	if usuario.is_empty():
		status_alterado.emit("configure o usuário TikTok")
		_agendar_backoff(_timer_eventos)
		return
	var cabecalhos := _cabecalhos()
	cabecalhos.append("Content-Type: application/json")
	var corpo := JSON.stringify({
		"username": usuario,
		"profile": str(Config.obter("api", "bridge_profile", "raw")),
		"consumer_id": str(Config.obter("api", "consumer_id", "pipajogo-godot"))
	})
	_requisicao_eventos_tipo = "bridge_register"
	_eventos_em_andamento = _http_eventos.request("%s/bridge/register" % base, cabecalhos, HTTPClient.METHOD_POST, corpo) == OK
	if _eventos_em_andamento:
		_inicio_requisicao_eventos_msec = Time.get_ticks_msec()
		status_alterado.emit("registrando sessão...")
	else:
		_agendar_backoff(_timer_eventos)


func _processar_registro_bridge(resposta: Dictionary) -> void:
	var sessao: Variant = resposta.get("session", {})
	var sessao_interna := ""
	if sessao is Dictionary:
		sessao_interna = str(sessao.get("session_id", sessao.get("sid", "")))
	_bridge_session = str(resposta.get("session_id", resposta.get("sid", sessao_interna)))
	_cursor = int(resposta.get("cursor", resposta.get("latest_seq", resposta.get("last_seq", 0))))
	if _bridge_session.is_empty():
		status_alterado.emit("resposta de registro inválida")
		_agendar_backoff(_timer_eventos)
		return
	status_alterado.emit("API OK • sessão registrada")
	_timer_eventos.start(0.05)


func _normalizar_evento_bridge(evento: Dictionary) -> Dictionary:
	var tipo_raw := str(evento.get("type", evento.get("tipo", ""))).to_lower()
	var mapa_tipos := {
		"gift": "PRESENTE", "comment": "COMENTARIO", "like": "LIKE",
		"follow": "SEGUIDOR", "share": "COMPARTILHAMENTO"
	}
	if not mapa_tipos.has(tipo_raw):
		return {}
	var dados_var: Variant = evento.get("data", {})
	var dados: Dictionary = dados_var if dados_var is Dictionary else {}
	var usuario_var: Variant = dados.get("user", evento.get("user", {}))
	var usuario_raw: Dictionary = usuario_var if usuario_var is Dictionary else {}
	var uid := str(usuario_raw.get("unique_id", usuario_raw.get("uniqueId", usuario_raw.get("username", "")))).strip_edges()
	if uid.is_empty():
		return {}
	var apelido := str(usuario_raw.get("nickname", usuario_raw.get("display_name", uid)))
	var avatar := str(usuario_raw.get("avatar_url", usuario_raw.get("avatar", usuario_raw.get("profile_picture_url", ""))))
	var quantidade := maxi(1, int(dados.get("count", dados.get("repeat_count", evento.get("count", 1)))))
	var detalhes := {"quantidade": quantidade}
	var pontos := float(evento.get("points", evento.get("pontos", 0.0)))
	if tipo_raw == "gift":
		var gift_var: Variant = dados.get("gift", {})
		var gift: Dictionary = gift_var if gift_var is Dictionary else {}
		var nome_gift := str(gift.get("name", dados.get("gift_name", "Presente")))
		var diamantes := maxi(1, int(gift.get("diamond_count", dados.get("gift_coins", 1))))
		detalhes.merge({"giftName": nome_gift, "giftId": str(gift.get("id", nome_gift)), "diamantes": diamantes}, true)
		if pontos <= 0.0:
			pontos = float(diamantes * quantidade)
	elif tipo_raw == "comment":
		detalhes.mensagem = str(dados.get("comment", ""))
		if pontos <= 0.0:
			pontos = 5.0
	elif tipo_raw == "like":
		if pontos <= 0.0:
			pontos = float(quantidade)
	elif pontos <= 0.0:
		pontos = 20.0
	return {
		"tipo": mapa_tipos[tipo_raw], "acao": tipo_raw.to_upper(), "pontos": pontos,
		"usuario": {"uniqueId": uid, "apelido": apelido, "avatar": avatar},
		"detalhes": detalhes, "seq": int(evento.get("seq", evento.get("id", 0)))
	}


func _confirmar_reset_bridge() -> void:
	reset_ciclo_concluido.emit(true, 200, "Novo ciclo local sincronizado; cursor da sessão preservado")
