# Documento de visão — Jogo social de palco para lives

> Documento de produto e direção criativa elaborado a partir do vídeo de referência `WhatsApp Video 2026-09-13 at 16.58.13.mp4` e preparado para ser usado junto de `DOCUMENTACAO_API_LIVE_GATEWAY.md`.

## 1. Objetivo deste documento

Este documento descreve o jogo que deverá ser projetado, e não uma implementação pronta. Ele serve como contexto para uma equipe ou outra IA entender:

- o que aparece no vídeo de referência;
- qual é o loop de interação da live;
- como comentários, seguidores e presentes controlam o jogo;
- como organizar fila, palco, transformações e recompensas;
- como adaptar o conceito ao Live Gateway existente;
- quais comportamentos são observados e quais são propostas de produto;
- quais cuidados técnicos evitam perda de eventos, sobreposição visual e pontuação incorreta.

O novo jogo deve se inspirar no formato e no ritmo da referência, mas ter identidade visual, personagens, interface e assets próprios.

## 2. Resumo da visão

O projeto é uma experiência social automática para transmissão vertical. Espectadores entram no cenário como personagens, aguardam em uma multidão/fila e usam interações da live para conquistar destaque no palco.

A proposta pode ser resumida assim:

> “Entre na multidão, avance na fila, conquiste alguns segundos de palco e transforme seu personagem diante de toda a live.”

O jogo precisa funcionar sozinho durante longos períodos. O criador da live não deve controlar cada personagem manualmente. Comentários, follows e presentes alimentam a experiência em tempo real.

### Fantasia central

- Todo espectador pode aparecer no jogo.
- O palco é um recurso limitado e desejado.
- Presentes compram atenção visual imediata, não apenas pontos invisíveis.
- Quanto maior o presente, maior, mais raro e mais espetacular é o destaque.
- A multidão crescendo comunica que a live está movimentada.
- O espectador consegue reconhecer “seu” personagem e mostrar aos demais que provocou um acontecimento.

## 3. Evidências do vídeo analisado

### Dados técnicos

- Duração aproximada: 39,91 segundos.
- Formato: vídeo vertical de tela de celular.
- Resolução: 400 × 896.
- Proporção aproximada: 9:20, próxima ao espaço vertical ocupado por uma TikTok Live.
- Taxa registrada: aproximadamente 60 fps.
- Conteúdo: captura de uma live com um jogo 3D de personagens em um palco aberto.

### Elementos observados com alta confiança

- Cenário 3D simples, aberto, com piso amplo e céu de fim de tarde.
- Grande número de avatares humanoides visíveis simultaneamente.
- Um personagem em posição elevada/central, funcionando como foco do palco.
- Multidão organizada diante do foco principal.
- Avatares executando animações variadas, principalmente dança/idle.
- Efeitos roxos intensos próximos a participantes que receberam destaque.
- Personagens que aparecem em escala muito maior que os demais.
- Painel fixo de recompensas ocupando a faixa superior da área do jogo.
- Texto central abaixo do painel: `SPAM UR USER!` e `FLLW = DANCE`.
- Quatro cartões de ação no painel:

| Cartão observado | Custo mostrado | Interpretação direta |
|---|---:|---|
| `SKIP LINE` | 1 coin | pular/avançar na fila |
| `3 SECONDS SCENE` | 5 coins | receber três segundos de destaque no palco |
| `GIANT` | 10 coins | tornar o personagem gigante |
| `SUPER GIANT` | 30 coins | tornar o personagem supergigante |

- Os cartões usam imagens de presentes como rosa, gesto de coração e rosquinha.
- Notificações do TikTok mostram usuários enviando rosas, incluindo multiplicadores como `×1` e `×2`.
- Durante a gravação, a quantidade de espectadores oscila aproximadamente entre 421 e 454.

### Elementos que pertencem ao TikTok, não ao jogo

Estes componentes aparecem na captura, mas não devem ser reproduzidos pela aplicação:

- cabeçalho com foto/nome do criador e botão Seguir;
- contador de espectadores;
- ranking/liga/galeria do TikTok;
- feed de comentários à esquerda;
- notificações nativas de presentes na parte inferior;
- corações flutuando no lado direito;
- campo de comentário e botões inferiores.

O jogo deve apenas reservar áreas para não esconder informações importantes atrás desses elementos.

