extends Node

const TAXA := 22050

var _efeitos: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _musica: AudioStreamPlayer
var _indice_player := 0
var _ultimo_contato_msec := 0
var _tema_musica := ""


func _ready() -> void:
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	_criar_players()
	Config.recarregada.connect(_aplicar_config)
	_aplicar_config(Config.dados)


func _exit_tree() -> void:
	if _musica != null:
		_musica.stop()
		_musica.stream = null
	for player in _players:
		player.stop()
		player.stream = null
	_efeitos.clear()


func tocar(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not bool(Config.obter("som", "ativado", true)) or not _efeitos.has(nome):
		return
	if nome == "contato":
		var agora := Time.get_ticks_msec()
		if agora - _ultimo_contato_msec < int(float(Config.obter("som", "intervalo_contato_seg", 0.09)) * 1000.0):
			return
		_ultimo_contato_msec = agora
	if _players.is_empty():
		return
	var player := _players[_indice_player % _players.size()]
	_indice_player += 1
	player.stream = _efeitos[nome]
	player.pitch_scale = randf_range(0.96, 1.04) if nome == "contato" else 1.0
	player.play()


func tocar_presente(efeito: String) -> void:
	match efeito:
		"ESCUDO": tocar("escudo")
		"GIGANTE": tocar("gigante")
		"CACA_E_DERRUBA": tocar("rosa")
		"DERRUBA_TRES": tocar("mini_dino")
		_: tocar("presente")


func atualizar_tema(tema: String) -> void:
	if tema == _tema_musica:
		return
	_tema_musica = tema
	if DisplayServer.get_name() == "headless":
		return
	var musica_arquivo := _carregar_stream(str(Config.obter("som", "musica_fundo", "")))
	if musica_arquivo != null:
		_musica.stream = musica_arquivo
		_musica.play()
		return
	var frequencia := 82.0
	if tema == "ceu_noite":
		frequencia = 65.4
	elif tema == "ceu_tempestade":
		frequencia = 55.0
	_musica.stream = _gerar_ambiencia(frequencia)
	_musica.play()


func _criar_players() -> void:
	var quantidade := maxi(4, int(Config.obter("som", "max_efeitos_simultaneos", 12)))
	for _indice in quantidade:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func _criar_fallbacks() -> void:
	_efeitos = {
		"comentario": _gerar_fanfara([523.25, 783.99], 0.075, 0.5),
		"contato": _gerar_estalo_linha(),
		"corte": _gerar_corte_cartoon(),
		"presente": _gerar_fanfara([659.25, 783.99, 1046.5], 0.12, 0.5),
		"escudo": _gerar_boing(260.0, 880.0, 0.58),
		"gigante": _gerar_trombone_comico(),
		"campeao": _gerar_fanfara([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.62),
		"rosa": _gerar_fanfara([987.77, 1318.5, 1567.98, 2093.0], 0.085, 0.48),
		"mini_dino": _gerar_rugido_comico(),
		"marco": _gerar_fanfara([523.25, 659.25, 783.99, 1046.5], 0.1, 0.58),
		"lider": _gerar_fanfara([659.25, 880.0, 1046.5, 1318.5], 0.09, 0.62),
		"quebrao_aviso": _gerar_fanfara([392.0, 523.25, 783.99], 0.11, 0.65),
		"quebrao": _gerar_boing(980.0, 110.0, 0.9),
		"quebrao_resultado": _gerar_fanfara([523.25, 659.25, 783.99, 1046.5, 1567.98], 0.1, 0.68)
	}
	var arquivos: Dictionary = Config.obter("som", "arquivos", {})
	for nome: String in arquivos.keys():
		var stream := _carregar_stream(str(arquivos[nome]))
		if stream != null:
			_efeitos[nome] = stream


func _carregar_stream(caminho_relativo: String) -> AudioStream:
	if caminho_relativo.strip_edges().is_empty():
		return null
	var caminho := caminho_relativo
	if not caminho.is_absolute_path():
		var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
		caminho = base.path_join(caminho_relativo)
	if not FileAccess.file_exists(caminho):
		return null
	match caminho.get_extension().to_lower():
		"ogg": return AudioStreamOggVorbis.load_from_file(caminho)
		"mp3": return AudioStreamMP3.load_from_file(caminho)
		"wav": return AudioStreamWAV.load_from_file(caminho)
	return null


func _aplicar_config(_dados: Dictionary) -> void:
	_criar_fallbacks()
	var volume_master := float(Config.obter("som", "volume_master", 0.8))
	var volume_efeitos := float(Config.obter("som", "volume_efeitos", 0.9))
	var volume_musica := float(Config.obter("som", "volume_musica", 0.5))
	for player in _players:
		player.volume_db = linear_to_db(maxf(0.001, volume_master * volume_efeitos))
	_musica.volume_db = linear_to_db(maxf(0.001, volume_master * volume_musica))
	_tema_musica = ""
	atualizar_tema(str(Config.obter("cenario", "tema", "ceu_cidade")))


func _gerar_tom(frequencia: float, duracao: float, volume: float, queda_pitch: float) -> AudioStreamWAV:
	var amostras := maxi(1, int(TAXA * duracao))
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	for indice in amostras:
		var t := float(indice) / float(TAXA)
		var progresso := float(indice) / float(amostras)
		var envelope := pow(1.0 - progresso, 2.2)
		var fase := TAU * frequencia * t * (1.0 + progresso * queda_pitch)
		var onda := sin(fase) * 0.72 + sin(fase * 2.03) * 0.2 + sin(fase * 0.51) * 0.08
		var amostra := int(clampf(onda * envelope * volume, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_estalo_linha() -> AudioStreamWAV:
	var duracao := 0.085
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	for indice in amostras:
		var t := float(indice) / TAXA
		var progresso := float(indice) / amostras
		var ruido := sin(float(indice * indice) * 0.071 + indice * 1.73)
		var metal := sin(TAU * (1500.0 - progresso * 620.0) * t)
		var envelope := pow(1.0 - progresso, 5.0)
		var amostra := int(clampf((ruido * 0.34 + metal * 0.66) * envelope * 0.46, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_corte_cartoon() -> AudioStreamWAV:
	var duracao := 0.52
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	for indice in amostras:
		var t := float(indice) / TAXA
		var progresso := float(indice) / amostras
		var assobio := sin(TAU * (1450.0 - progresso * 1050.0) * t) * sin(PI * clampf(progresso / 0.72, 0.0, 1.0))
		var snap_t := absf(t - 0.365)
		var snap := sin(float(indice * indice) * 0.043) * exp(-snap_t * 95.0)
		var pop := sin(TAU * 115.0 * t) * exp(-maxf(0.0, t - 0.36) * 16.0) if t >= 0.36 else 0.0
		var amostra := int(clampf(assobio * 0.34 + snap * 0.72 + pop * 0.42, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_boing(inicio_hz: float, fim_hz: float, duracao: float) -> AudioStreamWAV:
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	var fase := 0.0
	for indice in amostras:
		var progresso := float(indice) / amostras
		var frequencia := lerpf(inicio_hz, fim_hz, pow(progresso, 0.7))
		frequencia *= 1.0 + sin(progresso * TAU * 7.0) * (1.0 - progresso) * 0.08
		fase += TAU * frequencia / TAXA
		var envelope := sin(PI * progresso) * (1.0 - progresso * 0.45)
		var onda := sin(fase) + sin(fase * 2.0) * 0.18
		var amostra := int(clampf(onda * envelope * 0.48, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_trombone_comico() -> AudioStreamWAV:
	var duracao := 0.9
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	var fase := 0.0
	for indice in amostras:
		var progresso := float(indice) / amostras
		var frequencia := lerpf(245.0, 72.0, progresso) * (1.0 + sin(progresso * TAU * 5.0) * 0.035)
		fase += TAU * frequencia / TAXA
		var envelope := sin(PI * progresso) * 0.7
		var onda := sin(fase) * 0.68 + signf(sin(fase)) * 0.22 + sin(fase * 0.5) * 0.1
		var amostra := int(clampf(onda * envelope, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_rugido_comico() -> AudioStreamWAV:
	var duracao := 0.95
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	var fase := 0.0
	for indice in amostras:
		var progresso := float(indice) / amostras
		var frequencia := 92.0 + sin(progresso * TAU * 3.5) * 26.0 + progresso * 55.0
		fase += TAU * frequencia / TAXA
		var envelope := sin(PI * progresso)
		var ruido := sin(float(indice * indice) * 0.0091) * 0.16
		var onda := signf(sin(fase)) * 0.46 + sin(fase * 0.47) * 0.32 + ruido
		var amostra := int(clampf(onda * envelope * 0.72, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_fanfara(notas: Array, duracao_nota: float, volume: float) -> AudioStreamWAV:
	var duracao := notas.size() * duracao_nota + 0.22
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	for indice in amostras:
		var t := float(indice) / TAXA
		var passo := mini(notas.size() - 1, int(t / duracao_nota))
		var local := fmod(t, duracao_nota) / duracao_nota
		var envelope := pow(1.0 - clampf(local, 0.0, 1.0), 1.6)
		var nota := float(notas[passo])
		var onda := sin(TAU * nota * t) * 0.7 + sin(TAU * nota * 2.0 * t) * 0.2 + sin(TAU * nota * 3.0 * t) * 0.1
		var amostra := int(clampf(onda * envelope * volume, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, false, amostras)


func _gerar_ambiencia(frequencia: float) -> AudioStreamWAV:
	var duracao := 8.0
	var amostras := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(amostras * 2)
	var melodia := [261.63, 329.63, 392.0, 329.63, 293.66, 349.23, 440.0, 349.23]
	var transposicao := frequencia / 82.0
	for indice in amostras:
		var t := float(indice) / float(TAXA)
		var passo := int(t / 1.0) % melodia.size()
		var tempo_nota := fmod(t, 1.0)
		var envelope_nota := sin(PI * clampf(tempo_nota / 0.88, 0.0, 1.0))
		var nota: float = melodia[passo] * transposicao
		var onda := sin(TAU * nota * t) * 0.16 * envelope_nota
		onda += sin(TAU * nota * 2.0 * t) * 0.035 * envelope_nota
		var harmonia := sin(TAU * (nota * 1.5) * t) * 0.022 * envelope_nota
		var amostra := int(clampf(onda + harmonia, -1.0, 1.0) * 32767.0)
		dados.encode_s16(indice * 2, amostra)
	return _montar_wav(dados, true, amostras)


func _montar_wav(dados: PackedByteArray, repetir: bool, amostras: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TAXA
	stream.stereo = false
	stream.data = dados
	if repetir:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = amostras
	return stream
