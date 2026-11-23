# Lista os comandos disponíveis (executa ao digitar 'just').
default:
    @just --list

# Constrói o instalador e gera o ISO usando o build.conf.
iso:
    @scripts/build-iso.sh

# Só constrói a imagem de container do instalador (sem gerar o ISO).
build:
    @scripts/build-iso.sh --installer-only

# Só gera o ISO, reaproveitando o instalador já construído.
create-iso:
    @scripts/build-iso.sh --iso-only

# Valida o build.conf (não precisa de root).
check:
    @scripts/build-iso.sh --check
