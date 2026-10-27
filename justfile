# Define the default recipe (runs by just typing 'just')
default:
    just --list

# Build the container image with your custom bootc image
build CONTAINER_NAME="quay.io/fedora/fedora-bootc:latest":
    @[ "$(id -u)" -eq 0 ] || { echo "Error: Use root/sudo" 1>&2; exit 1; }
    @podman build -t localhost/bootc-generic-iso-f45:latest \
        --build-arg CONTAINER_NAME={{CONTAINER_NAME}} -f Containerfile

# Create the ISO with your custom bootc image
create-iso:
    @[ "$(id -u)" -eq 0 ] || { echo "Error: Use root/sudo" 1>&2; exit 1; }
    @image-builder build \
        --bootc-ref localhost/bootc-generic-iso-f45:latest \
        --bootc-default-fs ext4 \
        bootc-generic-iso