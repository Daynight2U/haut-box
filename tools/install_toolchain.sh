#!/usr/bin/env bash
# 一键安装 Flutter + JDK17 + Android SDK 到 E:\devkit（避开 C 盘仅剩 25G）
export PATH="/c/Users/33298/.workbuddy/binaries/PortableGit/versions/1.2.0/usr/bin:/c/Windows/System32:/c/Windows:$PATH"
set -u
DEV=/e/devkit
mkdir -p "$DEV"
cd "$DEV"
log() { echo "[$(date +%H:%M:%S)] $*"; }

log "== 下载 JDK17 =="
[ -f jdk17.zip ] || curl -fL --retry 3 --retry-delay 2 -o jdk17.zip \
  "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.21.1_2.zip"
log "JDK17 $(du -m jdk17.zip | cut -f1)MB"

log "== 下载 Flutter 3.50.1 =="
[ -f flutter.zip ] || curl -fL --retry 3 --retry-delay 2 -o flutter.zip \
  "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.1-stable.zip"
log "Flutter $(du -m flutter.zip | cut -f1)MB"

log "== 下载 Android cmdline-tools =="
[ -f cmdtools.zip ] || curl -fL --retry 3 --retry-delay 2 -o cmdtools.zip \
  "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
log "cmdtools $(du -m cmdtools.zip | cut -f1)MB"

log "== 解压 JDK =="
if [ ! -d jdk17 ]; then
  rm -rf jdk-tmp && mkdir jdk-tmp && unzip -q jdk17.zip -d jdk-tmp
  inner=$(ls -d jdk-tmp/jdk-17* | head -1) && mv "$inner" jdk17 && rm -rf jdk-tmp
fi
log "JDK -> $(ls jdk17/bin/java.exe 2>/dev/null || echo FAIL)"

log "== 解压 Flutter =="
if [ ! -d flutter ]; then unzip -q flutter.zip -d . ; fi
log "Flutter -> $(ls flutter/bin/flutter.bat 2>/dev/null || echo FAIL)"

log "== 解压 cmdline-tools =="
if [ ! -d android-sdk/cmdline-tools/latest ]; then
  rm -rf android-sdk/cmdline-tools-tmp && mkdir -p android-sdk/cmdline-tools-tmp
  unzip -q cmdtools.zip -d android-sdk/cmdline-tools-tmp
  mkdir -p android-sdk/cmdline-tools
  mv android-sdk/cmdline-tools-tmp/cmdline-tools android-sdk/cmdline-tools/latest
  rm -rf android-sdk/cmdline-tools-tmp
fi
log "cmdline-tools -> $(ls android-sdk/cmdline-tools/latest/bin/sdkmanager.bat 2>/dev/null || echo FAIL)"

export JAVA_HOME="E:\\devkit\\jdk17"
export ANDROID_HOME="E:\\devkit\\android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

log "== 接受 licenses =="
yes 2>/dev/null | "$DEV/android-sdk/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="E:\\devkit\\android-sdk" --licenses > /dev/null 2>&1
log "licenses done"

log "== 安装 SDK 组件 =="
"$DEV/android-sdk/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="E:\\devkit\\android-sdk" \
  "platform-tools" "platforms;android-36" "platforms;android-35" "build-tools;36.0.0" "build-tools;35.0.0" 2>&1 | tail -5
log "sdk components done"

log "== 预热 Flutter（首次会编译快照，慢）=="
export PUB_CACHE="E:\\devkit\\pub-cache"
export GRADLE_USER_HOME="E:\\devkit\\gradle-home"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
"$DEV/flutter/bin/flutter.bat" --version 2>&1 | tail -8
log "== 全部完成 =="
