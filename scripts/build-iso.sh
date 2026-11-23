#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Gera o ISO a partir do build.conf.
#
# Uso:
#   sudo just iso          # constrói o instalador e gera o ISO
#   sudo just build        # só a imagem do instalador
#   sudo just create-iso   # só o ISO (reaproveita o instalador)
#   just check             # valida o build.conf (não precisa de root)
#
# Saída: output/<IMAGE_NAME>.iso
# ----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output"

MODE="all"

usage() {
    cat <<'EOF'
Uso: scripts/build-iso.sh [opção]

  (sem opção)        Constrói o instalador e gera o ISO.
  --installer-only   Constrói apenas a imagem de container do instalador.
  --iso-only         Gera apenas o ISO, usando o instalador já construído.
  --check            Valida o build.conf e mostra a configuração.
  -h, --help         Mostra esta ajuda.
EOF
}

erro() {
    echo "ERRO: $*" >&2
    exit 1
}

trim() {
    local valor="$1"
    valor="${valor#"${valor%%[![:space:]]*}"}"
    valor="${valor%"${valor##*[![:space:]]}"}"
    printf '%s' "$valor"
}

for arg in "$@"; do
    case "$arg" in
        --check)                      MODE="check" ;;
        --installer-only|--build)     MODE="installer" ;;
        --iso-only|--iso|--create-iso) MODE="iso" ;;
        -h|--help)                    usage; exit 0 ;;
        *)
            echo "ERRO: opção desconhecida: $arg" >&2
            echo >&2
            usage >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Localiza e lê o arquivo de configuração
# ---------------------------------------------------------------------------
CONF=""
for candidato in "$ROOT_DIR/build.conf" "$ROOT_DIR/build.env" "$ROOT_DIR/build.yaml"; do
    if [[ -f "$candidato" ]]; then
        CONF="$candidato"
        break
    fi
done
[[ -n "$CONF" ]] || erro "arquivo de configuração não encontrado. Crie build.conf na raiz do repositório."
CONF_NAME="$(basename "$CONF")"

IMAGE_NAME=""
LINK=""
ASSINADA=""

