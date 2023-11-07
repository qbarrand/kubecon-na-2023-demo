FROM ubuntu:22.04 as builder
ARG KERNEL_VERSION=''
ARG I915_BRANCH=backport/main
RUN apt-get update && apt-get install --no-install-recommends -y bc \
    ca-certificates \
    coreutils \
    binutils \
    bison \
    flex \
    libelf-dev \
    gnupg \
    git \
    make \
    bc \
    gcc \
    patch \
    m4 \
    tar \
    kmod \
    gawk \
    linux-headers-${KERNEL_VERSION} \
    linux-modules-${KERNEL_VERSION}
WORKDIR /usr/src

# i915
RUN git clone -b ${I915_BRANCH} --depth 1 https://github.com/intel-gpu/intel-gpu-i915-backports.git
WORKDIR /usr/src/intel-gpu-i915-backports
RUN make defconfig-i915 && make -j8 && make modules_install

WORKDIR /usr/src

# FW
RUN git clone https://github.com/intel-gpu/intel-gpu-firmware.git && \
      cd intel-gpu-firmware/ && rm -rf .git && cd firmware && \
      rm -f adlp* bxt* cml* cnl* ehl* glk* icl* kbl* mtl* rkl* skl* tgl*

# copy i915 and its dependencies to one place for easy COPY later and strip debug symbols from modules
ARG MODULES="video sysimgblt sysfillrect syscopyarea fb_sys_fops i2c-algo-bit drm rc-core cec drm_kms_helper compat i915 intel_vsec"
RUN for file in $(for mod in $MODULES; do find /lib/modules/${KERNEL_VERSION}/ -name $mod.ko; done); do \
    dname=$(dirname /opt$file); mkdir -p $dname; cp $file /opt$file; strip --strip-debug /opt$file; done

FROM ubuntu:22.04 as install

RUN apt-get update && apt-get install --no-install-recommends -y kmod && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/lib/modules/$KERNEL_VERSION/ /opt/lib/modules/$KERNEL_VERSION/
RUN mkdir -p /intel-dgpu-firmware/i915
COPY --from=builder /usr/src/intel-gpu-firmware/firmware/ /intel-dgpu-firmware/i915/

RUN depmod -b /opt
