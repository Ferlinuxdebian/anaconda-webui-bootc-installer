# Define the default recipe (runs by just typing 'just')
default:
    just --list

# ENFORCE_SIGPOLICY (opcional): "true" exige assinatura de contêiner na
# instalação; "false" (padrão) aceita imagens assinadas e não assinadas.
#
# Build the container image with your custom bootc image (ENFORCE_SIGPOLICY opcional).
build CONTAINER_NAME="quay.io/fedora/fedora-bootc:latest" ENFORCE_SIGPOLICY="false":
    @[ "$(id -u)" -eq 0 ] || { echo "Error: Use root/sudo" 1>&2; exit 1; }
    @case "{{ENFORCE_SIGPOLICY}}" in true|false) ;; *) echo "Erro: ENFORCE_SIGPOLICY deve ser true ou false" 1>&2; exit 1;; esac
    @podman build -t localhost/bootc-generic-iso-f45:latest \
        --build-arg CONTAINER_NAME={{CONTAINER_NAME}} \
        --build-arg ENFORCE_SIGPOLICY={{ENFORCE_SIGPOLICY}} -f Containerfile

# Create the ISO with your custom bootc image
create-iso:
    @[ "$(id -u)" -eq 0 ] || { echo "Error: Use root/sudo" 1>&2; exit 1; }
    @image-builder build \
        --bootc-ref localhost/bootc-generic-iso-f45:latest \
        --bootc-default-fs ext4 \
        bootc-generic-iso