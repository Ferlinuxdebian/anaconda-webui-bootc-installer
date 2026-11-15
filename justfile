# Define a receita padrão (executa ao digitar 'just')
default:
    just --list

# ENFORCE_SIGPOLICY (opcional): "true" exige assinatura de contêiner na
# instalação; "false" (padrão) aceita imagens assinadas e não assinadas.
#
# Constrói a imagem de container com a sua imagem bootc personalizada (ENFORCE_SIGPOLICY opcional).
build CONTAINER_NAME="quay.io/fedora/fedora-bootc:latest" ENFORCE_SIGPOLICY="false":
    @[ "$(id -u)" -eq 0 ] || { echo "Erro: use root/sudo" 1>&2; exit 1; }
    @case "{{ENFORCE_SIGPOLICY}}" in true|false) ;; *) echo "Erro: ENFORCE_SIGPOLICY deve ser true ou false" 1>&2; exit 1;; esac
    @podman build -t localhost/bootc-generic-iso-f45:latest \
        --build-arg CONTAINER_NAME={{CONTAINER_NAME}} \
        --build-arg ENFORCE_SIGPOLICY={{ENFORCE_SIGPOLICY}} -f Containerfile

# Cria o ISO com a sua imagem bootc personalizada
create-iso:
    @[ "$(id -u)" -eq 0 ] || { echo "Erro: use root/sudo" 1>&2; exit 1; }
    @image-builder build \
        --bootc-ref localhost/bootc-generic-iso-f45:latest \
        --bootc-default-fs ext4 \
        bootc-generic-iso
