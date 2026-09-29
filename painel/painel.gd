extends Control

const COR_FUNDO := Color("#101827")
const COR_CARD := Color("#182338")
const COR_DESTAQUE := Color("#ffb703")

var _config: Dictionary = {}
var _campos: Dictionary = {}
var _caminho_config := ""
var _caminho_comandos := ""
var _caminho_segredos := ""
var _tabs: TabContainer
var _status: Label
var _aplicar_ao_vivo: CheckButton
var _usuario_teste: LineEdit
var _presente_teste: OptionButton
var _quantidade_teste: SpinBox


func _ready() -> void:
	_caminho_config = _arquivo_compartilhado("config.json")
	_caminho_comandos = _arquivo_compartilhado("comandos.jsonl")
	_caminho_segredos = _arquivo_compartilhado("secrets.json")
	_montar_interface()
	_carregar_config()


func _montar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	raiz.add_theme_constant_override("separation", 12)
	add_child(raiz)

	var titulo := Label.new()
	titulo.text = "PIPA PAINEL  •  CONTROLE DA LIVE"
	titulo.add_theme_font_size_override("font_size", 25)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	raiz.add_child(titulo)

	var aviso := Label.new()
	aviso.text = "Configurações marcadas como reinício: janela e URL da API. As demais aplicam ao vivo."
	aviso.add_theme_color_override("font_color", Color("#a9c5e8"))
	raiz.add_child(aviso)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(_tabs)

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 12)
	raiz.add_child(rodape)

	var salvar := Button.new()
	salvar.text = "SALVAR CONFIGURAÇÃO"
	salvar.pressed.connect(_salvar_config)
	rodape.add_child(salvar)

	var recarregar := Button.new()
	recarregar.text = "Recarregar do disco"
	recarregar.pressed.connect(_carregar_config)
	rodape.add_child(recarregar)

	_aplicar_ao_vivo = CheckButton.new()
	_aplicar_ao_vivo.text = "Aplicar ao vivo ao editar"
	rodape.add_child(_aplicar_ao_vivo)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rodape.add_child(_status)


func _carregar_config() -> void:
	if not FileAccess.file_exists(_caminho_config):
		_mostrar_status("config.json não encontrado", true)
		return
	var resultado: Variant = JSON.parse_string(FileAccess.get_file_as_string(_caminho_config))
	if not resultado is Dictionary:
		_mostrar_status("JSON inválido; arquivo não alterado", true)
		return
	if FileAccess.file_exists(_caminho_segredos):
		var segredos: Variant = JSON.parse_string(FileAccess.get_file_as_string(_caminho_segredos))
		if segredos is Dictionary and resultado.get("api", {}) is Dictionary:
			for chave in ["api_key", "live_username"]:
				if segredos.has(chave):
					resultado["api"][chave] = str(segredos[chave])
	_config = resultado
	_reconstruir_tabs()
	_mostrar_status("Configuração carregada", false)


func _reconstruir_tabs() -> void:
	_campos.clear()
	for filho in _tabs.get_children():
		_tabs.remove_child(filho)
		filho.queue_free()
	# Controles da transmissão precisam permanecer visíveis mesmo com muitas seções.
	_adicionar_tab_comandos()
	for secao: String in _config.keys():
		var scroll := ScrollContainer.new()
		scroll.name = secao.capitalize()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		var grade := GridContainer.new()
		grade.columns = 2
		grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grade.add_theme_constant_override("h_separation", 20)
		grade.add_theme_constant_override("v_separation", 8)
		scroll.add_child(grade)
		_adicionar_valores(grade, [secao], _config[secao])
	_tabs.current_tab = 0


func _adicionar_valores(grade: GridContainer, caminho: Array, valor: Variant) -> void:
	if valor is Dictionary:
		for chave: String in valor.keys():
			_adicionar_valores(grade, caminho + [chave], valor[chave])
		return
	var rotulo := Label.new()
	rotulo.text = caminho[0] if caminho.size() == 1 else ".".join(caminho.slice(1))
	rotulo.tooltip_text = ".".join(caminho)
	if caminho[0] in ["janela", "api"]:
		rotulo.text += "  [REINÍCIO]"
	grade.add_child(rotulo)
	var editor := LineEdit.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.text = _valor_para_texto(valor)
	editor.text_submitted.connect(func(_texto: String) -> void: _ao_editar_campo())
	if caminho.size() >= 3 and caminho[0] == "som" and caminho[1] == "arquivos":
		var linha_audio := HBoxContainer.new()
		linha_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha_audio.add_child(editor)
		var procurar := Button.new()
		procurar.text = "Procurar..."
		procurar.pressed.connect(func() -> void: _selecionar_audio(editor))
		linha_audio.add_child(procurar)
		grade.add_child(linha_audio)
	else:
		grade.add_child(editor)
	_campos["/".join(caminho)] = {"editor": editor, "original": valor, "caminho": caminho}