### Elementos não comprovados pelo vídeo

O trecho não mostra de forma suficiente:

- condição final de vitória;
- prêmio entregue ao vencedor;
- duração completa de uma rodada;
- regra exata de ordenação da fila;
- modo exato de relacionar o usuário do TikTok a um avatar 3D;
- comportamento após o tempo de palco terminar;
- todos os efeitos sonoros;
- se existe persistência entre lives.

As seções seguintes propõem essas regras para tornar o produto completo. Elas são decisões recomendadas, não afirmações sobre a referência.

## 4. Público e propósito

### Público principal

- criadores que fazem lives de entretenimento e interação;
- espectadores que querem aparecer na tela;
- público acostumado a presentes, rankings e respostas instantâneas;
- usuários que participam por poucos segundos e precisam entender o jogo imediatamente.

### Objetivos do produto

- aumentar comentários, follows e compartilhamentos;
- tornar presentes pequenos satisfatórios;
- criar uma progressão clara para presentes maiores;
- manter a tela interessante mesmo sem novas interações por alguns segundos;
- dar reconhecimento nominal e visual a cada doador;
- transformar a live em um espetáculo contínuo e observável.

### Princípios

1. Toda interação precisa produzir resposta perceptível.
2. Presentes nunca podem desaparecer silenciosamente.
3. O espectador deve localizar seu personagem rapidamente.
4. A recompensa deve comunicar causa, dono e resultado.
5. O jogo deve continuar legível com dezenas de participantes.
6. A monetização deve aumentar o espetáculo sem tornar a entrada gratuita inútil.
7. A automação precisa ser robusta o bastante para rodar sem operador.

## 5. Loop principal

```text
Espectador interage
        ↓
Gateway gera evento com usuário, avatar e pontos
        ↓
Jogo cria ou encontra o participante
        ↓
Personagem entra na multidão/fila
        ↓
Interações comuns geram movimento, dança e progresso
        ↓
Presentes geram prioridade, palco ou transformação
        ↓
Personagem recebe destaque visual e nominal
        ↓
Pontuação atualiza ranking e progressão
        ↓
Ciclo termina → campeão é celebrado → ranking é resetado
```

## 6. Estrutura espacial recomendada

### Palco principal

- Posicionado no terço superior/central da área jogável.
- Elevado o suficiente para o personagem em destaque aparecer sobre a multidão.
- Deve comportar um personagem comum e um supergigante sem cobrir o painel de recompensas.
- Pode usar pedestal, círculo luminoso ou plataforma animada.

### Fila e multidão

- A fila lógica define quem será o próximo participante comum no palco.
- Visualmente, os personagens podem ocupar linhas, semicírculos ou uma arquibancada.
- Avatares novos entram pelo fundo/laterais para comunicar chegada.
- Participantes próximos do palco ficam maiores e mais legíveis.
- Quando houver muitos usuários, usar níveis de detalhe e posições compactadas.

### Zona de transformação

- Área lateral ou circular onde nasce o efeito de gigante.
- Pode ser a própria plataforma, desde que o aumento de escala não esconda outros elementos.
- Transformações máximas devem deslocar automaticamente personagens próximos.

### Câmera

- Câmera vertical fixa ou com movimentos suaves programados.
- Plano geral na maior parte do tempo.
- Zoom curto durante presente importante.
- Retorno automático ao plano geral.
- Nunca depender de controle manual do streamer.

## 7. Entrada de participantes

### Gatilho recomendado

O texto `SPAM UR USER!` sugere que comentários são usados para entrada. Com a API atual, a forma mais robusta é:

- primeiro comentário do usuário no ciclo cria o personagem;
- comentários seguintes renovam atividade e podem gerar pequenos pontos;
- opcionalmente, uma palavra-chave como `entrar`, `play` ou nome do avatar confirma a entrada;
- `!nick NOME` personaliza o nome exibido usando o recurso já existente no gateway.

### Identidade

- Chave permanente: `usuario.uniqueId`.
- Nome visível: `nickJogo`, quando existir; depois `apelido`; por último `uniqueId`.
- Retrato: `usuario.avatar`.
- O personagem 3D pode ser gerado por catálogo interno, seleção determinística ou integração futura com outra plataforma.
- Nunca suponha que o `uniqueId` do TikTok seja um nome válido em Roblox ou outro serviço.

