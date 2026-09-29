# Live Gateway — documentação da API para integração de jogos

> Documento de contexto para desenvolvedores e assistentes de IA criarem novos jogos integrados ao Live Gateway do TikTok.

## 1. Visão geral

O Live Gateway conecta uma transmissão do TikTok, normaliza as interações dos espectadores e expõe uma API HTTP simples para qualquer engine de jogo.

Fluxo principal:

```text
TikTok Live → Live Gateway → fila de eventos HTTP → jogo
                         └→ ranking consolidado → jogo
```

O gateway é responsável por:

- conectar-se à live;
- transformar eventos do TikTok em um formato estável;
- calcular os pontos conforme as regras da instância;
- armazenar temporariamente os eventos em memória;
- manter o ranking do ciclo atual;
- disponibilizar avatar, apelido e identificador do espectador;
- zerar o ranking quando o jogo terminar um ciclo.

O jogo é responsável por:

- consultar eventos continuamente usando cursor;
- transformar eventos em mecânicas visuais;
- evitar processar o mesmo cursor duas vezes;
- consultar e exibir o ranking;
- solicitar o reset quando uma rodada terminar;
- guardar sua própria fila de efeitos longos, se necessário.

## 2. Endereços

Servidor local padrão:

```text
http://localhost:3000
```

Base completa da API:

```text
http://localhost:3000/api
```

Se a configuração do jogo receber apenas `http://localhost:3000`, o cliente deve acrescentar `/api`. Se já receber um endereço terminado em `/api`, não deve duplicar o segmento.

Health check público:

```http
GET http://localhost:3000/health
```

Resposta:

```json
{
  "status": "ONLINE",
  "timestamp": 1789300000000
}
```

Esse status confirma que o backend está respondendo. Ele não significa necessariamente que a transmissão do TikTok está online.

## 3. Conceitos essenciais

### Instância

Cada jogo/live utiliza uma instância cadastrada no dashboard. A instância contém:

- nome;
- usuário do TikTok;
- API Key exclusiva;
- regras de pontuação;
- configuração de presentes.

### API Key do jogo

As rotas `/api/v1/game/*` usam a API Key da instância, e não o JWT administrativo.

Cabeçalho recomendado:

```http
x-api-key: API_KEY_DA_INSTANCIA
```

Também é aceito:

```http
Authorization: Bearer API_KEY_DA_INSTANCIA
```

Nunca coloque o JWT do dashboard no campo destinado à API Key do jogo.

### Cursor de eventos

Cada evento recebe um número `cursor` crescente. O jogo informa o último cursor processado e recebe somente os eventos posteriores.

```text
consulta cursor=0 → recebe cursores 1, 2 e 3
próxima consulta cursor=3 → recebe 4, 5...
```

O buffer atual guarda até 200 eventos por instância em memória. Portanto, o jogo deve consultar regularmente. O cursor é mantido enquanto o processo do gateway estiver rodando; ao reiniciar o gateway, trate o fluxo como uma nova sessão.

## 4. Autenticação e erros

Todas as rotas do jogo abaixo exigem `x-api-key`.

Erros comuns:

| HTTP | Significado |
|---:|---|
| 200 | Requisição concluída |
| 400 | Corpo ou parâmetros inválidos |
| 401 | API Key não enviada |
| 403 | API Key inválida ou instância inexistente |
| 500 | Erro interno, banco, TikTok ou configuração |

Exemplo de erro:

```json
{
  "erro": "API Key do jogo não fornecida."
}
```

## 5. Endpoint de eventos

```http
GET /api/v1/game/events?cursor=0&limit=100
x-api-key: API_KEY_DA_INSTANCIA
```

Parâmetros:

| Parâmetro | Tipo | Padrão | Limite | Descrição |
|---|---|---:|---:|---|
| `cursor` | inteiro | `0` | — | Último cursor já recebido |
| `limit` | inteiro | `30` | `100` | Máximo de eventos na resposta |

Resposta:

```json
{
  "statusLive": "ONLINE",
  "eventos": [],
  "cursor": 42,
  "pendentes": 0,
  "totalEmBuffer": 42
}
```

Campos:

- `statusLive`: `ONLINE` ou `OFFLINE`; representa a conexão com a live.
- `eventos`: eventos posteriores ao cursor solicitado.
- `cursor`: cursor do último evento devolvido. Salve este valor mesmo quando processar em lotes.
- `pendentes`: quantidade que ainda não coube no limite desta resposta.
- `totalEmBuffer`: quantidade atualmente guardada no buffer.

