#---- 基础 ----
FROM almalinux:9 AS base
ARG USER=developer
ARG UID=1000
ARG GID=1000

# 最小系统依赖
RUN dnf -y update && \
    dnf -y install --setopt=install_weak_deps=False \
        java-17-openjdk-devel git unzip which sudo nano \
        # Chrome 依赖
        atk cups-libs gtk3 libXcomposite libXcursor libXdamage \
        libXrandr mesa-libgbm pango alsa-lib && \
    dnf clean all

# 创建用户
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -u ${UID} -g ${GID} -G wheel -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#---- Android SDK（latest） ----
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools
USER root
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/cmd.zip && \
    unzip -q /tmp/cmd.zip -d /tmp && \
    mv /tmp/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm /tmp/cmd.zip && \
    chown -R ${USER}:${USER} ${ANDROID_SDK_ROOT}
USER ${USER}
# 默认最新稳定平台与 build-tools
RUN set -e && \
    yes | sdkmanager --licenses && \
    API=$(sdkmanager --list 2>/dev/null | \
          sed -n '/Available packages:/,$p' | \
          grep -oE 'platforms;android-[0-9]+$' | \
          grep -oE '[0-9]+$' | sort -n | tail -n1) && \
    BUILD_TOOLS=$(sdkmanager --list 2>/dev/null | \
                  sed -n '/Available packages:/,$p' | \
                  grep -oE 'build-tools;[0-9]+\.[0-9]+\.[0-9]+' | \
                  grep -oE '[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1) && \
    [ -n "$API" ] && echo "Latest API  = $API"   || echo "Warning: no API found" && \
    [ -n "$BUILD_TOOLS" ] && echo "Latest BT = $BUILD_TOOLS" || echo "Warning: no build-tools found" && \
    sdkmanager --install \
        ${API:+"platforms;android-$API"} \
        ${BUILD_TOOLS:+"build-tools;$BUILD_TOOLS"} \
        "platform-tools"

#---- Chrome（Web 调试） ----
USER root
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/pki/rpm-gpg/RPM-GPG-KEY-google && \
    echo -e "[google-chrome]\nname=google-chrome\nbaseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-google" \
    > /etc/yum.repos.d/google-chrome.repo && \
    dnf -y install google-chrome-stable && \
    dnf clean all
USER ${USER}

#---- FVM + Flutter 3 stable ----
ENV FVM_ROOT=/home/${USER}/fvm
ENV PATH=${PATH}:${FVM_ROOT}/default/bin
USER root
RUN curl -fsSL https://github.com/leoafarias/fvm/releases/download/3.2.0/fvm-3.2.0-linux-x64.tar.gz | tar xz -C /tmp && \
    mv /tmp/fvm /usr/local/bin/fvm && rm -rf /tmp/fvm*
USER ${USER}
RUN fvm install stable && \
    fvm global stable && \
    flutter precache && \
    flutter config --enable-web --enable-android

#---- 最终 ----
USER ${USER}
WORKDIR /home/${USER}
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FVM_ROOT=/home/${USER}/fvm
ENV PATH=${PATH}:${FVM_ROOT}/default/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools
CMD ["/bin/bash"]
