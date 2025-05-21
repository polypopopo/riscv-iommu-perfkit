BUILD.md



> 预测的主要工作流程是：依赖工具-搭建rootfs-配置-内核编译时选择相关选项-perf-脚本处理结果信息
>
> 还是预测啊
>
> 有一些潜在问题：
>
> roofs构建时的依赖库可能不会很完整
>
> 性能事件在每个版本不一样
>
> 交叉编译perf可能有一些隐藏依赖
>
> 功能验证项可能有缺失
>
> 头文件问题



### 准备环境

```shell
# 先建立依赖
# 我的设备是ubuntu22.04， thinkpad x230t,较老的硬件
# 不敢保证是完善的。。。有一些头文件可能需要自己部署，视具体情况而定
sudo apt update && sudo apt install -y \
    fastfetch neofetch neovim \
    git \
    gcc g++ \
    tmux zellij screen \
    python3-venv python3-pip python3 \
    ninja-build \
    autoconf automake autotools-dev curl \
    libmpc-dev libmpfr-dev libgmp-dev \
    gawk build-essential bison flex texinfo gperf libtool patchutils bc \
    zlib1g-dev libexpat-dev libglib2.0-dev \
    libfdt-dev libpixman-1-dev libncurses-dev libssl-dev \
    libslirp-dev \
    gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu \
    meson \
    libaio-dev liburing-dev libbrlapi-dev libcap-dev \
    libcurl4-gnutls-dev libgtk-3-dev libiscsi-dev libnfs-dev libnuma-dev \
    libsdl2-dev libseccomp-dev libspice-server-dev libusb-1.0-0-dev \
    libusbredirparser-dev libvdeplug-dev libvirglrenderer-dev libzstd-dev \
    libpmem-dev libdaxctl-dev \
    e2fsprogs squashfs-tools parted dosfstools \
    flex bison libelf-dev libdw-dev libunwind-dev \
    libslang2-dev libiberty-dev \
    device-tree-compiler debootstrap qemu-user-static \
    qemu-system-riscv64 crossbuild-essential-riscv64    

git clone https://github.com/OSchengdu/riscv-iommu-perfkit.git ~/rip # 没什么用好像，起一个规定工作目录的作用哈哈哈？

export WORKSPACE=~/rip
export ROOTFS=$WORKSPACE/rootfs
export LINUX=$WORKSPACE/linux
export QEMU=$WORKSPACE/qemu
export SYSROOT=$ROOTFS/temp-rootfs
```

### debootstrap构建最小ubuntu-riscv rootfs

```bash
# 最小系统搭建和配置
sudo debootstrap --arch=riscv64 --foreign jammy $ROOTFS http://ports.ubuntu.com/ubuntu-ports
# HACK：存疑，还没到这一步
sudo cp /usr/bin/qemu-riscv64-static $ROOTFS/usr/bin/
sudo chroot $ROOTFS /debootstrap/debootstrap --second-stage
# 配置基础环境
sudo chroot $ROOTFS /bin/bash <<EOF
apt update && apt install -y sudo ssh net-tools ethtool \
     linux-tools-common linux-tools-generic \
     libelf-dev libdw-dev zlib1g-dev
echo "root:riscv" | chpasswd
exit
EOF
# img
dd if=/dev/zero of=$ROOTFS/ubuntu-riscv.img bs=1G count=4
mkfs.ext4 $ROOTFS/ubuntu-riscv.img
sudo mkdir -p /mnt/riscv-root
sudo mount -o loop $ROOTFS/ubuntu-riscv.img /mnt/riscv-root
sudo cp -rp $ROOTFS/* /mnt/riscv-root/
sudo umount /mnt/riscv-root
```

### 内核编译

```shell
export LINUX=$WORKSPACE/linux
git clone --depth=1 -b riscv_iommu_v7 https://github.com/tjeznach/linux $LINUX
cd $LINUX

# 应用 HPM/Nested 补丁
wget https://lore.kernel.org/all/20240614142156.29420-1-zong.li@sifive.com/mbox -O hpm-patches.mbox
git am hpm-patches.mbox
```



### perf交叉编译

```
```



### 测试和测试框架
