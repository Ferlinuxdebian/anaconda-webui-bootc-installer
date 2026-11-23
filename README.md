# ISO do Anaconda WebUI para imagens bootc (template)

[![Use this template](https://img.shields.io/badge/Use%20this-template-2ea44f?logo=github)](https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer/generate)
![feito com bootc](https://img.shields.io/badge/feito_com-bootc-51A2DA)
![base Fedora 45](https://img.shields.io/badge/base-Fedora_45-51A2DA?logo=fedora&logoColor=white)
![Anaconda WebUI](https://img.shields.io/badge/instalador-Anaconda_WebUI-3fb950)
![GitHub Actions](https://img.shields.io/badge/build-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)

Este repositório é um **template** que gera um **ISO de instalação** com o
**Anaconda WebUI**. O ISO instala em disco uma imagem `bootc` — por exemplo, a
sua imagem atômica criada com o template
[gnome-minimal](https://github.com/Ferlinuxdebian/gnome-minimal).

Você **não precisa entender o Containerfile nem o workflow**. O uso é:

1. criar o seu repositório a partir deste template;
2. editar **um único arquivo**, o `build.conf`;
3. fazer push. O GitHub Actions gera o ISO e o disponibiliza para download.

> **Habilite a leitura e gravação antes do primeiro build.** No GitHub, abra
> **Settings → Actions → General → Workflow permissions** e marque
> **Read and write permissions**. Sem isso, o workflow não consegue publicar o
> ISO na release.

---

## 1. Use este template

No GitHub, clique em **Use this template** (**Usar este modelo**) **→ Create a
new repository** e escolha o nome e a visibilidade.

> Para o dono deste repositório: marque **Settings → General → Template
> repository** para habilitar o botão **Use this template**.

Depois clone o **seu** repositório:

```bash
git clone https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
cd SEU-REPOSITORIO
```

---

## 2. Edite apenas o `build.conf`

O arquivo tem só estas três linhas para você alterar:

```bash
IMAGE_NAME=bootc-gnome-minimal-f45
LINK_DA_IMAGEM_PERSONALIZADA=ghcr.io/ferlinuxdebian/bootc-gnome-minimal-f45:latest
ASSINADA_COM_CONSIG=true
```

| Variável | O que colocar |
| --- | --- |
| `IMAGE_NAME` | Nome da imagem no registro do GitHub (GHCR), **sem** `ghcr.io/`, **sem** o usuário e **sem** a tag. É o nome que aparece em `ghcr.io/SEU-USUARIO/<IMAGE_NAME>:tag`. Também vira o nome do ISO: `output/<IMAGE_NAME>.iso`. Use letras minúsculas, números, ponto, hífen e sublinhado. |
| `LINK_DA_IMAGEM_PERSONALIZADA` | O link completo da imagem bootc que o instalador vai baixar e gravar. Formato `registro/repositório:tag` (ex.: `ghcr.io/joao/minha-imagem:latest`) ou com digest (`@sha256:...`). |
| `ASSINADA_COM_CONSIG` | `true` se a imagem for assinada com cosign; `false` se não for. |

> `IMAGE_NAME` é só o nome da imagem no GHCR (ex.: `minha-imagem`). O endereço
> completo, com registro, usuário e tag, vai em
> `LINK_DA_IMAGEM_PERSONALIZADA`.

### Exemplo com a sua imagem

```bash
IMAGE_NAME=minha-imagem
LINK_DA_IMAGEM_PERSONALIZADA=ghcr.io/joao/minha-imagem:latest
ASSINADA_COM_CONSIG=false
```

### Se a imagem não for assinada

Use `ASSINADA_COM_CONSIG=false`.

O padrão do template é `true` porque a imagem
`bootc-gnome-minimal-f45` é assinada. Se você trocar o link por uma imagem
**sem assinatura** e deixar `true`, a instalação vai recusar a imagem.

### Se a imagem for assinada e for outra imagem

O template já inclui a chave e a política da `bootc-gnome-minimal-f45` na
pasta `security/`. Se você usar **outra** imagem assinada, substitua estes
três arquivos pelos da sua imagem:

```text
security/policy.json
security/registries.d/ghcr.yaml
security/cosign.pub
```

O `policy.json` precisa citar o repositório da imagem (sem a tag) e apontar
para `/etc/pki/containers/bootc-gnome.pub`, que é onde o container instala a
chave.

> Se você ainda não assina a sua imagem, o caminho mais simples é
> `ASSINADA_COM_CONSIG=false`.

---

## 3. Faça push e baixe o ISO

```bash
git add build.conf
git commit -m "Configura a imagem do ISO"
git push origin main
```

A cada push na `main`, o GitHub Actions:

1. lê o `build.conf`;
2. constrói a imagem do instalador com o Anaconda WebUI;
3. gera o ISO com o `image-builder`;
4. publica o ISO na release **ISO mais recente**.

Para baixar:

1. abra a aba **Releases** do seu repositório (ou `.../releases/tag/iso-latest`);
2. baixe o arquivo `IMAGE_NAME.iso`.

Se o ISO passar de ~1,9 GiB (perto do limite de 2 GiB por arquivo do GitHub),
o workflow o divide em partes (`...iso.part-00`, `...iso.part-01` etc.) e
inclui um `LEIA-ME.txt`. Baixe todas as partes e junte na ordem:

```bash
cat minha-imagem.iso.part-* > minha-imagem.iso
```

Também é possível disparar manualmente em **Actions → Gerar ISO de instalação
→ Run workflow**.

> O ISO fica na release `iso-latest`, que é substituída a cada execução.
> Se a publicação falhar com erro de permissão, ative **Settings → Actions →
> General → Workflow permissions → Read and write permissions**.

---

## 4. Rodar localmente (opcional)

Se preferir gerar o ISO na sua máquina Fedora:

```bash
sudo dnf install -y just podman
sudo just iso
```

O ISO fica em `output/<IMAGE_NAME>.iso`.

Também funciona sem o `just`:

```bash
sudo ./scripts/build-iso.sh
```

Se o `image-builder` estiver instalado no sistema, o script o usa. Se não
estiver, ele usa automaticamente o container oficial
`ghcr.io/osbuild/image-builder-cli`.

Para testar sem gerar nada:

```bash
just check
```

---

## 5. O que tem no repositório

```text
.
├── build.conf                     # ★ o único arquivo que você edita
├── Containerfile                  # imagem do instalador (Anaconda WebUI)
├── justfile                       # atalhos: just iso, build, create-iso, check
├── scripts/
│   └── build-iso.sh               # lê o build.conf e gera o ISO
├── security/
│   ├── policy.json                # política de assinatura (cosign)
│   ├── registries.d/ghcr.yaml     # descoberta de assinaturas no GHCR
│   └── cosign.pub                 # chave pública da imagem de exemplo
├── .github/workflows/build-iso.yml # gera o ISO no GitHub Actions
├── LICENSE.md
└── README.md
```

Você só precisa mexer no `build.conf`. O restante já está pronto.

---

## 6. Como funciona (resumo)

1. O `Containerfile` monta uma imagem com o Anaconda WebUI, o cockpit e o
   Firefox.
2. Dentro dela fica um kickstart que diz ao Anaconda qual imagem `bootc`
   instalar.
3. O `image-builder` transforma essa imagem em um ISO inicializável.
4. Na instalação, o Anaconda baixa a imagem do `LINK_DA_IMAGEM_PERSONALIZADA`
   e grava no disco.

O ISO **não** contém a imagem bootc; ele baixa a imagem na hora da instalação.
Por isso a máquina que está instalando precisa de internet.

---

## 7. Problemas comuns

**O ISO não aparece na release**
Abra a execução em **Actions** e veja qual passo falhou. O passo **Validar o
build.conf** mostra qual variável está com problema. Se o erro for de
permissão ao publicar, ative **Settings → Actions → General → Workflow
permissions → Read and write permissions**.

**`ASSINADA_COM_CONSIG=true` e a instalação recusa a imagem**
A imagem não está assinada ou a política/chave em `security/` é de outra
imagem. Use `false` ou substitua os três arquivos de `security/`.

**Não consigo baixar a imagem na instalação**
A imagem precisa ser pública ou o instalador precisa de login. Torne o pacote
público no GHCR/quay.io ou use uma imagem pública.

**O link da imagem está errado**
Use sempre o registro completo e uma tag:

```text
ghcr.io/usuario/imagem:latest
quay.io/usuario/imagem:latest
```

**O build demora muito**
A primeira execução baixa o Anaconda e as camadas da imagem base. As
execuções seguintes tendem a ser mais rápidas, mas cada uma começa de um
runner limpo.

**Quero o instalador antigo (Anaconda GTK)**
Use o repositório
[anaconda-bootc-isos](https://github.com/Ferlinuxdebian/anaconda-bootc-isos).

---

## Licença

CC BY 4.0 — veja `LICENSE.md`.