### Spawn

1. Evento chega.
2. O sistema verifica se o usuário já existe.
3. Se não existir, escolhe um slot livre na multidão.
4. Personagem entra caminhando, surgindo por portal ou caindo no cenário.
5. Nome e foto aparecem brevemente.
6. Depois da introdução, a interface individual fica discreta.

### Limites

- Recomendação inicial: 40 a 60 personagens completos.
- Participantes excedentes permanecem em uma fila lógica.
- Pode-se representar excedentes por cards, silhuetas ou contadores.
- Nunca excluir a pontuação de alguém apenas porque não há slot 3D disponível.

## 8. Sistema de fila

### Fila de palco

Cada participante possui:

```text
id
posição na fila
hora de entrada
pontos do ciclo
estado atual
tempo restante no palco
efeitos pendentes
nível de transformação
última interação
```

Fila padrão recomendada: FIFO, com quem entrou primeiro avançando primeiro.

### Ação “pular fila”

Inspirada no cartão `SKIP LINE`:

- presente pequeno move o usuário para a primeira posição elegível;
- se várias pessoas usarem a ação, respeitar a ordem em que os presentes chegaram;
- se o usuário já estiver no palco, converter a recompensa em tempo adicional ou bônus de pontos;
- mostrar uma trilha rápida do personagem atravessando a fila;
- exibir `@usuário PULOU A FILA!` sem esconder o palco.

### Fila de recompensas

Além da fila de palco, deve existir uma fila FIFO separada para apresentações de presentes:

- cada presente confirmado cria ou atualiza um ticket;
- sequências cumulativas do mesmo presente são agrupadas por usuário + `giftId`;
- uma recompensa nunca é descartada porque outra está ativa;
- a próxima começa depois da conclusão visual da atual;
- presentes do mesmo usuário recebidos durante seu efeito atual entram como novo ticket;
- o fim do ciclo aguarda a fila de recompensas esvaziar.

Estados do ticket:

```text
AGRUPANDO → AGUARDANDO → ANUNCIANDO → EXECUTANDO → RESULTADO → CONCLUÍDO
```

## 9. Mecânicas de interação

### Comentário

Entrada mínima e gratuita.

Comportamentos recomendados:

- criar personagem;
- atualizar o balão de fala de forma moderada;
- dar pontos definidos pela API;
- permitir comandos simples;
- ativar uma reação curta, sem interromper recompensas pagas.

Antispam visual:

- no máximo um balão por personagem a cada poucos segundos;
- comentários continuam valendo conforme a API, mas não precisam todos virar animação;
- filtrar texto ofensivo antes de exibir no mundo.

### Follow

O vídeo declara `FLLW = DANCE`.

Implementação de visão:

- personagem executa dança especial;
- spotlight colorido acompanha o usuário;
- nome aparece por 1,5 a 2,5 segundos;
- se o usuário ainda não tiver personagem, ele entra já dançando;
- follow não entra na fila de presentes, pois é uma reação curta e paralela;
- pontos vêm do campo `pontos` da API.

### Compartilhamento

Recompensa proposta:

- dança em dupla ou onda coletiva próxima ao usuário;
- pequeno avanço na fila;
- partículas sociais/ícone de compartilhamento;
- destaque inferior curto.

### Curtidas

Recompensa proposta:

- preencher uma barra comunitária;
- marcos da barra ativam chuva de confete, troca de música ou dança coletiva;
- evitar disparar som por curtida individual;
- processar `detalhes.quantidade` como lote.

## 10. Catálogo de presentes e recompensas

Os valores devem ser configuráveis por `giftId` no dashboard. Os nomes abaixo descrevem papéis de design.

### Nível 1 — Avançar/pular fila

Referência: `SKIP LINE`, custo visual de 1 coin.

Resultado:

- usuário vai para a frente da fila de palco;
- rastro luminoso curto;
- som rápido e cômico;
- card com foto, nome e presente;
- caso já esteja no palco: +1 a +2 segundos de destaque.

### Nível 2 — Três segundos de palco

Referência: `3 SECONDS SCENE`, custo visual de 5 coins.

Resultado:

- interrompe apenas a rotação normal, nunca outro presente já confirmado;
- usuário ocupa o foco por três segundos completos;
- câmera aproxima suavemente;
- personagem escolhe/recebe uma pose ou dança;
- contador `3… 2… 1…` aparece próximo ao pedestal;
- ao terminar, o usuário retorna à multidão ou ao fim da fila.

