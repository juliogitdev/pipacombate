extends Node

signal recarregada(dados: Dictionary)

const ARQUIVO := "config.json"
const INTERVALO_VERIFICACAO_SEG := 1.0

var dados: Dictionary = {}
var caminho := ""
var _mtime: int = 0
var _acumulado := 0.0
var _hash_conteudo := 0
var _hash_segredos := 0


func _ready() -> void:
	caminho = _resolver_caminho()
	_garantir_config_externa()
	recarregar()


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < INTERVALO_VERIFICACAO_SEG:
		return
	_acumulado = 0.0
	var novo_mtime := FileAccess.get_modified_time(caminho)
	var novo_hash := FileAccess.get_file_as_string(caminho).hash() if FileAccess.file_exists(caminho) else 0
	var caminho_segredos := caminho.get_base_dir().path_join("secrets.json")
	var novo_hash_segredos := FileAccess.get_file_as_string(caminho_segredos).hash() if FileAccess.file_exists(caminho_segredos) else 0
	if novo_mtime > 0 and (novo_mtime != _mtime or novo_hash != _hash_conteudo or novo_hash_segredos != _hash_segredos):
		recarregar()


func obter(secao: String, chave: String, padrao: Variant = null) -> Variant:
	var grupo: Variant = dados.get(secao, {})
	if grupo is Dictionary:
		return grupo.get(chave, padrao)
	return padrao


func recarregar() -> bool:
	if not FileAccess.file_exists(caminho):
		push_error("Configuração não encontrada: %s" % caminho)
		return false
	var texto := FileAccess.get_file_as_string(caminho)
	var resultado: Variant = JSON.parse_string(texto)
	if not resultado is Dictionary:
		push_error("config.json inválido; mantendo a última configuração válida")
		return false
	var alterado := false
	if caminho != ProjectSettings.globalize_path("res://%s" % ARQUIVO) and FileAccess.file_exists("res://%s" % ARQUIVO):
		var padrao: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://%s" % ARQUIVO))
		if padrao is Dictionary:
			alterado = _mesclar_campos_ausentes(resultado, padrao)
	_aplicar_segredos_locais(resultado)
	dados = resultado
	if alterado:
		var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
		if arquivo != null:
			arquivo.store_string(JSON.stringify(dados, "  "))
			arquivo.close()
	_mtime = FileAccess.get_modified_time(caminho)
	_hash_conteudo = FileAccess.get_file_as_string(caminho).hash()
	var caminho_segredos := caminho.get_base_dir().path_join("secrets.json")
	_hash_segredos = FileAccess.get_file_as_string(caminho_segredos).hash() if FileAccess.file_exists(caminho_segredos) else 0
	recarregada.emit(dados)
	return true


func _aplicar_segredos_locais(destino: Dictionary) -> void:
	var caminho_segredos := caminho.get_base_dir().path_join("secrets.json")
	if not FileAccess.file_exists(caminho_segredos):
		return
	var segredos: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_segredos))
	if not segredos is Dictionary:
		push_warning("secrets.json inválido; credenciais locais ignoradas")
		return
	var api: Dictionary = destino.get("api", {})
	for chave in ["api_key", "live_username"]:
		if segredos.has(chave):
			api[chave] = str(segredos[chave])
	destino["api"] = api


func _mesclar_campos_ausentes(destino: Dictionary, padrao: Dictionary) -> bool:
	var alterado := false
	for chave: String in padrao.keys():
		if not destino.has(chave):
			destino[chave] = padrao[chave].duplicate(true) if padrao[chave] is Dictionary or padrao[chave] is Array else padrao[chave]
			alterado = true
		elif destino[chave] is Dictionary and padrao[chave] is Dictionary:
			alterado = _mesclar_campos_ausentes(destino[chave], padrao[chave]) or alterado
	return alterado


func _resolver_caminho() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://%s" % ARQUIVO)
	var pasta_executavel := OS.get_executable_path().get_base_dir()
	var junto_executavel := pasta_executavel.path_join(ARQUIVO)
	if FileAccess.file_exists(junto_executavel):
		return junto_executavel
	var pasta_projeto := pasta_executavel.get_base_dir()
	var junto_projeto := pasta_projeto.path_join(ARQUIVO)
	if FileAccess.file_exists(junto_projeto):
		return junto_projeto
	return junto_executavel


func _garantir_config_externa() -> void:
	if FileAccess.file_exists(caminho) or OS.has_feature("editor"):
		return
	var padrao := "res://%s" % ARQUIVO
	if not FileAccess.file_exists(padrao):
		return
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível criar a configuração externa: %s" % caminho)
		return
	arquivo.store_string(FileAccess.get_file_as_string(padrao))
	arquivo.close()
	print("Configuração externa criada em: %s" % caminho)