### Estrutura comum de um evento

```json
{
  "tipo": "COMENTARIO",
  "acao": "CHAT",
  "pontos": 5,
  "usuario": {
    "uniqueId": "usuario_tiktok",
    "apelido": "Nome exibido",
    "avatar": "https://endereco-da-imagem.webp"
  },
  "detalhes": {},
  "cursor": 42,
  "recebidoEm": 1789300000000
}
```

Regras de identificação:

- use `usuario.uniqueId` como chave permanente do jogador;
- use `usuario.apelido` somente para exibição;
- o apelido pode mudar;
- `avatar` pode estar vazio ou expirar; implemente imagem reserva e cache;
- aceite WebP, JPEG e PNG ao baixar avatares.

## 6. Tipos de eventos

### Comentário

```json
{
  "tipo": "COMENTARIO",
  "acao": "CHAT",
  "pontos": 5,
  "usuario": {
    "uniqueId": "maria123",
    "apelido": "Maria",
    "avatar": "https://..."
  },
  "detalhes": {
    "mensagem": "pipa"
  },
  "cursor": 10,
  "recebidoEm": 1789300000000
}
```

Uso sugerido: criar/renovar o participante, interpretar comandos de chat e aplicar `pontos`.

O comando `!nick NOVO_NOME` vincula um nome de jogo ao usuário no ranking.

### Curtidas

```json
{
  "tipo": "LIKE",
  "acao": "BOOST",
  "pontos": 12,
  "usuario": {
    "uniqueId": "joao",
    "apelido": "João",
    "avatar": "https://..."
  },
  "detalhes": {
    "quantidade": 12
  },
  "cursor": 11,
  "recebidoEm": 1789300000100
}
```

`detalhes.quantidade` informa quantas curtidas vieram no lote. `pontos` já contém a pontuação total calculada para esse evento.

### Seguidor

```json
{
  "tipo": "SEGUIDOR",
  "acao": "FOLLOW",
  "pontos": 50,
  "usuario": {
    "uniqueId": "ana",
    "apelido": "Ana",
    "avatar": "https://..."
  },
  "detalhes": {},
  "cursor": 12,
  "recebidoEm": 1789300000200
}
```

### Compartilhamento

```json
{
  "tipo": "COMPARTILHAMENTO",
  "acao": "SHARE",
  "pontos": 20,
  "usuario": {
    "uniqueId": "carlos",
    "apelido": "Carlos",
    "avatar": "https://..."
  },
  "detalhes": {},
  "cursor": 13,
  "recebidoEm": 1789300000300
}
```

### Presente

```json
{
  "tipo": "PRESENTE",
  "acao": "PRESENTE_PADRAO",
  "pontos": 600,
  "usuario": {
    "uniqueId": "doador",
    "apelido": "Doador",
    "avatar": "https://..."
  },
  "detalhes": {
    "giftId": 5655,
    "giftName": "Rose",
    "quantidade": 3,
    "diamantes": 1
  },
  "cursor": 14,
  "recebidoEm": 1789300000400
}
```

Campos específicos:

- `giftId`: identificador numérico do presente no TikTok;
- `giftName`: nome fornecido pelo TikTok;
- `quantidade`: `repeatCount` da sequência;
- `diamantes`: valor unitário informado pelo provedor;
- `acao`: ação configurada para aquele presente;
- `pontos`: pontos totais correspondentes à quantidade informada.

### Atenção: presentes em sequência

O TikTok pode emitir uma sequência como contagens cumulativas:

```text
Rosa quantidade 1
Rosa quantidade 2
Rosa quantidade 3
```

Isso representa uma sequência que chegou a 3, e não necessariamente 6 presentes.

Para efeitos agrupados no jogo:

1. agrupe por `usuario.uniqueId + giftId` durante uma janela curta;
2. mantenha a maior `quantidade` recebida nessa janela;
3. mantenha o maior valor de `pontos` do grupo;
4. execute uma única animação usando o total final;
5. coloque animações longas em fila FIFO para nenhum doador ser ignorado.

O gateway atual já protege o ranking contra a soma triangular do `repeatCount`. O jogo não deve recalcular nem enviar pontos de volta ao ranking.

## 7. Endpoint de ranking

```http
GET /api/v1/game/ranking?limit=10
x-api-key: API_KEY_DA_INSTANCIA
```

O limite padrão é 10 e o máximo é 50.

Resposta:

