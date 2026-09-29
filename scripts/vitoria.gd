class_name TelaVitoria
extends CanvasLayer

signal nova_batalha_solicitada

var _restante := 0.0
var _ativa := false

@onready var _painel: Control = $Painel
@onready var _nome: Label = $Painel/Conteudo/Nome
@onready var _estatisticas: Label = $Painel/Conteudo/Estatisticas
@onready var _detalhes: Label = $Painel/Conteudo/Detalhes
@onready var _contagem: Label = $Painel/Conteudo/Contagem
@onready var _avatar: TextureRect = $Painel/Conteudo/Avatar


func _ready() -> void:
	_painel.hide()


func mostrar(nome: String, unique_id: String, pontos: int, cortes: int, sobrevivencia_seg: float, textura: Texture2D = null) -> void:
	_ativa = true
	_restante = float(Config.obter("vitoria", "proxima_batalha_seg", 5.0))
	_nome.text = nome if not nome.strip_edges().is_empty() else "@%s" % unique_id
	_estatisticas.text = "🏆 %d PONTOS 🏆" % pontos
	_detalhes.text = "%d CORTES  •  CICLO %s" % [cortes, _formatar_tempo(sobrevivencia_seg)]
	_avatar.texture = textura
	_avatar.visible = textura != null
	_painel.show()
	_painel.modulate.a = 0.0
	_painel.scale = Vector2(0.84, 0.84)
	_painel.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_painel, "modulate:a", 1.0, 0.35)
	tween.tween_property(_painel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_soltar_confetes()
	var card: Control = $Painel/Card
	card.pivot_offset = card.size * 0.5
	var pulso := create_tween().set_loops(3)
	pulso.tween_property(card, "scale", Vector2(1.035, 1.035), 0.22).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


func _soltar_confetes() -> void:
	for filho in _painel.get_children():
		if filho.is_in_group("confete_campeao"):
			filho.queue_free()
	var tamanho := get_viewport().get_visible_rect().size
	var cores := [Color("#ffe66d"), Color("#5ffbf1"), Color("#ff70b7"), Color("#a78bfa"), Color("#ffffff")]
	for indice in 38:
		var estrela := Label.new()
		estrela.add_to_group("confete_campeao")
		estrela.text = "★" if indice % 3 else "✦"
		estrela.add_theme_font_size_override("font_size", 14 + indice % 10)
		estrela.add_theme_color_override("font_color", cores[indice % cores.size()])
		estrela.position = Vector2(tamanho.x * 0.5 + randf_range(-80.0, 80.0), tamanho.y * 0.28)
		estrela.z_index = 5
		_painel.add_child(estrela)
		var destino := estrela.position + Vector2(randf_range(-tamanho.x * 0.48, tamanho.x * 0.48), randf_range(260.0, 620.0))
		var duracao := randf_range(1.5, 2.8)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(estrela, "position", destino, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(estrela, "rotation", randf_range(-8.0, 8.0), duracao)
		tween.tween_property(estrela, "modulate:a", 0.0, 0.7).set_delay(randf_range(1.0, 1.9))
		tween.chain().tween_callback(estrela.queue_free)


func _process(delta: float) -> void:
	if not _ativa:
		return
	_restante = maxf(0.0, _restante - delta)
	_contagem.text = "NOVA BATALHA EM %d" % maxi(1, ceili(_restante))
	if _restante <= 0.0:
		_ativa = false
		var tween := create_tween()
		tween.tween_property(_painel, "modulate:a", 0.0, 0.25)
		await tween.finished
		_painel.hide()
		nova_batalha_solicitada.emit()


func _formatar_tempo(segundos: float) -> String:
	var total := maxi(0, int(segundos))
	return "%02d:%02d" % [total / 60, total % 60]
