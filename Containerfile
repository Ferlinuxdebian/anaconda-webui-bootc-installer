FROM quay.io/fedora/fedora-bootc:45

# Collecting your image bootc personalization
ARG CONTAINER_NAME=quay.io/fedora/fedora-bootc:45

# Installs essential Anaconda packages to generate the live ISO with the installer
RUN dnf install -qy \
    anaconda \
    anaconda-install-img-deps \
    anaconda-dracut \
    dracut-config-generic \
    dracut-network \
    net-tools \
    grub2-efi-x64-cdboot \
    plymouth \
    cockpit-ws \
    cockpit-bridge \
    anaconda-webui \
    firefox \
    cage \
    mesa-dri-drivers \
    default-fonts-core-sans \
    jq

# these are necessary build tools. if you use a separate build container then
# these tools should be installed there
RUN dnf install -qy \
    xorrisofs \
    squashfs-tools

RUN dnf clean all

RUN mkdir -p /boot/efi && cp -ra /usr/lib/efi/*/*/EFI /boot/efi

# ---

# some configuration for our ISO

RUN mkdir -p /usr/lib/image-builder/bootc

# Configured with inst.webui to launch anacondaWEBUI as the main installer
RUN cat <<EOF > /usr/lib/image-builder/bootc/iso.yaml
label: "Fedora-bootc-Installer"
grub2:
  timeout: 5
  entries:
    - name: "Install Fedora (bootc WebUI Wayland Local)"
      linux: \${kernelpath} \${root} inst.webui
      initrd: \${initrdpath}
EOF

# some configuration for anaconda

COPY <<EOT /usr/share/anaconda/interactive-defaults.ks
bootc --source-imgref registry:${CONTAINER_NAME} --target-imgref ${CONTAINER_NAME}
EOT

# ---

# these things are normally performed by `lorax` to make `anaconda` work; this is the
# bare minimum to get things to work

RUN echo "install:x:0:0:root:/root:/usr/libexec/anaconda/run-anaconda" >> /etc/passwd && \
    echo "install::14438:0:99999:7:::" >> /etc/shadow && \
    passwd -d root

RUN mv /usr/share/anaconda/list-harddrives-stub /usr/bin/list-harddrives && \
    mv /etc/yum.repos.d /etc/anaconda.repos.d && \
    ln -s /lib/systemd/system/anaconda.target /etc/systemd/system/default.target && \
    rm -v /usr/lib/systemd/system-generators/systemd-gpt-auto-generator

RUN ln -s /usr/lib/systemd/system/anaconda-shell@.service /usr/lib/systemd/system/autovt@.service

RUN mkdir -p /usr/lib/systemd/logind.conf.d
COPY <<EOT /usr/lib/systemd/logind.conf.d/anaconda-shell.conf
[Login]
ReserveVT=2
EOT

RUN mkdir "$(realpath /root)" && \
    kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version') && \
    DRACUT_NO_XATTR=1 dracut --force -v --zstd --reproducible --no-hostonly \
        --add "anaconda" \
        "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

RUN mkdir /etc/systemd/user/pipewire.service.d/
COPY <<EOT /etc/systemd/user/pipewire.service.d/allowroot.conf
[Unit]
ConditionUser=
EOT

RUN mkdir /etc/systemd/user/pipewire.socket.d/
COPY <<EOT /etc/systemd/user/pipewire.socket.d/allowroot.conf
[Unit]
ConditionUser=
EOT