```json
{
  "instancia": "Minha Live",
  "top": [
    {
      "posicao": 1,
      "uniqueId": "maria123",
      "nickname": "Maria",
      "nickJogo": "RainhaDasPipas",
      "pontos": 21500,
      "avatar": "https://...",
      "atualizadoEm": 1789300000000
    }
  ]
}
```

Regras para o cliente:

- `pontos` é o total consolidado do ciclo;
- prefira `nickJogo` quando existir; caso contrário use `nickname` e depois `uniqueId`;
- ordene por `pontos` decrescente se precisar combinar dados;
- não substitua imediatamente um placar novo por uma resposta atrasada menor;
- dentro do mesmo ciclo, pontos são monotônicos: use `max(valorLocal, valorDaAPI)` por usuário;
- a API devolve somente jogadores com pontuação maior que zero;
- use o ranking consolidado como fonte final para definir o campeão.

Estratégia recomendada:

```pseudo
para cada item recebido:
    placar[item.uniqueId] = max(placar[item.uniqueId] ou 0, item.pontos)

ao receber evento:
    processar efeito imediatamente
    opcionalmente atualizar previsão local

ao encerrar ciclo:
    terminar eventos e animações já enfileirados
    escolher maior pontuação consolidada
    mostrar campeão
    solicitar reset
```

## 8. Reset do ciclo

```http
POST /api/v1/game/ranking/reset
Content-Type: application/json
x-api-key: API_KEY_DA_INSTANCIA

{
  "manterNicks": true
}
```

Resposta de sucesso:

```json
{
  "sucesso": true,
  "mensagem": "Ciclo de ranking resetado com sucesso.",
  "instancia": "Minha Live",
  "timestamp": 1789300000000
}
```

`manterNicks: true` zera os pontos, mas preserva os nomes definidos com `!nick`. Se for `false`, a tabela da instância é apagada completamente.

Fluxo seguro de encerramento:

1. pare de aceitar o encerramento imediato quando ainda houver eventos locais na fila;
2. termine efeitos de presentes já recebidos;
3. congele uma cópia do placar e anuncie o campeão;
4. faça o `POST /ranking/reset`;
5. somente comece a rodada seguinte depois de receber HTTP 200;
6. em caso de falha, tente novamente com intervalo de pelo menos 2 segundos;
7. após sucesso, limpe placar, cursor visual da rodada, filas e participantes locais conforme a regra do jogo.

O reset também limpa no gateway o controle temporário de sequências de presentes.

## 9. Configuração da instância para o jogo

```http
GET /api/v1/game/config
x-api-key: API_KEY_DA_INSTANCIA
```

Resposta aproximada:

```json
{
  "instancia": "Minha Live",
  "tiktokUsername": "usuario_da_live",
  "regras": {
    "pontosPorComentario": 5,
    "pontosPorLike": 1,
    "pontosPorFollow": 50,
    "pontosPorShare": 20,
    "pontosPorPresentePadrao": 200,
    "configPresentes": [
      {
        "giftId": 0,
        "nome": "Padrão",
        "acao": "PRESENTE_PADRAO",
        "pontos": 200
      }
    ]
  }
}
```

O jogo pode usar esse endpoint para informar regras na interface. Para conceder pontuação, confie preferencialmente no campo `pontos` de cada evento, pois ele já foi calculado pelo gateway.

## 10. Exemplo de cliente genérico

```pseudo
baseUrl = "http://localhost:3000/api"
apiKey = "API_KEY_DA_INSTANCIA"
cursor = 0
fila = []

a cada 500–1000 ms:
    resposta = GET baseUrl + "/v1/game/events?cursor=" + cursor + "&limit=100"
        header "x-api-key" = apiKey

    se HTTP 200:
        para evento em resposta.eventos:
            se evento.cursor > cursor:
                fila.adicionar(evento)
        cursor = resposta.cursor

a cada frame:
    processar uma quantidade limitada de eventos da fila

a cada 3–6 segundos:
    ranking = GET baseUrl + "/v1/game/ranking?limit=10"
    reconciliar sem reduzir pontuações do ciclo
```

Exemplo com cURL:

```bash
curl -H "x-api-key: SUA_API_KEY" \
  "http://localhost:3000/api/v1/game/events?cursor=0&limit=100"
```

```bash
curl -H "x-api-key: SUA_API_KEY" \
  "http://localhost:3000/api/v1/game/ranking?limit=10"
```

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: SUA_API_KEY" \
  -d '{"manterNicks":true}' \
  "http://localhost:3000/api/v1/game/ranking/reset"
