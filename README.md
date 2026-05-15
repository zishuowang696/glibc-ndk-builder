# glibc-ndk-builder

用 Android NDK 交叉编译 glibc（aarch64），通过 GitHub Actions + Pages 分发产物。

## 产物

- **glibc 2.40** — `aarch64-linux-gnu` 目标
- **编译器** — Android NDK r28（Clang/LLVM）
- **下载** — 见 [GitHub Pages](https://zishuowang696.github.io/glibc-ndk-builder/) 或 Release 页面

## 用法

```bash
# 下载
wget https://zishuowang696.github.io/glibc-ndk-builder/glibc-2.40-aarch64-ndk.tar.gz

# 解压到 sysroot
tar xzf glibc-2.40-aarch64-ndk.tar.gz -C /path/to/sysroot
```