ler_config() {
    local raw linha chave valor numero=0

    while IFS= read -r raw || [[ -n "$raw" ]]; do
        numero=$((numero + 1))

        linha="${raw%$'\r'}"
        [[ "$linha" =~ ^[[:space:]]*# ]] && continue
        [[ "$linha" =~ ^[[:space:]]*$ ]] && continue

        linha="${linha%%#*}"
        linha="$(trim "$linha")"
        [[ -z "$linha" ]] && continue

        # Aceita CHAVE=valor (formato do template) e CHAVE: valor.
        if [[ "$linha" == *=* ]]; then
            chave="$(trim "${linha%%=*}")"
            valor="$(trim "${linha#*=}")"
        elif [[ "$linha" == *:* ]]; then
            chave="$(trim "${linha%%:*}")"
            valor="$(trim "${linha#*:}")"
        else
            erro "$CONF_NAME, linha $numero: esperava CHAVE=valor (encontrado: '$linha')."
        fi

        # Remove aspas, se houver.
        if [[ "$valor" == \"*\" && "$valor" == *\" ]]; then
            valor="${valor:1:${#valor}-2}"
        elif [[ "$valor" == \'*\' && "$valor" == *\' ]]; then
            valor="${valor:1:${#valor}-2}"
        fi

        case "$chave" in
            IMAGE_NAME)                   IMAGE_NAME="$valor" ;;
            LINK_DA_IMAGEM_PERSONALIZADA) LINK="$valor" ;;
            ASSINADA_COM_CONSIG)          ASSINADA="${valor,,}" ;;
            *)
                erro "$CONF_NAME, linha $numero: chave desconhecida '$chave'. Use IMAGE_NAME, LINK_DA_IMAGEM_PERSONALIZADA e ASSINADA_COM_CONSIG."
                ;;
        esac
    done < "$CONF"
}

validar() {
    ler_config

    [[ -n "$IMAGE_NAME" ]] || erro "defina IMAGE_NAME em $(basename "$CONF")."
    if [[ ! "$IMAGE_NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        erro "IMAGE_NAME inválido: '$IMAGE_NAME'. Use letras minúsculas, números, ponto, hífen e sublinhado."
    fi

    [[ -n "$LINK" ]] || erro "defina LINK_DA_IMAGEM_PERSONALIZADA em $(basename "$CONF")."
    [[ "$LINK" != *[[:space:]]* ]] || erro "o link da imagem não pode conter espaços."
    [[ "$LINK" == */* ]] || erro "use o link completo, com registro e repositório (ex.: ghcr.io/usuario/imagem:latest)."
    if [[ ! "$LINK" =~ @sha256:[a-f0-9]{64}$ && ! "$LINK" =~ :[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
        erro "o link da imagem precisa terminar com uma tag (:latest) ou um digest (@sha256:...)."
    fi

    case "$ASSINADA" in
        true|false) ;;
        *) erro "ASSINADA_COM_CONSIG deve ser true ou false (valor: '$ASSINADA')." ;;
    esac
}

exigir_root() {
    [[ "$(id -u)" -eq 0 ]] || erro "execute com root/sudo. Exemplo: sudo just iso"
}

exigir_podman() {
    command -v podman >/dev/null 2>&1 || \
        erro "podman não encontrado. Instale com: sudo dnf install -y podman"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
INSTALLER_IMAGE=""

construir_instalador() {
    exigir_podman
    INSTALLER_IMAGE="localhost/bootc-iso-${IMAGE_NAME}:latest"

    echo "→ Construindo a imagem do instalador: $INSTALLER_IMAGE"
    echo "   imagem a instalar: $LINK"
    echo "   exige assinatura:  $ASSINADA"
    echo

    podman build \
        --security-opt label=disable \
        -t "$INSTALLER_IMAGE" \
        --build-arg "CONTAINER_NAME=$LINK" \
        --build-arg "ENFORCE_SIGPOLICY=$ASSINADA" \
        -f "$ROOT_DIR/Containerfile" \
        "$ROOT_DIR"
}

gerar_iso() {
    [[ -n "$INSTALLER_IMAGE" ]] || INSTALLER_IMAGE="localhost/bootc-iso-${IMAGE_NAME}:latest"
    mkdir -p "$OUTPUT_DIR"

    echo
    echo "→ Gerando o ISO a partir de $INSTALLER_IMAGE"
    echo

    if command -v image-builder >/dev/null 2>&1; then
        image-builder build \
            --bootc-ref "$INSTALLER_IMAGE" \
            --bootc-default-fs ext4 \
            --output-dir "$OUTPUT_DIR" \
            --output-name "$IMAGE_NAME" \
            bootc-generic-iso || erro "falha ao gerar o ISO."
    else
        echo "image-builder não está instalado; usando o container oficial."
        exigir_podman
        podman run --privileged --rm --pull=newer \
            --security-opt label=disable \
            -v /var/lib/containers/storage:/var/lib/containers/storage \
            -v "$OUTPUT_DIR:/output" \
            ghcr.io/osbuild/image-builder-cli:latest \
            build \
            --bootc-ref "$INSTALLER_IMAGE" \
            --bootc-default-fs ext4 \
            --output-dir /output \
            --output-name "$IMAGE_NAME" \
            bootc-generic-iso || erro "falha ao gerar o ISO."
    fi

    local iso
    iso="$(find "$OUTPUT_DIR" -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
        | sort -n | tail -n1 | cut -d' ' -f2- || true)"
    [[ -n "$iso" && -f "$iso" ]] || erro "o build terminou, mas nenhum .iso foi encontrado em $OUTPUT_DIR."

    local destino="$OUTPUT_DIR/$IMAGE_NAME.iso"
    if [[ "$iso" != "$destino" ]]; then
        mv -f "$iso" "$destino"
    fi

    if [[ -n "${SUDO_USER:-}" ]] && id -u "$SUDO_USER" >/dev/null 2>&1; then
        chown -R "$SUDO_USER:$(id -gn "$SUDO_USER")" "$OUTPUT_DIR" 2>/dev/null || true
    fi

    echo
    echo "ISO gerado: $destino"
    echo "Imagem instalada por ele: $LINK"
}

# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------
validar

if [[ "$MODE" == "check" ]]; then
    echo "$CONF_NAME válido:"
    echo "  IMAGE_NAME=$IMAGE_NAME"
    echo "  LINK_DA_IMAGEM_PERSONALIZADA=$LINK"
    echo "  ASSINADA_COM_CONSIG=$ASSINADA"
    echo "  saída: output/$IMAGE_NAME.iso"
    exit 0
fi

exigir_root

case "$MODE" in
    installer)
        construir_instalador
        echo
        echo "Imagem do instalador pronta: $INSTALLER_IMAGE"
        echo "Para gerar o ISO: sudo just create-iso"
        ;;
    iso)
        gerar_iso
        ;;
    all)
        construir_instalador
        gerar_iso
        ;;
esac
