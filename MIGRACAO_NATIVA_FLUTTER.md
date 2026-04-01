# Migracao Nativa Flutter - MinhaCopa

## Objetivo

Sair do modo WebView (paridade imediata) para app Flutter 100% nativo, mantendo o mesmo comportamento funcional do Nuxt.

## Entregas concluidas

- Fase 0:
  - Projeto Flutter criado em `public_html/frontcopa_flutter`.
  - Paridade funcional imediata via WebView para Android e iOS.
  - Configuracoes mobile aplicadas para execucao e upload.
- Fase 1 (fundacao):
  - `Dio` com interceptor de refresh token.
  - `flutter_secure_storage` para sessao.
  - `go_router` com guard de autenticacao.
  - Login/registro nativo conectado aos mesmos endpoints do Nuxt.
  - Modelos Dart centrais espelhando `types/index.ts`.
- Fase 2 (core inicial):
  - Peladas: listar, criar, editar e detalhar.
  - Jogadores: listar por pelada, criar, editar e filtrar por status.
  - Temporadas: listar, criar, encerrar e excluir.

## Escopo funcional mapeado no Nuxt

Rotas principais identificadas em `frontcopa/pages`:

- Autenticacao: `/login`, `/register`
- Home: `/`
- Peladas: `/peladas`, `/peladas/nova`, `/peladas/[id]`, `/peladas/[id]/edit`, `/peladas/[id]/publico`
- Jogadores: `/peladas/[id]/jogadores/*`, `/perfil/[jogadorId]`
- Temporadas/Rodadas/Partidas: `/peladas/[id]/temporadas/*`, `/peladas/[id]/rodadas/*`, `/peladas/[id]/partidas/[partidaId]`
- Times/Transferencias: `/peladas/[id]/temporadas/[temporadaId]/times/*`, `/transferencias/*`
- Rankings/Estatisticas/Comparativo: `/rankings`, `/estatisticas`, `/comparativo`
- Votacoes: `/peladas/[id]/votacoes/*`, `/votacao/[votacaoId]/publico`
- Admin: `/admin`

Composables e endpoints mapeados:

- Auth: `/api/usuarios/login`, `/registrar`, `/me`, `/refresh`
- Peladas: `/api/peladas/*`
- Jogadores: `/api/peladas/{peladaId}/jogadores`, `/api/publico/jogadores/*`
- Temporadas/Rodadas/Partidas/Gols/Substituicoes: `/api/peladas/temporadas/*`, `/rodadas/*`, `/partidas/*`, `/gols/*`, `/substituicoes/*`
- Times/Transferencias: `/api/peladas/times/*`, `/transferencias/*`
- Rankings/Scout: `/api/peladas/temporadas/{id}/ranking/*`, `/scout`
- Votacoes: `/api/peladas/votacoes/*`

## Plano de execucao nativo (ordem recomendada)

### Fase 1 - Fundacao (concluida)

- Camada `Dio` + interceptor de refresh token automatico (equivalente ao `useApi.ts`).
- Persistencia segura com `flutter_secure_storage`.
- Modelos Dart centrais (`User`, `Pelada`, `Jogador`, `Temporada`, `Time`, `Rodada`, `Partida`, `Votacao`).
- Roteamento com `go_router` e guards de autenticacao.
- Tema base alinhado ao Nuxt.

### Fase 2 - Core funcional (parcialmente concluida)

- Autenticacao completa (login, registro, sessao, logout).
- CRUD de peladas.
- CRUD de jogadores (incluindo upload de foto).
- CRUD de temporadas.
- Pendencia desta fase: ampliar cobertura de paginacao/UX e validar todos os cenarios de upload em device real.

### Fase 3 - Operacao esportiva (2 sprints)

- Rodadas, partidas, gols em tempo real.
- Times (formacao, edicao, escudo, elenco).
- Substituicoes e transferencias.

### Fase 4 - Inteligencia e publico (1-2 sprints)

- Rankings, scout e comparativo de jogadores.
- Votacoes (abertura, voto, resultado, votantes).
- Perfis publicos (pelada e jogador).

### Fase 5 - Admin + hardening (1 sprint)

- Dashboard admin.
- Observabilidade, crash reporting e analytics.
- Testes E2E + regressao completa contra Nuxt.
- Publicacao Android/iOS.

## Estrategia de migracao sem risco

- Manter WebView como fallback por modulo enquanto telas nativas entram em producao.
- Migrar por feature flag:
  - Tela nativa ON: usa fluxo Flutter.
  - Tela nativa OFF: abre rota web correspondente na WebView.
- Objetivo: zero downtime e sem perda de funcionalidade durante a transicao.

## Criterios de pronto (paridade nativa)

- Todas as rotas de negocio acima com equivalencia de comportamento.
- Uploads funcionando (logo, capa, foto, escudo).
- Fluxos de erro e permissao equivalentes.
- Testes automatizados de regressao passando.
