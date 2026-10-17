# George × upstream (rustdesk/rustdesk)

O `george-client` é um fork rebrandizado do RustDesk (AGPL-3.0). A regra é **mudança mínima e
isolada**: tudo que é do George vive em arquivos novos, e cada toque no core upstream é
marcado com `// GEORGE:` (Rust/Dart) ou `# GEORGE:` (YAML/Python/shell). Este arquivo é o mapa
para quem for sincronizar com o upstream.

## Como sincronizar

```bash
scripts/sync-upstream.sh            # fetch upstream + merge em branch sync/upstream-<data>
python3 scripts/george-gen-workflow.py   # regenera .github/workflows/george-build.yml
scripts/george-gen-icons.sh /srv/george/brand   # só se o upstream mexeu em ícones/assets
```

Remotes: `origin` = `Nucleo-EBPOS/george-client`, `upstream` = `rustdesk/rustdesk`.
Submódulo `libs/hbb_common` segue o upstream sem alterações (os valores de servidor/chave são
sobrescritos em runtime, não no submódulo).

## Arquivos 100% do George (sem conflito esperado)

| Caminho | Papel |
|---|---|
| `src/george/mod.rs` | identidade (APP_NAME/ORG), servidor/relay/API/chave embutidos (`option_env!` com defaults de produção), URL do manifest de atualização, Modo Host p/ bandeja |
| `src/george/lang.rs` | traduções pt-BR/en próprias (chaves `george_*`) e sobrescritas |
| `flutter/lib/george/*.dart` | tema (tokens), tela inicial, Modo Host, conta, convites, deep link, cliente da API |
| `flutter/assets/george/` | logo/ícone de marca |
| `web-landing/` | página `/web` (convite `?code=`, downloads) |
| `scripts/george-*.{sh,py}`, `scripts/sync-upstream.sh` | ícones, workflow, sync |
| `.github/workflows/george-*.yml` | CI/release (`george-build.yml` é **gerado**) |

## Patches no core (procure por `GEORGE`)

| Arquivo | O que | Conflito provável? |
|---|---|---|
| `src/lib.rs` | `pub mod george;` | baixo |
| `src/common.rs` | `load_custom_client()` chama `george::apply()`; `check_software_update` não pula custom client; URL do manifest = george-api; `release_id_from_update_url` aceita repo `Nucleo-EBPOS/george-client` | médio (função de update muda com frequência) |
| `src/lang.rs` | overlay `george::lang::translate` antes das tabelas | baixo |
| `src/tray.rs` | tooltip mostra Modo Host ON/OFF | baixo |
| `src/platform/macos.rs` | labels/plists `com.carriez.*` → `george::ORG` | baixo |
| `src/platform/privileges_scripts/*` | `com.carriez.RustDesk` → `com.georgedesk.RustDesk` (o nome é trocado em runtime) | baixo |
| `flutter/lib/common.dart` | cores `MyTheme` (dourado), temas passam por `GeorgeTheme`, hook `george://` em `handleUriLink`, `checkUpdate` | **alto** (arquivo grande, muda sempre) |
| `flutter/lib/main.dart` | `?code=` no web; título | baixo |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | painel esquerdo usa `GeorgeHomeHero`; largura 320 | médio |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | "Sobre": links, copyright, crédito AGPL | baixo |
| `flutter/lib/mobile/pages/settings_page.dart` | links do "Sobre" | baixo |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | título da aba usa app name | baixo |
| `Cargo.toml` | description, `[package.metadata.bundle]` | baixo |
| `build.py` | `George.app`, control do deb (`Package: george`) | médio |
| `res/msi/preprocess.py` | links ARP | baixo |
| `res/rustdesk.desktop`, `res/rustdesk-link.desktop` | nome/`x-scheme-handler/george` | baixo |
| `flutter/{linux,windows,macos,android}` ids/strings/ícones | `com.georgedesk.app`, `George` | baixo |
| `flutter/pubspec.yaml` | description, `assets/george/` | baixo |

Ícones substituídos (regenerar com o script): `res/*.png|ico|svg`, `flutter/assets/icon.*`,
`flutter/assets/logo*.png`, `flutter/windows/runner/resources/app_icon.ico`,
`flutter/macos/Runner/AppIcon.icns`, `flutter/android/app/src/main/res/mipmap-*`.

## O que NÃO foi possível trazer do upstream

- **Web client completo**: o Flutter web do upstream depende de um bridge JS "v2" que o projeto
  não publica (o diretório `flutter/web/` está no `.gitignore`; o job `build-rustdesk-web` está
  `if: False`; o `web_deps.tar.gz` público só traz codecs ogv.js). Entregamos `web-landing/`
  (marca, `?code=`/`?id=&pw=` → `george://connect`, downloads). Opções: licenciar/obter o bridge
  v2, ou restaurar o `flutter/web/v1` de `git show 41a20b50e^:flutter/web` e portar.
- **Auto-update in-place** (Windows/macOS): o updater do upstream baixa assets com nome
  `rustdesk-*` e verifica metadata assinada do upstream. No George o banner abre a página do
  release (`https://github.com/Nucleo-EBPOS/george-client/releases/tag/vX.Y.Z`, servida pela
  george-api em `/api/v1/releases/latest` no formato `{"url": "..."}`).

## Versão

Bump = `Cargo.toml` `version`, `flutter/pubspec.yaml` `version`, e `VERSION` em
`.github/workflows/flutter-build.yml` (o `george-build.yml` é regenerado). Tag `vX.Y.Z` dispara
`george-release.yml`. O checador de versão só aceita tags `vX.Y.Z` (3 números).