func _selecionar_audio(editor: LineEdit) -> void:
	var seletor := FileDialog.new()
	seletor.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	seletor.access = FileDialog.ACCESS_FILESYSTEM
	seletor.filters = PackedStringArray(["*.ogg ; Áudio OGG", "*.mp3 ; Áudio MP3", "*.wav ; Áudio WAV"])
	seletor.use_native_dialog = true
	seletor.file_selected.connect(func(caminho: String) -> void:
		editor.text = caminho
		_salvar_config()
		seletor.queue_free())
	seletor.canceled.connect(seletor.queue_free)
	add_child(seletor)
	seletor.popup_centered_ratio(0.75)


func _adicionar_tab_comandos() -> void:
	var pagina := VBoxContainer.new()
	pagina.name = "Ao vivo"
	pagina.add_theme_constant_override("separation", 12)
	_tabs.add_child(pagina)

	var linha_teste := HBoxContainer.new()
	pagina.add_child(linha_teste)
	_usuario_teste = LineEdit.new()
	_usuario_teste.placeholder_text = "Usuário de teste"
	_usuario_teste.text = "teste_painel"
	_usuario_teste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_teste.add_child(_usuario_teste)
	_presente_teste = OptionButton.new()
	var presentes: Dictionary = _config.get("presentes", {}).get("por_gift", {})
	for nome: String in presentes.keys():
		_presente_teste.add_item(nome)
	linha_teste.add_child(_presente_teste)
	_quantidade_teste = SpinBox.new()
	_quantidade_teste.min_value = 1
	_quantidade_teste.max_value = 100
	_quantidade_teste.value = 1
	linha_teste.add_child(_quantidade_teste)

	var botoes := GridContainer.new()
	botoes.columns = 3
	pagina.add_child(botoes)
	_adicionar_botao_comando(botoes, "Simular comentário", func() -> void:
		_escrever_comando({"cmd": "simular_comentario", "user": _usuario_teste.text}))
	_adicionar_botao_comando(botoes, "Simular presente", func() -> void:
		_escrever_comando({"cmd": "simular_presente", "gift": _presente_teste.get_item_text(_presente_teste.selected), "qtd": int(_quantidade_teste.value), "user": _usuario_teste.text}))
	_adicionar_botao_comando(botoes, "Simular likes", func() -> void:
		_escrever_comando({"cmd": "simular_like", "qtd": int(_quantidade_teste.value), "user": _usuario_teste.text}))
	_adicionar_botao_comando(botoes, "Simular seguidor", func() -> void:
		_escrever_comando({"cmd": "simular_seguidor", "user": _usuario_teste.text}))
	_adicionar_botao_comando(botoes, "Simular compartilhamento", func() -> void:
		_escrever_comando({"cmd": "simular_compartilhamento", "user": _usuario_teste.text}))
	_adicionar_botao_comando(botoes, "Nova batalha", func() -> void:
		_escrever_comando({"cmd": "nova_batalha"}))
	_adicionar_botao_comando(botoes, "Zerar partida", func() -> void:
		_escrever_comando({"cmd": "zerar_partida"}))
	_adicionar_botao_comando(botoes, "Escudo geral", func() -> void:
		_escrever_comando({"cmd": "escudo_geral"}))
	_adicionar_botao_comando(botoes, "Recarregar jogo", func() -> void:
		_escrever_comando({"cmd": "recarregar"}))
	_adicionar_botao_comando(botoes, "Encerrar eventos / Dia", func() -> void:
		_escrever_comando({"cmd": "encerrar_eventos"}))
	_adicionar_botao_comando(botoes, "Teste com 40 pipas", func() -> void:
		_escrever_comando({"cmd": "teste_estresse"}))
	_adicionar_botao_comando(botoes, "Mostrar campeão", func() -> void:
		_escrever_comando({"cmd": "teste_vitoria"}))
	_adicionar_botao_comando(botoes, "Ouvir som de comentario", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "comentario"}))
	_adicionar_botao_comando(botoes, "Ouvir troca de líder", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "lider"}))
	_adicionar_botao_comando(botoes, "Ouvir som da rosa", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "rosa"}))
	_adicionar_botao_comando(botoes, "Ouvir aviso de quebrão", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "quebrao_aviso"}))
	_adicionar_botao_comando(botoes, "Ouvir mergulho do quebrão", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "quebrao"}))
	_adicionar_botao_comando(botoes, "Ouvir resultado do quebrão", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "quebrao_resultado"}))
	_adicionar_botao_comando(botoes, "Ouvir som de corte", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "corte"}))
	_adicionar_botao_comando(botoes, "Ouvir som de presente", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "presente"}))
	_adicionar_botao_comando(botoes, "Ouvir som de campeão", func() -> void:
		_escrever_comando({"cmd": "testar_som", "som": "campeao"}))

	var separador := HSeparator.new()
	pagina.add_child(separador)
	var titulo_eventos := Label.new()
	titulo_eventos.text = "EVENTOS TEMÁTICOS"
	titulo_eventos.add_theme_font_size_override("font_size", 20)
	titulo_eventos.add_theme_color_override("font_color", COR_DESTAQUE)
	pagina.add_child(titulo_eventos)
	var botoes_eventos := GridContainer.new()
	botoes_eventos.columns = 3
	pagina.add_child(botoes_eventos)
	var eventos: Dictionary = _config.get("eventos", {}).get("lista", {})
	for id: String in eventos.keys():
		var definicao: Dictionary = eventos[id]
		var evento_id := id
		_adicionar_botao_comando(botoes_eventos, str(definicao.get("nome", id)), func() -> void:
			_escrever_comando({"cmd": "evento", "id": evento_id}))


