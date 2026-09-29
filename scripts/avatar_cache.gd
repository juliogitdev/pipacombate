extends Node

signal avatar_pronto(unique_id: String, textura: ImageTexture)

const USER_AGENT := "Mozilla/5.0 PipaJogo/1.0"

var _memoria: Dictionary = {}
var _pendentes: Dictionary = {}
var _avisados_vazios: Dictionary = {}


func solicitar(unique_id: String, url: String) -> void:
	if url.strip_edges().is_empty():
		if not _avisados_vazios.has(unique_id):
			_avisados_vazios[unique_id] = true
			print("Avatar vazio recebido para @%s; usando fallback." % unique_id)
		return
	if _memoria.has(unique_id):
		avatar_pronto.emit(unique_id, _memoria[unique_id])
		return
	var caminho := _caminho_cache(unique_id)
	if FileAccess.file_exists(caminho):
		var imagem_cache := Image.load_from_file(caminho)
		if not imagem_cache.is_empty():
			_guardar_e_emitir(unique_id, ImageTexture.create_from_image(imagem_cache))
			return
	if _pendentes.has(unique_id):
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 8.0
	http.request_completed.connect(_ao_baixar.bind(unique_id, caminho, http))
	_pendentes[unique_id] = http
	var erro := http.request(url, PackedStringArray(["User-Agent: %s" % USER_AGENT]))
	if erro != OK:
		_pendentes.erase(unique_id)
		http.queue_free()


func obter(unique_id: String) -> Texture2D:
	return _memoria.get(unique_id) as Texture2D


func _ao_baixar(resultado: int, codigo: int, _headers: PackedStringArray, corpo: PackedByteArray, unique_id: String, caminho: String, http: HTTPRequest) -> void:
	_pendentes.erase(unique_id)
	http.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		print("Falha ao baixar avatar de @%s (HTTP %d)." % [unique_id, codigo])
		return
	var imagem := _decodificar_imagem(corpo)
	if imagem.is_empty():
		print("Formato de avatar não reconhecido para @%s." % unique_id)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://avatares"))
	imagem.save_png(caminho)
	_guardar_e_emitir(unique_id, ImageTexture.create_from_image(imagem))


func _decodificar_imagem(corpo: PackedByteArray) -> Image:
	var imagem := Image.new()
	# O CDN do TikTok entrega as fotos de perfil principalmente em WebP.
	var erro := imagem.load_webp_from_buffer(corpo)
	if erro != OK:
		erro = imagem.load_jpg_from_buffer(corpo)
	if erro != OK:
		erro = imagem.load_png_from_buffer(corpo)
	return imagem if erro == OK else Image.new()


func _guardar_e_emitir(unique_id: String, textura: ImageTexture) -> void:
	_memoria[unique_id] = textura
	avatar_pronto.emit(unique_id, textura)


func _caminho_cache(unique_id: String) -> String:
	return ProjectSettings.globalize_path("user://avatares/%s.png" % abs(hash(unique_id)))