Combos podem acumular duração até um teto configurável para evitar monopolização.

### Nível 3 — Gigante

Referência: `GIANT`, custo visual de 10 coins.

Resultado:

- personagem cresce com antecipação, impacto e onda circular;
- escala sugerida: 2,0× a 2,8×;
- duração sugerida: 8 a 15 segundos;
- aura específica e passos com pequenas ondas no chão;
- câmera enquadra automaticamente;
- nome permanece legível acima do personagem;
- outros personagens se afastam sem colisões violentas.

### Nível 4 — Supergigante

Referência: `SUPER GIANT`, custo visual de 30 coins.

Resultado:

- transformação em múltiplos estágios;
- escala sugerida: 3,5× a 5×, limitada pelo enquadramento;
- céu e iluminação mudam temporariamente;
- explosão de partículas e reação coletiva da multidão;
- câmera recua para mostrar a dimensão;
- título exclusivo, por exemplo `SUPERSTAR DA LIVE`;
- duração sugerida: 12 a 20 segundos;
- prioridade visual máxima, executada pela fila de recompensas.

### Presentes acima do catálogo

Proposta para presentes raros:

- transformação lendária;
- troca temporária do cenário;
- entrada de criatura/veículo;
- domínio do palco por tempo limitado;
- minievento coletivo;
- nome do doador fixado no cenário durante o ciclo.

O valor financeiro nunca deve ser deduzido apenas de `diamantes`. O dashboard deve mapear `giftId` para uma ação de jogo explícita.

## 11. Agrupamento e intensidade

Uma sequência do TikTok pode chegar como `quantidade` 1, depois 2, depois 3. O jogo deve manter o maior total durante a janela de agrupamento, e não somar 1 + 2 + 3.

Chave do grupo:

```text
usuario.uniqueId + giftId
```

Janela recomendada: 500 a 900 ms após a última atualização, ou sinal explícito de fim quando disponível.

Exemplo:

```text
eventos: 1, 2, 3, 4 rosas
resultado: um ticket de 4 rosas
```

Escalonamento sugerido:

- quantidade aumenta duração até um teto;
- quantidade aumenta partículas e intensidade sonora;
- grandes sequências desbloqueiam uma variante rara;
- a curva deve ser sublinear para preservar desempenho;
- o card mostra claramente `×N`.

## 12. Estados do personagem

```text
FORA_DO_CENÁRIO
    ↓
ENTRANDO
    ↓
NA_MULTIDÃO/FILA
    ↓
AVANÇANDO
    ↓
NO_PALCO
    ├→ DANÇANDO
    ├→ GIGANTE
    ├→ SUPERGIGANTE
    └→ REAÇÃO_ESPECIAL
    ↓
RETORNANDO
    ↓
NA_MULTIDÃO/FILA
```

Regras:

- um estado pago não pode ser cancelado por reação gratuita;
- transformações podem ser enfileiradas;
- o personagem sempre volta a uma escala e posição válidas;
- cada transição precisa ter timeout de segurança;
- ao desconectar/reiniciar, nenhum personagem deve ficar preso em estado intermediário.

## 13. Interface vertical

### Faixa superior do jogo

Painel permanente de presentes com quatro cards. Cada card deve mostrar:

- imagem do presente;
- ação em duas ou três palavras;
- custo ou presente necessário;
- cor própria por nível;
- alto contraste e contorno forte.

O painel da referência é chamativo e legível, porém ocupa bastante altura. A nova versão deve manter clareza sem esmagar a área 3D.

Recomendação: no máximo 18% a 23% da altura total para instruções permanentes.

### Linha de chamada

Logo abaixo do catálogo:

```text
COMENTE PARA ENTRAR • SIGA PARA DANÇAR
```

O texto deve ser localizado em português e compreensível em menos de dois segundos.

### Cards temporários

Ao receber presente:

- foto do perfil;
- `@uniqueId` ou apelido;
- ícone/nome do presente;
- multiplicador;
- recompensa recebida;
- animação curta de entrada e saída.

Posicionar fora do foco principal e nunca sobre o rosto do personagem em destaque.

### Ranking

Top 3 compacto, opcionalmente recolhível durante supertransformações.

