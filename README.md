# MinhaCopa Flutter

Front mobile (iOS/Android) da MinhaCopa em Flutter, usando a mesma API do Nuxt.

## API usada

Mesma API do Nuxt:

- Base padrao: `https://api.minhacopa.online`
- Configuravel via: `--dart-define=APP_API_BASE=...`

## Status atual

- Fase 0 concluida:
  - Shell WebView com paridade imediata da interface web.
- Fase 1 concluida:
  - `Dio` + refresh token automatico.
  - `flutter_secure_storage`.
  - `go_router` com guard de autenticacao.
  - Login/registro nativo.
- Fase 2 concluida:
  - Peladas nativo: listar, criar, editar, detalhe.
  - Jogadores nativo: listar por pelada, criar, editar, filtro ativo/inativo.
  - Temporadas nativo: listar, criar, encerrar, excluir.

## Rotas nativas principais

- `/peladas`
- `/peladas/new`
- `/peladas/:peladaId`
- `/peladas/:peladaId/edit`
- `/peladas/:peladaId/jogadores`
- `/peladas/:peladaId/jogadores/new`
- `/peladas/:peladaId/jogadores/:jogadorId/edit`
- `/peladas/:peladaId/temporadas`

Fallback web mantido:

- `/app`

## Rodar

```bash
cd e:\minhacopa\minhacopa.online\public_html\frontcopa_flutter
flutter pub get
flutter run
```

## Variaveis (`dart-define`)

- `APP_API_BASE` (default `https://api.minhacopa.online`)
- `APP_WEB_URL` (default `https://minhacopa.online`)
- `APP_ALLOWED_HOSTS`

Exemplo (Nuxt local no Android Emulator):

```bash
flutter run \
  --dart-define=APP_API_BASE=https://api.minhacopa.online \
  --dart-define=APP_WEB_URL=http://10.0.2.2:5000 \
  --dart-define=APP_ALLOWED_HOSTS=10.0.2.2,localhost,127.0.0.1,minhacopa.online,www.minhacopa.online,api.minhacopa.online
```

## Validacao

- `flutter analyze` sem erros
- `flutter test` passando

## Proximo alvo

Plano completo: `MIGRACAO_NATIVA_FLUTTER.md`  
Próxima fase natural: Rodadas, Partidas, Gols, Times e Transferencias.