```

## 11. Recomendações de robustez

- Não crie uma nova requisição se a anterior do mesmo endpoint ainda estiver em andamento.
- Use timeout entre 5 e 8 segundos.
- Após erro, aplique retry/backoff entre 1 e 3 segundos.
- Use watchdog para rearmar o polling se o timer parar.
- Limite quantos eventos são aplicados por frame para evitar travamentos.
- Mantenha uma fila local maior que o lote HTTP.
- Nunca use apelido como chave; use `uniqueId`.
- Trate campos desconhecidos de forma tolerante.
- Ignore pontuações negativas, `NaN` ou infinitas.
- Durante um ciclo, não permita que uma resposta atrasada diminua pontos.
- Ao receber muitos presentes, preserve a ordem de chegada em uma fila FIFO.
- Não descarte uma recompensa apenas porque outra animação está ativa.
- Se o ciclo terminar com recompensas enfileiradas, conclua a fila antes do campeão.
- Faça cache dos avatares e use fallback quando o download falhar.
- Não bloqueie a jogabilidade esperando uma imagem remota.

## 12. Dashboard administrativo

O dashboard é servido em:

```text
http://localhost:3000
```

Login padrão, quando não foi alterado por variáveis de ambiente:

```text
E-mail: admin@live.com
Senha: admin123
```

O dashboard utiliza JWT administrativo. Essas rotas servem para cadastrar instâncias, configurar regras, iniciar/parar a live e simular eventos. Um jogo comum não deve precisar delas.

Principais rotas administrativas:

| Método | Rota | Uso |
|---|---|---|
| POST | `/api/admin/login` | obter JWT |
| GET | `/api/admin/instancias` | listar instâncias |
| POST | `/api/admin/instancias` | criar instância |
| PUT | `/api/admin/instancias/:id` | editar instância |
| DELETE | `/api/admin/instancias/:id` | excluir instância |
| POST | `/api/admin/instancias/:id/iniciar` | conectar à live |
| POST | `/api/admin/instancias/:id/parar` | desconectar |
| PUT | `/api/admin/instancias/:id/regras` | salvar pontuação |
| POST | `/api/admin/instancias/:id/simular` | gerar evento de teste |
| GET | `/api/admin/instancias/:id/ranking` | consultar ranking |
| POST | `/api/admin/instancias/:id/ranking/reset` | zerar ranking |
| GET | `/api/admin/logs/stream` | logs via SSE |

Nas rotas administrativas protegidas:

```http
Authorization: Bearer JWT_DO_ADMIN
```

## 13. Prompt de contexto para outra IA

Copie o trecho abaixo junto com esta documentação ao iniciar outro projeto:

```text
Crie um jogo integrado ao Live Gateway descrito neste arquivo. Use HTTP polling com cursor para eventos e x-api-key para autenticação. usuario.uniqueId é a identidade permanente. O campo pontos do evento já vem calculado. Consulte o ranking consolidado separadamente e nunca permita regressão de pontos dentro do mesmo ciclo. Presentes do TikTok podem chegar com quantidade cumulativa; agrupe por usuário + giftId, use o maior total da sequência e enfileire animações longas em FIFO. Não descarte presentes enquanto outro efeito estiver ativo. Antes de encerrar a rodada, termine os eventos já recebidos, determine o campeão pela maior pontuação e só inicie a próxima rodada após o POST de reset retornar HTTP 200. Implemente timeout, backoff, watchdog, cache de avatar e fallback visual.
```

## 14. Checklist de integração

- [ ] Base URL configurável.
- [ ] API Key configurável e enviada em `x-api-key`.
- [ ] Health check funcionando.
- [ ] Polling de eventos com cursor.
- [ ] Cursor atualizado somente com resposta válida.
- [ ] Todos os cinco tipos de evento tratados.
- [ ] Participante identificado por `uniqueId`.
- [ ] Avatar com cache e fallback.
- [ ] Ranking consultado separadamente.
- [ ] Pontuação sem regressão durante o ciclo.
- [ ] Presentes cumulativos agrupados corretamente.
- [ ] Fila FIFO para efeitos/recompensas.
- [ ] Campeão escolhido por pontos, não por eliminações.
- [ ] Reset confirmado antes da próxima rodada.
- [ ] Retry e watchdog implementados.
- [ ] Teste com eventos simultâneos e pelo menos 40 participantes.

---

Esta documentação descreve o contrato existente do Live Gateway em setembro de 2026. Se o backend for alterado, atualize primeiro as estruturas de eventos, autenticação, ranking e reset neste documento.
