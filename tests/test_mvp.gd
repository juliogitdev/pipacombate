extends SceneTree

var _falhas := 0


func _init() -> void:
	call_deferred("_executar")


func _verificar(condicao: bool, mensagem: String) -> void:
	if condicao:
		print("[OK] %s" % mensagem)
	else:
		_falhas += 1
		push_error("[FALHA] %s" % mensagem)


func _executar() -> void:
	var config: Node = root.get_node("Config")
	var eventos: Node = root.get_node("Eventos")
	var cena: PackedScene = load("res://Main.tscn")
	var jogo := cena.instantiate()
	root.add_child(jogo)
	for _indice in 4:
		await process_frame

	_verificar(config.dados is Dictionary and not config.dados.is_empty(), "config.json carregado")
	_verificar(jogo.get_node_or_null("Pipas") != null, "arena instanciada")
	var api_cliente: Node = jogo.get_node("ApiClient")
	_verificar(str(api_cliente.call("_base_api")) == "https://tiktok-roblox-live-manager.onrender.com/api", "URL publica da API v4 configurada")
	var evento_bridge: Dictionary = api_cliente.call("_normalizar_evento_bridge", {
		"seq": 17, "type": "gift", "data": {
			"user": {"unique_id": "teste_api", "nickname": "Teste API", "avatar_url": "https://imagem.test/avatar.webp"},
			"gift": {"id": 5655, "name": "Rose", "diamond_count": 1}, "repeat_count": 5
		}
	})
	_verificar(str(evento_bridge.get("tipo", "")) == "PRESENTE" and int(evento_bridge.get("detalhes", {}).get("quantidade", 0)) == 5, "evento gift da API v4 e convertido para o jogo")
	var avatar_teste := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	avatar_teste.fill(Color("#31a8ff"))
	var avatar_webp := avatar_teste.save_webp_to_buffer()
	var avatar_decodificado: Image = root.get_node("AvatarCache").call("_decodificar_imagem", avatar_webp)
	_verificar(not avatar_decodificado.is_empty(), "avatar WebP do TikTok é decodificado")

	jogo.call("_executar_comando", {"cmd": "teste_estresse"})
	for _indice in 3:
		await process_frame
	var quantidade := jogo.get_node("Pipas").get_child_count()
	var maximo := int(config.obter("arena", "max_pipas", 40))
	_verificar(quantidade == maximo, "pool inicial comporta %d pipas" % maximo)
	var titas := 0
	for pipa_teste: Node in jogo.get("_pipas").values():
		if bool(pipa_teste.call("eh_tita")):
			titas += 1
	_verificar(titas > 0 and titas < maximo, "arena mistura pipas comuns e titas de cerol")
	_verificar(str(config.obter("cenario", "tema", "")) == "favela_noite", "cenario noturno de favela esta ativo")
	var ancora_min := INF
	var ancora_max := -INF
	for pipa_linha: Node in jogo.get_node("Pipas").get_children():
		var linha: PackedVector2Array = jogo.call("_obter_linha", pipa_linha)
		ancora_min = minf(ancora_min, linha[0].x)
		ancora_max = maxf(ancora_max, linha[0].x)
	_verificar(ancora_max - ancora_min > 500.0, "bases das linhas ficam espalhadas pela cidade")
	var pipa_marco: Node = jogo.get_node("Pipas").get_child(0)
	var hp_antes := float(pipa_marco.get("hp_max"))
	pipa_marco.call("aplicar_presente", {"giftName": "Rosa", "quantidade": 10, "diamantes": 1})
	_verificar(bool(pipa_marco.call("eh_vip")), "pipa de presente permanece VIP no ciclo")
	_verificar(float(pipa_marco.get("hp_max")) > hp_antes, "presente aumenta o HP máximo")
	_verificar(pipa_marco.get("_marcos_recebidos").size() >= 2, "marcos de HP são desbloqueados")
	_verificar(pipa_marco.get_node("PoderLabel").visible, "poder recebido fica visível na pipa")

	_verificar(eventos.ativar("noite", true), "evento Noite ativa")
	_verificar(eventos.esta_ativo("noite"), "evento permanece registrado")
	eventos.encerrar_todos()
	_verificar(not eventos.esta_ativo("noite"), "eventos podem ser encerrados")
	_verificar(str(jogo.get_node("Cenario").get("_tema")) == "favela_noite", "cenario de favela retorna depois de eventos temporarios")

	jogo.call("_executar_comando", {"cmd": "simular_like", "user": "teste_mvp", "qtd": 20})
	jogo.call("_executar_comando", {"cmd": "escudo_geral"})
	await process_frame
	_verificar(jogo.get("_pipas").size() <= maximo, "limite de pipas respeitado")

	var max_faiscas := int(config.obter("robustez", "max_faiscas", 360))
	for _indice in 5:
		await process_frame
	jogo.call("_somar_pontos_ciclo", "stress_00", 1000.0)
	jogo.call("_somar_pontos_ciclo", "stress_01", 2000.0)
	_verificar(str(jogo.get("_lider_uid")) == "stress_01", "coroa acompanha a lideranca em tempo real")
	var ranking_cinco: Array = []
	for indice in 5:
		ranking_cinco.append({"uniqueId": "rank_%d" % indice, "nickname": "Rank %d" % indice, "pontos": 100 - indice})
	jogo.set("_ranking_dados", ranking_cinco)
	jogo.call("_renderizar_ranking")
	_verificar(jogo.get_node("Hud/RankingLista").get_child_count() == 4, "placar exibe somente Top 3")
	var pontuacao_antes_reconciliacao: Dictionary = jogo.get("_pontuacao_ciclo").duplicate(true)
	jogo.set("_pontuacao_ciclo", {"estavel": 21000.0})
	jogo.call("_atualizar_ranking", [{"uniqueId": "estavel", "nickname": "Estável", "pontos": 20000}])
	_verificar(float(jogo.get("_pontuacao_ciclo").get("estavel", 0)) == 21000.0, "ranking atrasado nao reduz pontuacao")
	jogo.call("_atualizar_ranking", [{"uniqueId": "estavel", "nickname": "Estável", "pontos": 22000}])
	_verificar(float(jogo.get("_pontuacao_ciclo").get("estavel", 0)) == 22000.0, "ranking novo confirma pontuacao maior")
	jogo.set("_pontuacao_ciclo", pontuacao_antes_reconciliacao)
	jogo.call("_atualizar_ranking_local")
	var doador_quebrao: Node = jogo.get("_pipas").get("stress_00")
	jogo.call("_agendar_quebrao", doador_quebrao, 1, "Rosa")
	jogo.call("_agendar_quebrao", doador_quebrao, 4, "Rosa")
	_verificar(jogo.get("_quebroes_pendentes").size() == 1, "presentes cumulativos geram um unico quebrao")
	var pendente_quebrao: Dictionary = jogo.get("_quebroes_pendentes").get("stress_00")
	_verificar(int(pendente_quebrao.get("quantidade", 0)) == 5, "combo do quebrao acumula presentes")
	var intensidade_pequena := float(jogo.call("_calcular_intensidade_quebrao", 1))
	var intensidade_maxima := float(jogo.call("_calcular_intensidade_quebrao", 50))
	_verificar(intensidade_maxima > intensidade_pequena and intensidade_maxima >= 0.99, "rosas multiplicam a intensidade do quebrao")
	pendente_quebrao.pronto_msec = 0
	jogo.get("_quebroes_pendentes")["stress_00"] = pendente_quebrao
	jogo.set("_presente_restante", 0.0)
	jogo.call("_atualizar_quebroes", 0.01)
	_verificar(float(jogo.get_node("Cenario").call("intensidade_quebrao")) > 0.0, "quebrao intenso escurece o ceu")
	var segundo_doador: Node = jogo.get("_pipas").get("stress_01")
	jogo.call("_agendar_quebrao", segundo_doador, 2, "Rosa")
	jogo.call("_agendar_quebrao", doador_quebrao, 3, "Rosa")
	var fila_quebroes: Array = jogo.get("_fila_quebroes")
	_verificar(fila_quebroes.size() == 2 and fila_quebroes[0] == "stress_01" and fila_quebroes[1] == "stress_00", "fila preserva ordem e nao perde presente durante quebrao ativo")
	jogo.set("_tempo_ciclo_restante", 0.0)
	jogo.call("_atualizar_ciclo", 0.01)
	_verificar(not bool(jogo.get("_batalha_encerrada")), "ciclo aguarda a fila de quebrao terminar")
	jogo.set("_tempo_ciclo_restante", 300.0)
	jogo.call("_atualizar_quebroes", 2.0)
	_verificar(bool(doador_quebrao.call("esta_em_quebrao")), "pipa executa o mergulho do quebrao")
	for _passo in 8:
		doador_quebrao.call("simular", 0.4, jogo.get("_limites"))
		jogo.call("_atualizar_quebroes", 0.4)
	_verificar(int(jogo.get("_quebrao_ativo").get("cortes", 0)) >= 2, "quebrao conta as pipas cortadas")
	jogo.call("_limitar_efeitos")
	_verificar(jogo.get("_faiscas").size() <= max_faiscas, "limite de efeitos respeitado")

	var pipas: Array = jogo.get_node("Pipas").get_children()
	var vencedor_teste: Node = pipas[0]
	for indice in range(1, pipas.size()):
		pipas[indice].forcar_queda(vencedor_teste.unique_id)
	await create_timer(1.4).timeout
	_verificar(not bool(jogo.get("_batalha_encerrada")), "última pipa não encerra o ciclo")
	# Isola o teste do ranking real caso o gateway esteja rodando na maquina.
	jogo.set("_pontuacao_ciclo", {"stress_00": 1000.0, "stress_01": 2000.0})
	jogo.call("_forcar_campeao_teste")
	await process_frame
	_verificar("Teste 02" in jogo.get_node("Vitoria/Painel/Conteudo/Nome").text, "campeao e escolhido pela maior pontuacao")
	_verificar("2000 PONTOS" in jogo.get_node("Vitoria/Painel/Conteudo/Estatisticas").text, "tela do campeao destaca a pontuacao")
	_verificar(bool(jogo.get("_batalha_encerrada")), "campeão é anunciado pelo encerramento do ciclo")
	jogo.call("_iniciar_nova_batalha")
	await process_frame
	var antigas_recriadas := false
	for uid: String in jogo.get("_pipas").keys():
		if uid.begins_with("stress_"):
			antigas_recriadas = true
	_verificar(not antigas_recriadas, "novo ciclo não recria pipas antigas")

	jogo.call("_executar_comando", {"cmd": "simular_comentario", "user": "teste_movimento"})
	await process_frame
	var amostra_movimento: Node2D = jogo.get("_pipas").get("teste_movimento")
	var posicao_antes := amostra_movimento.position
	await create_timer(0.35).timeout
	var posicao_depois := amostra_movimento.position
	var limites_simulacao: Rect2 = jogo.get("_limites")
	_verificar(posicao_depois.distance_to(posicao_antes) > 0.1, "simulacao movimenta as pipas")
	_verificar(is_finite(posicao_depois.x) and is_finite(posicao_depois.y) and limites_simulacao.has_point(posicao_depois), "simulacao mantem pipas validas dentro da arena")

	jogo.queue_free()
	await process_frame
	print("MVP: %d falha(s)" % _falhas)
	quit(0 if _falhas == 0 else 1)
