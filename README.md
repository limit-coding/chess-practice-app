# 棋类练习 App（五子棋 / 象棋）

用开源博弈引擎做对手 + 复盘教练的练习工具。核心思路：

1. **人机对弈**：引擎（[Rapfi](https://github.com/dhbloo/rapfi)，GPLv3）作为对手，可调难度。
2. **复盘练习**：对局结束后逐步评估，找出走差的着法，退回该局面按引擎推荐重走，在残局基础上继续练。

## 结构

```
app/              Flutter 应用（iOS / Android）
native/rapfi/     Rapfi 引擎（git submodule，GPLv3）
native/wrapper/   C 桥接层：引擎跑在进程内线程，暴露 3 个 C 函数供 FFI 调用
总纲.md           原始想法
技术方案.md        方案定稿（引擎选型、复盘设计、技术栈决策）
实施步骤.md        分阶段计划与进度
开发日志.md        踩坑与经验记录
```

## 构建

```bash
git submodule update --init

# 引擎桥接层（Mac 本地验证）
cd native/wrapper
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j8
./build/bridge_test   # 应输出 ALL PASS

# iOS 静态库（真机 + 模拟器）
cmake -B build-ios -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
cmake --build build-ios -j8 --target rapfi_core
cmake -B build-ios-sim -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
cmake --build build-ios-sim -j8 --target rapfi_core

# Flutter 应用
cd ../../app
flutter run
```

## 许可

GPL-3.0（因链接 GPLv3 的 Rapfi 引擎，本项目整体以 GPLv3 发布），见 [LICENSE](./LICENSE)。