- medalha;
- avatar;
- nome;
- pontos;
- coroa dinâmica no líder dentro do cenário.

### Safe areas do TikTok

Considerando a captura vertical:

- topo extremo: reservado ao cabeçalho da live;
- esquerda inferior: comentários e notificações;
- direita: corações e botões;
- base: caixa de comentário e controles;
- centro: preservar para o personagem e efeitos principais.

O layout deve ser testado com uma máscara que simule a interface real do TikTok.

## 14. Direção visual

### Cenário

- praça, arena ou passarela aberta;
- horizonte e céu colorido para profundidade;
- materiais simples e iluminação agradável;
- palco facilmente identificável;
- fundo com movimento lento para não parecer imagem parada.

### Personagens

- silhuetas diferentes e cores variadas;
- escala padrão pequena o suficiente para formar multidão;
- personalização determinística por usuário;
- destaque pago altera aura/escala, não destrói a identidade original;
- nomes aparecem apenas quando úteis.

### Efeitos

Hierarquia recomendada:

| Evento | Intensidade |
|---|---:|
| comentário | baixa |
| curtidas em lote | baixa/média |
| follow | média |
| compartilhar | média |
| pular fila | média |
| palco | média/alta |
| gigante | alta |
| supergigante | máxima |

Efeitos possíveis:

- portal roxo/rosa;
- anel no chão;
- partículas ascendentes;
- flash de impacto;
- spotlight;
- rastro ao avançar;
- confete;
- mudança breve no céu;
- reação sincronizada da multidão.

Evitar partículas opacas cobrindo toda a tela durante muitos segundos.

## 15. Áudio

O trecho contém áudio, mas não permite documentar com segurança cada som isolado do jogo. A nova direção sonora recomendada é:

- entrada: pop curto e simpático;
- avanço de fila: whoosh rápido;
- palco: fanfarra curta;
- gigante: subida tonal + impacto grave;
- supergigante: antecipação, silêncio curtíssimo e explosão;
- follow/dança: vinheta rítmica;
- marco coletivo: torcida/confete;
- erro/retry: não tocar para o público, apenas registrar.

Regras:

- evitar sobrepor dezenas de sons;
- aplicar prioridade por categoria;
- limitar efeitos simultâneos;
- abaixar música durante anúncios importantes;
- permitir trocar cada arquivo sem recompilar o jogo;
- não copiar áudio protegido da referência.

## 16. Pontuação, ranking e campeão

### Fonte de pontos

- cada evento já chega com `pontos` calculados pelo gateway;
- o jogo não deve multiplicar novamente pelo preço do presente;
- o endpoint `/ranking` contém o total consolidado do ciclo;
- dentro do ciclo, uma resposta atrasada nunca pode reduzir o placar local.

### Ranking

- Top 3 visível;
- atualização a cada 3 a 6 segundos;
- previsão local pode atualizar imediatamente;
- reconciliação: `max(local, API)` por usuário dentro do ciclo;
- trocar a coroa assim que o líder mudar.

### Final de ciclo proposto

Como o vídeo não mostra uma conclusão, recomenda-se:

1. ciclos de 5 a 10 minutos;
2. cronômetro discreto;
3. quando zerar, parar de iniciar interações comuns novas;
4. terminar presentes já recebidos e sua fila visual;
5. campeão = maior pontuação, nunca maior número de animações;
6. mostrar avatar, nome, pontos e título;
7. chuva de confete e pose coletiva;
8. chamar `POST /api/v1/game/ranking/reset`;
9. começar nova rodada somente após HTTP 200.

### Prêmios sugeridos

Prêmios virtuais e visuais, configuráveis:

- troféu no perfil durante a próxima rodada;
- skin/cor/aura de campeão;
- entrada prioritária no próximo ciclo;
- estátua temporária no fundo do cenário;
- nome no “Hall da Live”;
- moldura dourada no ranking.

Se houver prêmio real, sua entrega, regras e elegibilidade devem existir fora do jogo e ser comunicadas claramente pelo criador.

## 17. Integração com o Live Gateway

Usar junto de `DOCUMENTACAO_API_LIVE_GATEWAY.md`.

Mapeamento mínimo:

