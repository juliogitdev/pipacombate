# PipaJogo Live

Jogo 2D para lives do TikTok desenvolvido no Godot 4.7. O público cria e fortalece
pipas por comentários, curtidas, seguidores, compartilhamentos e presentes. O jogo
possui ranking, ciclos, campeão por pontuação, quebrão, avatares e painel separado.

## Requisitos

- Godot `4.7.2` ou compatível.
- Acesso à API TikTok Live Manager.
- Git, para sincronizar o projeto entre computadores.

## Primeira configuração

1. Clone o repositório.
2. Copie `secrets.example.json` para `secrets.json`.
3. Preencha em `secrets.json`:

```json
{
  "api_key": "SUA_CHAVE_DA_API",
  "live_username": "USUARIO_TIKTOK_SEM_ARROBA"
}
```

4. Abra `project.godot` no Godot e execute o projeto.

`secrets.json` é ignorado pelo Git. Nunca coloque chaves reais no `config.json`, em
commits, issues ou mensagens públicas.

## API pública

O projeto está configurado para:

```text
https://tiktok-roblox-live-manager.onrender.com
```

O cliente usa `/api/bridge/register` e long polling em `/api/bridge/{sid}/poll`.
Também existe compatibilidade com o gateway antigo usando `api.modo = "legado"`.

## Executar o painel

O painel é outro projeto Godot, localizado em `painel/project.godot`. Abra-o em uma
segunda janela. Durante o desenvolvimento ele edita o `config.json` e escreve comandos
em `comandos.jsonl`. Esse arquivo é local e não deve ser versionado.

## Testes

No PowerShell:

```powershell
& "C:\caminho\para\Godot.exe" --headless --path . --script res://tests/test_mvp.gd
```

O teste cobre arena, 40 pipas, movimento, avatares WebP, API v4, ranking, presentes,
quebrão, eventos, campeão e reinício de ciclo.

## Exportar

- Jogo: preset `PipaJogo Windows`, saída padrão `build/PipaJogo.exe`.
- Painel: preset `PipaPainel Windows`, saída padrão `painel/build/PipaPainel.exe`.

Para distribuição, coloque o jogo, o painel, `config.json` e um `secrets.json` local
na mesma pasta. Não envie o `secrets.json` ao GitHub.

## Fluxo entre PC e notebook

No PC:

```bash
git add .
git commit -m "Descrição da alteração"
git push
```

No notebook:

```bash
git clone URL_DO_REPOSITORIO
cd game
git pull
```

Crie um `secrets.json` separado em cada computador. Antes de começar a trabalhar,
execute `git pull`; ao terminar, faça commit e `git push`.