func _adicionar_botao_comando(pai: Control, texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(220, 52)
	botao.pressed.connect(acao)
	pai.add_child(botao)


func _ao_editar_campo() -> void:
	if _aplicar_ao_vivo.button_pressed:
		_salvar_config()


func _salvar_config() -> void:
	var nova_config := _config.duplicate(true)
	for entrada: Dictionary in _campos.values():
		var convertido: Variant = _converter_texto(entrada.editor.text, entrada.original)
		if convertido == null and entrada.original != null:
			_mostrar_status("Valor inválido em %s" % ".".join(entrada.caminho), true)
			return
		_definir_caminho(nova_config, entrada.caminho, convertido)
	var config_disco: Dictionary = nova_config.duplicate(true)
	var segredos := {
		"api_key": str(nova_config.get("api", {}).get("api_key", "")),
		"live_username": str(nova_config.get("api", {}).get("live_username", ""))
	}
	if config_disco.get("api", {}) is Dictionary:
		config_disco["api"]["api_key"] = ""
		config_disco["api"]["live_username"] = ""
	var arquivo_segredos := FileAccess.open(_caminho_segredos, FileAccess.WRITE)
	if arquivo_segredos == null:
		_mostrar_status("Não foi possível gravar secrets.json", true)
		return
	arquivo_segredos.store_string(JSON.stringify(segredos, "  "))
	arquivo_segredos.close()
	var arquivo := FileAccess.open(_caminho_config, FileAccess.WRITE)
	if arquivo == null:
		_mostrar_status("Não foi possível gravar config.json", true)
		return
	arquivo.store_string(JSON.stringify(config_disco, "  "))
	arquivo.close()
	_config = nova_config
	_mostrar_status("Salvo — o jogo recarrega em até 1 segundo", false)


func _converter_texto(texto: String, original: Variant) -> Variant:
	match typeof(original):
		TYPE_BOOL:
			if texto.to_lower() in ["true", "1", "sim"]:
				return true
			if texto.to_lower() in ["false", "0", "não", "nao"]:
				return false
			return null
		TYPE_INT:
			return int(texto) if texto.is_valid_int() else null
		TYPE_FLOAT:
			return float(texto) if texto.is_valid_float() else null
		TYPE_ARRAY:
			var resultado: Variant = JSON.parse_string(texto)
			return resultado if resultado is Array else null
		_:
			return texto


func _definir_caminho(destino: Dictionary, caminho: Array, valor: Variant) -> void:
	var atual := destino
	for indice in range(caminho.size() - 1):
		atual = atual[caminho[indice]]
	atual[caminho[-1]] = valor


func _valor_para_texto(valor: Variant) -> String:
	if valor is Array or valor is Dictionary:
		return JSON.stringify(valor)
	if valor is bool:
		return "true" if valor else "false"
	return str(valor)


func _escrever_comando(comando: Dictionary) -> void:
	var arquivo := FileAccess.open(_caminho_comandos, FileAccess.READ_WRITE)
	if arquivo == null:
		arquivo = FileAccess.open(_caminho_comandos, FileAccess.WRITE)
	if arquivo == null:
		_mostrar_status("Não foi possível gravar comandos.jsonl", true)
		return
	arquivo.seek_end()
	arquivo.store_line(JSON.stringify(comando))
	arquivo.close()
	_mostrar_status("Comando enviado: %s" % comando.get("cmd", ""), false)


func _mostrar_status(texto: String, erro: bool) -> void:
	_status.text = texto
	_status.add_theme_color_override("font_color", Color("#ff667a") if erro else Color("#69e6a6"))


func _arquivo_compartilhado(nome: String) -> String:
	if OS.has_feature("editor"):
		var pasta_painel := ProjectSettings.globalize_path("res://project.godot").get_base_dir()
		return pasta_painel.get_base_dir().path_join(nome)
	var pasta_executavel := OS.get_executable_path().get_base_dir()
	var junto_executavel := pasta_executavel.path_join(nome)
	if FileAccess.file_exists(junto_executavel):
		return junto_executavel
	var junto_projeto := pasta_executavel.get_base_dir().path_join(nome)
	if FileAccess.file_exists(junto_projeto):
		return junto_projeto
	return junto_executavel
