#!/usr/bin/env python3
"""GEORGE: gera .github/workflows/george-build.yml a partir do flutter-build.yml upstream.
Mantém os passos de build upstream (testados) e aplica só as mudanças do George.
Rode após cada sync com o upstream: python3 scripts/george-gen-workflow.py
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
src = (ROOT / '.github/workflows/flutter-build.yml').read_text()

head, _, body = src.partition('\njobs:\n')
# ---- jobs por bloco de texto ----
parts = re.split(r'(?m)^(?=  [A-Za-z0-9_-]+:\n)', body)
jobs = {}
for p in parts:
    m = re.match(r'  ([A-Za-z0-9_-]+):\n', p)
    if m:
        jobs[m.group(1)] = p.rstrip('\n') + '\n'

def need(name):
    if name not in jobs:
        sys.exit(f'job upstream não encontrado: {name}')
    return jobs[name]

def drop_steps(text, names):
    steps = re.split(r'(?m)^(?=      - name: )', text)
    out = []
    for s in steps:
        m = re.match(r'      - name: (.*)\n', s)
        if m and m.group(1).strip() in names:
            continue
        out.append(s)
    return ''.join(out)

def must_replace(text, old, new, count=1):
    if text.count(old) != count:
        sys.exit(f'anchor ({text.count(old)}x): {old[:80]!r}')
    return text.replace(old, new)

def drop_matrix_entry(text, marker):
    # remove o bloco "- {" ... "}" (multilinha ou de uma linha) que contém `marker`
    i = text.index(marker)
    ls = text.rfind('\n', 0, i) + 1
    le = text.index('\n', i) + 1
    line = text[ls:le]
    if line.lstrip().startswith('- {') and line.rstrip().endswith('}'):
        return text[:ls] + text[le:]
    start = text.rfind('          - {', 0, i)
    end = text.index('            }\n', i) + len('            }\n')
    return text[:start] + text[end:]

# ---- header ----
head = must_replace(head, 'name: Build the flutter version of the RustDesk',
    '# GEORGE: gerado por scripts/george-gen-workflow.py a partir de flutter-build.yml. Não edite à mão.\nname: George build (Windows, macOS, Linux, web)')
head = must_replace(head, '''on:
  workflow_call:
    inputs:
      upload-artifact:
        type: boolean
        default: true
      upload-tag:
        type: string
        default: "nightly"
      publish-update-metadata:
        type: boolean
        default: false
''', '''on:
  workflow_call:
    inputs:
      upload-artifact:
        type: boolean
        default: true
      upload-tag:
        type: string
        default: "nightly"
      publish-update-metadata:
        type: boolean
        default: false
  workflow_dispatch:
    inputs:
      upload-artifact:
        type: boolean
        default: true
        description: "Gerar e subir artefatos"
      upload-tag:
        type: string
        default: "nightly"
        description: "Tag do release (vX.Y.Z publica release; outro valor só gera artefatos)"
      publish-update-metadata:
        type: boolean
        default: false
''')
head = must_replace(head, '''  TAG_NAME: "${{ inputs.upload-tag }}"
''', '''  TAG_NAME: "${{ inputs.upload-tag }}"
  # GEORGE: servidor/chave de produção embutidos em tempo de build (option_env! em src/george/mod.rs).
  RENDEZVOUS_SERVER: "georgedesk.com"
  RELAY_SERVER: "georgedesk.com:21117"
  API_SERVER: "https://georgedesk.com"
  RS_PUB_KEY: "GuScaZGLwh+xwwBVafvVItAJsbjNf+zT7tBEUWCIwqo="
  GEORGE_APP_NAME: "George"
''')

# ---- generate-bridge / topmost ----
# GEORGE: cópia do bridge.yml só com o bridge padrão (Flutter 3.22.3). A entrada 3.44 serve apenas
# ao Windows arm64, que o George não compila; uma falha nela derrubava todo o `needs`.
bsrc = (ROOT / '.github/workflows/bridge.yml').read_text()
bsrc = drop_matrix_entry(bsrc, 'artifact-name: "bridge-artifact-flutter-3.44"')
bsrc = '# GEORGE: gerado por scripts/george-gen-workflow.py a partir de bridge.yml. Não edite à mão.\n' + bsrc
(ROOT / '.github/workflows/george-bridge.yml').write_text(bsrc)
bridge = must_replace(need('generate-bridge'), '    needs: [validate-update-metadata-keys]\n', '')
bridge = must_replace(bridge, 'uses: ./.github/workflows/bridge.yml', 'uses: ./.github/workflows/george-bridge.yml')
topmost = must_replace(need('build-RustDeskTempTopMostWindow'), '    needs: [validate-update-metadata-keys]\n', '')
topmost = drop_matrix_entry(topmost, 'target: windows-11-arm')

# ---- windows ----
win = need('build-for-windows-flutter')
win = drop_matrix_entry(win, 'target: aarch64-pc-windows-msvc')
win = must_replace(win, '  build-for-windows-flutter:\n    name: ${{ matrix.job.target }}\n',
                   '  build-for-windows-flutter:\n    name: George Windows ${{ matrix.job.arch }}\n')
win = drop_steps(win, {'Upload unsigned', 'Sign rustdesk files', 'Build pre-built MSI template',
                       'Upload unsigned msi template', 'Sign rustdesk self-extracted file',
                       'Upload signed Windows Flutter EXE', 'Upload signed Windows Flutter MSI',
                       'Publish Release'})
win = must_replace(win, '''          pushd ./res/msi
          python preprocess.py --arp -d ../../rustdesk
''', '''          # GEORGE: o MSI procura <app-name>.exe na dist; instala como George.exe
          Copy-Item -Recurse ./rustdesk ./george-dist
          Move-Item ./george-dist/rustdesk.exe ./george-dist/George.exe
          pushd ./res/msi
          python preprocess.py --arp -d ../../george-dist --app-name ${{ env.GEORGE_APP_NAME }}
''')
win = must_replace(win, '''          mv $msi.FullName ../../SignOutput/rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.msi
          sha256sum ../../SignOutput/rustdesk-*.msi
''', '''          mv $msi.FullName ../../SignOutput/George-${{ env.VERSION }}-windows-${{ matrix.job.arch }}.msi
          sha256sum ../../SignOutput/George-*.msi
''')
win = must_replace(win, '''          mv ./target/release/rustdesk-portable-packer.exe ./SignOutput/rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.exe
''', '''          mv ./target/release/rustdesk-portable-packer.exe ./SignOutput/George-${{ env.VERSION }}-windows-${{ matrix.job.arch }}.exe
''')
win = win.rstrip('\n') + '''

      - name: Upload George Windows artifacts
        if: env.UPLOAD_ARTIFACT == 'true'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: George-${{ env.VERSION }}-windows-${{ matrix.job.arch }}
          path: |
            ./SignOutput/George-*.exe
            ./SignOutput/George-*.msi
          if-no-files-found: error
'''

# ---- macOS ----
mac = need('build-for-macOS')
mac = must_replace(mac, '  build-for-macOS:\n    name: ${{ matrix.job.target }}\n',
                   '  build-for-macOS:\n    name: George macOS ${{ matrix.job.arch }}\n')
mac = drop_steps(mac, {'Test verified updates', 'Upload signed macOS DMG', 'Publish DMG package',
                       'Upload unsigned macOS app', 'Rename rustdesk'})
mac = mac.replace('RustDesk.app', 'George.app').replace('Release/George.app/Contents/MacOS/RustDesk', 'Release/George.app/Contents/MacOS/George')
mac = mac.replace('rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.dmg', 'George-${{ env.VERSION }}-macos-${{ matrix.job.arch }}.dmg')
mac = mac.replace('rustdesk-${{ env.VERSION }}.dmg', 'George-${{ env.VERSION }}-macos-${{ matrix.job.arch }}.dmg')
mac = mac.rstrip('\n') + '''

      - name: Upload George macOS DMG
        if: env.UPLOAD_ARTIFACT == 'true'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: George-${{ env.VERSION }}-macos-${{ matrix.job.arch }}
          path: George-${{ env.VERSION }}-macos-${{ matrix.job.arch }}.dmg
          if-no-files-found: error
'''

# ---- linux ----
lin = need('build-rustdesk-linux')
lin = drop_matrix_entry(lin, 'target: aarch64-unknown-linux-gnu')
lin = must_replace(lin, '  build-rustdesk-linux:\n    needs: [generate-bridge]\n    name: build rustdesk linux ${{ matrix.job.target }}\n',
                   '  build-rustdesk-linux:\n    needs: [generate-bridge]\n    name: George Linux ${{ matrix.job.arch }}\n')
# corta rpm/arch do script de build (só deb)
i = lin.index('            # rpm package\n')
j = lin.index('      - name: Publish debian/rpm package')
lin = lin[:i] + '\n' + lin[j:]
lin = drop_steps(lin, {'Publish debian/rpm package', 'Patch archlinux PKGBUILD', 'Build archlinux package',
                       'Publish archlinux package'})
lin = lin.rstrip('\n') + '''

      - name: Upload George Linux deb
        if: env.UPLOAD_ARTIFACT == 'true'
        run: cp rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.deb George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}.deb
      - name: Upload George Linux deb artifact
        if: env.UPLOAD_ARTIFACT == 'true'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}-deb
          path: George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}.deb
          if-no-files-found: error
'''

# ---- appimage ----
app = need('build-appimage')
app = drop_matrix_entry(app, 'target: aarch64-unknown-linux-gnu')
app = must_replace(app, '  build-appimage:\n    name: Build appimage ${{ matrix.job.target }}\n',
                   '  build-appimage:\n    name: George AppImage ${{ matrix.job.arch }}\n')
app = drop_steps(app, {'Publish appimage package'})
app = app.rstrip('\n') + '''

      - name: Rename and upload George AppImage
        shell: bash
        run: |
          # o nome gerado pelo appimage-builder varia (app_info.name/versão/arch); pega o único .AppImage
          f=$(find appimage -maxdepth 3 -name '*.AppImage' -type f | head -1)
          if [ -z "$f" ]; then echo "::error::nenhum .AppImage gerado"; ls -laR appimage | head -80; exit 1; fi
          echo "AppImage gerado: $f"
          sudo mv "$f" George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}.AppImage
          sudo chown "$(id -u):$(id -g)" George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}.AppImage
      - name: Upload George AppImage artifact
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}-appimage
          path: George-${{ env.VERSION }}-linux-${{ matrix.job.arch }}.AppImage
          if-no-files-found: error
'''

web = '''  build-george-web:
    name: George web (landing /web)
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout source code
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - name: Package web landing
        shell: bash
        run: |
          # GEORGE: o web client completo depende do bridge JS v2 que o upstream não publica
          # (ver GEORGE-UPSTREAM.md). Publicamos a página /web com marca, que trata ?code= e
          # ?id=&pw= (abre george://connect e oferece os downloads).
          sed -i "s/__GEORGE_VERSION__/${{ env.VERSION }}/g" web-landing/index.html
          (cd web-landing && zip -r ../George-${{ env.VERSION }}-web.zip .)
          sha256sum George-${{ env.VERSION }}-web.zip
      - name: Upload George web artifact
        if: env.UPLOAD_ARTIFACT == 'true'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: George-${{ env.VERSION }}-web
          path: George-${{ env.VERSION }}-web.zip
          if-no-files-found: error
'''

publish = '''  publish-george-release:
    name: Publish GitHub Release
    if: ${{ inputs.upload-artifact && startsWith(inputs.upload-tag, 'v') }}
    needs: [build-for-windows-flutter, build-for-macOS, build-rustdesk-linux, build-appimage, build-george-web]
    runs-on: ubuntu-22.04
    # Sem `permissions:` aqui: num workflow reutilizável o job não pode pedir mais do que o
    # chamador concede (pedir `contents: write` sob um caller read-only = startup_failure).
    # Quem concede `contents: write` é o george-release.yml.
    steps:
      - name: Download all George artifacts
        uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
        with:
          pattern: George-*
          path: release
          merge-multiple: true
      - name: Build manifest
        shell: bash
        run: |
          cd release
          ls -la
          python3 - <<'EOF2'
          import json, os, hashlib
          ver = os.environ['VERSION']; tag = os.environ['TAG_NAME']
          repo = os.environ['GITHUB_REPOSITORY']
          assets = []
          for f in sorted(os.listdir('.')):
              if not f.startswith('George-') or f.endswith('.json'): continue
              h = hashlib.sha256(open(f,'rb').read()).hexdigest()
              plat = 'windows' if 'windows' in f else 'macos' if 'macos' in f else 'linux' if 'linux' in f else 'web'
              assets.append({'name': f, 'platform': plat, 'sha256': h, 'size': os.path.getsize(f),
                             'url': f'https://github.com/{repo}/releases/download/{tag}/{f}'})
          json.dump({'version': ver, 'tag': tag,
                     'url': f'https://github.com/{repo}/releases/tag/{tag}', 'assets': assets},
                    open(f'George-{ver}-manifest.json','w'), indent=2)
          EOF2
          cat George-*-manifest.json
      - name: Publish release
        uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844 # v1
        with:
          tag_name: ${{ env.TAG_NAME }}
          name: George ${{ env.VERSION }}
          prerelease: ${{ contains(env.TAG_NAME, '-') }}
          files: |
            release/George-*
'''

out = head + '\njobs:\n' + '\n'.join([bridge, topmost, win, mac, lin, app, web, publish])
(ROOT / '.github/workflows/george-build.yml').write_text(out)
print('george-build.yml gerado:', len(out.splitlines()), 'linhas')