| Evento da API | Resposta do jogo |
|---|---|
| `COMENTARIO` | criar personagem/reação/balão |
| `LIKE` | barra coletiva e pontos |
| `SEGUIDOR` | dança especial |
| `COMPARTILHAMENTO` | reação social/avanço leve |
| `PRESENTE` | criar ticket de recompensa |

Dados indispensáveis:

```text
evento.cursor
evento.tipo
evento.acao
evento.pontos
usuario.uniqueId
usuario.apelido
usuario.avatar
detalhes.giftId
detalhes.giftName
detalhes.quantidade
```

### Frequências recomendadas

- eventos: 500 a 1.000 ms;
- lote: até 100;
- ranking: 3 a 6 segundos;
- timeout HTTP: 5 segundos;
- watchdog: 8 a 10 segundos;
- retry após erro: 1 a 3 segundos.

### Regra crítica

Receber o evento e atualizar pontos são responsabilidades diferentes de reproduzir uma animação. O evento deve ser contabilizado imediatamente e a recompensa visual pode aguardar na fila.

## 18. Arquitetura lógica sugerida

```text
APIClient
├── polling de eventos
├── cursor
├── ranking
├── reset
└── retry/watchdog

EventRouter
├── comentário
├── like
├── follow
├── share
└── presente

PlayerRegistry
├── jogadores por uniqueId
├── perfis e avatares
├── slots da multidão
└── pool de personagens

StageQueue
├── fila normal
├── avanço pago
└── ocupante atual

RewardQueue
├── agrupamento cumulativo
├── FIFO
├── máquina de estados
└── conclusão garantida

ScoreManager
├── previsão local
├── reconciliação da API
├── Top 3
└── campeão

PresentationDirector
├── câmera
├── cards
├── efeitos
├── áudio
└── safe areas
```

## 19. Concorrência e prioridades

Prioridade visual proposta:

```text
SUPERGIGANTE
GIGANTE
PALCO PAGO
PULAR FILA
FOLLOW/SHARE
COMENTÁRIO/LIKE
```

Isso não significa descartar eventos menores. Significa:

- evento é registrado;
- pontuação é aplicada;
- efeito curto pode acontecer em paralelo se não atrapalhar;
- efeito principal espera sua vez;
- cada ticket termina ou expira apenas por uma regra explícita e auditável.

Casos importantes:

- dois usuários enviam presente ao mesmo tempo: ordem pelo cursor;
- mesmo usuário envia outro presente durante seu destaque: novo ticket;
- personagem caiu/despawnou antes do ticket: recriar antes da recompensa;
- lotação máxima: manter ticket e perfil mesmo sem slot imediato;
- ciclo zera durante a fila: aguardar recompensas confirmadas;
- API desconecta: manter estado atual, tentar reconectar e não repetir cursores.

## 20. Desempenho

- usar pool de personagens;
- limitar esqueletos/animações complexas simultâneas;
- reduzir atualização de personagens distantes;
- usar partículas com pool e teto global;
- cachear avatares;
- limitar downloads simultâneos;
- não recriar UI do ranking a cada frame;
- processar número limitado de eventos por frame;
- testar com 40, 60 e 100 identidades lógicas;
- separar participantes lógicos de personagens 3D ativos.

Metas sugeridas:

- 60 fps em computador de transmissão intermediário;
- degradação aceitável até 30 fps sob pico;
- resposta visual a evento comum em até 1,5 segundo;
- presente reconhecido em até 1 segundo após chegar ao jogo;
- nenhuma recompensa perdida em teste de rajada.

## 21. Segurança e moderação

- nunca exibir mensagens sem filtro quando houver texto livre;
- limitar tamanho de apelidos e comandos;
- impedir markup/código em nomes;
- não expor API Key na tela;
- manter JWT administrativo separado da API Key do jogo;
- usar imagens de avatar apenas como conteúdo remoto não confiável;
- aplicar timeout e limite de tamanho no download;
- fornecer botão administrativo para ocultar/banir usuário;
- registrar eventos importantes para auditoria.

## 22. MVP recomendado

### Obrigatório

- cenário vertical com palco e multidão;
- entrada por comentário;
- identificação por `uniqueId`;
- follow ativa dança;
- quatro níveis de recompensa configuráveis;
- fila FIFO de palco;
- fila FIFO de presentes;
- agrupamento correto de sequências;
- personagem gigante e supergigante;
- cards com foto/nome/presente;
- Top 3;
- campeão por pontos;
- reset sincronizado;
- reconexão automática;
- painel de configuração de URL/API Key e efeitos.

