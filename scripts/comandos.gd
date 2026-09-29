extends Node

signal comando_recebido(comando: Dictionary)

var _caminho := ""
var _posicao := 0
var _acumulado := 0.0


func _ready() -> void:
	_caminho = _resolver_caminho()
	if FileAccess.file_exists(_caminho):
		var arquivo := FileAccess.open(_caminho, FileAccess.READ)
		if arquivo != null:
			# Comandos de sessões anteriores não devem ser repetidos.
			_posicao = arquivo.get_length()


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 0.1:
		return
	_acumulado = 0.0
	_ler_novos_comandos()


func _ler_novos_comandos() -> void:
	if not FileAccess.file_exists(_caminho):
		return
	var arquivo := FileAccess.open(_caminho, FileAccess.READ)
	if arquivo == null:
		return
	if arquivo.get_length() < _posicao:
		_posicao = 0
	arquivo.seek(_posicao)
	while arquivo.get_position() < arquivo.get_length():
		var linha := arquivo.get_line().strip_edges()
		_posicao = arquivo.get_position()
		if linha.is_empty():
			continue
		var resultado: Variant = JSON.parse_string(linha)
		if resultado is Dictionary:
			comando_recebido.emit(resultado)
		else:
			push_warning("Comando JSON inválido ignorado: %s" % linha)


func _resolver_caminho() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://comandos.jsonl")
	var pasta_executavel := OS.get_executable_path().get_base_dir()
	var junto_executavel := pasta_executavel.path_join("comandos.jsonl")
	if FileAccess.file_exists(junto_executavel):
		return junto_executavel
	var junto_projeto := pasta_executavel.get_base_dir().path_join("comandos.jsonl")
	if FileAccess.file_exists(junto_projeto):
		return junto_projeto
	return junto_executavel
