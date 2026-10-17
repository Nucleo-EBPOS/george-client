# George — your remote support

Cliente desktop/web do **George** (acesso remoto), fork rebrandizado do
[RustDesk](https://github.com/rustdesk/rustdesk) (AGPL-3.0). Servidor, relay, API e chave pública de
produção vêm embutidos: o usuário instala e usa, sem configurar nada.

- Site/portal: https://georgedesk.com · Spec: `docs/specs/03-client.md` (repo `george`)
- Upstream e regras de sincronização: [`GEORGE-UPSTREAM.md`](GEORGE-UPSTREAM.md)

## O que o George adiciona

- Marca George (nome, ids `com.georgedesk.app`, ícones, "Sobre" com crédito AGPL).
- `georgedesk.com` (ID/relay `:21117`) + `https://georgedesk.com` (API) + chave pública embutidos e travados
  (`src/george/mod.rs`). Dev: `GEORGE_DEV_SERVER=1` no ambiente libera editar o servidor.
- Tema dark/light a partir de `design-system/tokens.css` (`flutter/lib/george/george_theme.dart`).
- Tela inicial: ID grande e copiável, **Conectar** (ID ou código de convite), **Convidar**, card
  **Modo Host ON/OFF** (status na tela e na bandeja), conta (login/"Meus computadores").
- Protocolo `george://connect?code=AB7K2` (e `?id=&pw=`) — Windows (registro, no install), macOS
  (`CFBundleURLTypes`), Linux (`x-scheme-handler/george`).
- Atualização: manifest `https://georgedesk.com/api/v1/releases/latest`.
- i18n pt-BR (padrão) e en (`src/george/lang.rs`).

## Build

Builds nativos saem do GitHub Actions:

| Workflow | Quando | Saída |
|---|---|---|
| `george-build.yml` | `workflow_dispatch` / chamado pelos outros | artefatos `George-<versão>-<plataforma>` |
| `george-release.yml` | tag `vX.Y.Z` | GitHub Release com Windows (exe + MSI silencioso), macOS (dmg x86_64/aarch64), Linux (deb + AppImage), web (zip) + `George-<versão>-manifest.json` |
| `george-ci.yml` | PR para `master` | compila tudo sem publicar |

```bash
gh workflow run george-build.yml -f upload-tag=nightly   # build de teste (sem release)
git tag v1.5.1 && git push origin v1.5.1                 # release
```

MSI silencioso: `msiexec /i George-<v>-windows-x86_64.msi /qn`. Instalação do exe sem UI:
`George-<v>-windows-x86_64.exe --silent-install`.

Build local (mesmos passos do upstream): https://rustdesk.com/docs/en/dev/build/ — os valores
de servidor são lidos de `RENDEZVOUS_SERVER`, `RELAY_SERVER`, `API_SERVER`, `RS_PUB_KEY` em tempo de
compilação (defaults = produção).

## Integração com a george-api (`/api/v1`)

| Uso | Endpoint |
|---|---|
| Login / address book ("Meus computadores") | rotas upstream `/api/login`, `/api/ab`, … |
| Criar convite (botão Convidar, logado) | `POST /invites` `{device_id, session_password, max_uses:1, ttl_minutes:60}` → `{code, link?, expires_at?}` |
| Consumir convite (`george://connect?code=`) | `POST /invites/{code}/consume` → `{rustdesk_id|device_id|id, session_password|password}` (fallback `GET /invites/{code}`) |
| Modo Host | `PATCH /devices/{rustdesk_id}` `{host_enabled}` · `POST /devices/heartbeat` `{id, uuid, host_enabled, platform, version}` (60 s) |
| Atualização | `GET /releases/latest` → `{"url": "https://github.com/Nucleo-EBPOS/george-client/releases/tag/vX.Y.Z"}` |

## Licença

AGPL-3.0, como o upstream. Código-fonte: https://github.com/Nucleo-EBPOS/george-client

## Assinatura de código (atual e o que falta)

Hoje os binários saem **sem assinatura oficial**:

- **macOS:** o build assina o `George.app` **ad-hoc** (`codesign --force --deep -s -`) antes de
  montar o `.dmg`. Isso faz o app **rodar no Apple Silicon** (sem a ad-hoc o Gatekeeper mata o
  binário e o Finder diz *"o aplicativo está danificado"*). Na 1ª abertura o usuário ainda vê
  *"desenvolvedor não identificado"* → **botão direito ▸ Abrir** (ou `xattr -dr com.apple.quarantine George.app`).
- **Windows:** o `.exe`/`.msi` não têm Authenticode → o **SmartScreen** alerta na 1ª execução.

### Para remover os avisos de vez (necessário para distribuir/vender)

- **macOS — Apple Developer (conta paga, US$99/ano):** criar os secrets no repositório e o
  workflow já usa os passos de assinatura+notarização reais (herdados do upstream):
  `MACOS_P12_BASE64` (certificado *Developer ID Application* em base64), `MACOS_P12_PASSWORD`,
  `MACOS_CODESIGN_IDENTITY` (ex.: `Developer ID Application: Nome (TEAMID)`) e
  `MACOS_NOTARIZE_JSON` (chave da App Store Connect API para `rcodesign notary-submit`).
  Com eles presentes, o passo *"Codesign app and create signed dmg"* assina com Developer ID e
  **notariza/staple** o dmg → sem avisos.
- **Windows — certificado de code signing (preferência EV):** adicionar a assinatura
  (ex.: `signtool`/azure-code-signing) ao passo de empacotamento; sem isso o SmartScreen persiste
  até o app ganhar reputação. Os hooks de assinatura do upstream (`SIGN_BASE_URL`/`SIGN_SECRET_KEY`)
  foram removidos do fork; reintroduzir com o provedor escolhido.

Enquanto não houver contas, a ad-hoc (macOS) + instruções ao usuário (botão direito ▸ Abrir /
"Executar mesmo assim" no SmartScreen) é o caminho suportado.
