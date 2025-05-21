#! /bin/bash

sudo pacman -Syu --needed git gcc make flex bison bc cpio qemu-full libslirp ninja dtc opensbi \
    riscv64-linux-gnu-gcc riscv64-linux-gnu-binutils riscv64-linux-gnu-glibc \
    python python-pip autoconf automake pkg-config glib2 gawk libmpc libmpfr libgmp zlib expat















































# ==============================================
# 整合

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# pre step
detect_env() {

	# alpine
	if [ -f /etc/alpine-release ]; then
		OS="alpine"
	# arch
	elif [ -f /etc/arch-release ]; then
		OS="arch"
	# ubuntu and debian
	elif [ -f /etc/debian_version ] || grep -q 'Ubuntu' /etc/os-release 2>/dev/null; then
		OS="ubuntu"

	else
		echo -e "${RED} error: we only support alpine、arch and ubuntu $(NC)"
		exit 1
	fi

	ARCH=$(uname -m) # check again
	case "$ARCH" in
		x86_64)  HOST_ARCH="x86_64" ;;
		aarch64) HOST_ARCH="arm64"   ;;
		armv7l)  HOST_ARCH="armhf"   ;;
		riscv64) HOST_ARCH="riscv64" ;;
        *)       echo -e "${RED}error：unsupported arch $ARCH${NC}"; exit 1 ;;
    esac

    echo -e "${GREEN}detected env：${YELLOW}OS=$OS, ARCH=$HOST_ARCH${NC}"
}



# basic tools installations
install_deps() {
	case "$OS" in
		"alpine")
			sudo apk update; sudo apk add --no-cache git bash gcc g++ make autoconf automake bison flex textinfo gawk gmp-dev mpfr-dev mpc1-dev libtool patchutils bc zlib-dev expart-dev ninja glibc-dev pixman-dev python3 openssl-dev slirpp-dev linux-headers libaio-dev
		;;
		"arch")
			sudo pacman -Syyuu; sudo pacman -Sy --needed --noconfirm git base-devel cmake autoconf automake bison flex textinfo gawk libmpc mpfr gmp libtool patchutils bc zlib expat ninja glib2 pixman python openssl libslirp dtc ncuses qemu-full
		;;

		"ubuntu") #NOTE: NEED TEST;I dont use it
	    		apt-get update && apt-get install -y \
			    	git build-essential cmake autoconf automake \
		 		bison flex texinfo gawk libgmp-dev \
				libmpfr-dev libmpc-dev libtool patchutils \
				bc zlib1g-dev libexpat1-dev ninja-build \
				libglib2.0-dev libpixman-1-dev \
				python3 libssl-dev libslirp-dev \
				libaio-dev libncurses-dev qemu-system
	    ;;
	esac
}



# Risc-V GNU toolchain installation
tool_chain() {
	local target="$1"
	echo -e "${GREEN}install $target toolchains...${NC}"

	case "$OS" in
		"alpine")
			case "$target" in
				"riscv64"
			esac

	esac
}



# build qemu-riscv


# build linux kernel


# riscv rfs


# kvm guest env and boot it by qemu