### Depois do MVP

- temas de cenário;
- skins persistentes;
- galeria/hall de campeões;
- metas comunitárias;
- votação por comentários;
- minijogos no palco;
- tradução automática da interface;
- controle remoto pelo dashboard;
- recompensas sazonais.

## 23. Critérios de aceitação

### Entrada

- comentar cria exatamente um participante por `uniqueId`;
- comentar novamente não duplica o personagem;
- avatar com falha recebe imagem reserva.

### Fila

- ordem comum é previsível;
- pular fila funciona sem apagar outro usuário;
- duas compras simultâneas preservam a ordem dos cursores.

### Presentes

- sequência 1, 2, 3 resulta em quantidade final 3;
- todo presente produz reconhecimento visual;
- nenhum presente é descartado durante outro efeito;
- efeitos voltam ao estado normal ao terminar.

### Ranking

- pontuação não cai temporariamente;
- respostas atrasadas não substituem totais maiores;
- campeão é o maior valor de pontos;
- reset só inicia nova rodada após confirmação.

### Visual

- personagem em destaque permanece visível;
- cards não cobrem a ação;
- Top 3 não domina a tela;
- supergigante cabe no enquadramento;
- interface continua legível sob a sobreposição do TikTok.

### Estresse

- 100 eventos em rajada;
- 40 personagens ativos;
- 20 presentes enfileirados;
- reconexão após perda do gateway;
- presente recebido no último segundo do ciclo;
- troca de líder no instante do encerramento.

## 24. Riscos e decisões pendentes

Antes da produção, definir:

- engine do novo jogo;
- estilo original dos personagens;
- como o usuário escolhe ou recebe um avatar;
- duração da fila e do palco gratuito;
- gifts reais associados a cada ação;
- teto de tempo acumulado;
- limite de personagens 3D;
- política de mensagens e nomes;
- persistência de campeões;
- existência ou não de prêmio real;
- resolução final e método de captura da live.

Riscos principais:

- excesso de personagens tornar a tela ilegível;
- presentes contínuos monopolizarem o palco;
- avatar gigante esconder a interface;
- sequência cumulativa ser pontuada em duplicidade;
- diferença de tempo entre eventos e ranking;
- conteúdo do TikTok cobrir os principais controles;
- depender de assets ou identidade visual copiados da referência.

## 25. Prompt para entregar a outra IA

```text
Crie o projeto descrito no DOCUMENTO_VISAO_JOGO_PALCO_LIVE.md e integre-o conforme DOCUMENTACAO_API_LIVE_GATEWAY.md. O produto é um jogo social vertical e automático para lives: espectadores entram como personagens por comentários, formam uma multidão/fila e recebem destaque no palco. Follow ativa dança. Presentes configuráveis permitem pular fila, ganhar tempo de palco, virar gigante ou supergigante. Implemente StageQueue e RewardQueue separadas. RewardQueue deve ser FIFO, agrupar repeatCount cumulativo por uniqueId + giftId e nunca descartar uma recompensa porque outra está ativa. Pontos vêm da API e o campeão é sempre o maior total consolidado. Preserve safe areas do TikTok, use UI compacta e mantenha o personagem em destaque visível. Crie identidade visual original; não copie personagens, logos, imagens ou áudios do vídeo. Antes de implementar, apresente arquitetura, cenas/componentes, estados, modelos de dados, plano de testes e decisões ainda pendentes.
```

## 26. Resultado esperado

O resultado ideal não é apenas uma multidão reagindo a gifts. É um programa de palco automático no qual cada interação tem significado:

- comentário coloca o espectador dentro do mundo;
- follow faz o personagem se apresentar;
- presente pequeno altera sua posição social;
- presente médio compra tempo de atenção;
- presente grande muda sua escala e domina o espetáculo;
- ranking cria continuidade;
- campeão fecha o ciclo com reconhecimento.

Essa estrutura transforma a doação em narrativa visível: o público entende o que aconteceu, quem causou, qual foi a recompensa e o que pode fazer para participar também.

---

Documento baseado na observação do vídeo de referência de 39,91 segundos. Afirmações sobre condição de vitória, prêmios persistentes e regras completas de fila são propostas de design porque esses comportamentos não aparecem integralmente no trecho analisado.
