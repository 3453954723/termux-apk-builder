# Termux APK Builder

在 Termux 终端中编译 Android APK 的工具集，兼容 Android 16。

## 快速开始

### 1. 安装依赖

```bash
pkg install openjdk-17 aapt2 apksigner dx zipalign
```

### 2. 下载工具

```bash
git clone https://github.com/3453954723/termux-apk-builder.git
cd termux-apk-builder
cp tools/apk-builder.sh ~/tools/
chmod +x ~/tools/apk-builder.sh
mkdir -p ~/android-sdk/android-34
cp android-sdk/android-34/android.jar ~/android-sdk/android-34/
```

### 3. 编译 APK

```bash
# 初始化项目
apk-builder.sh init MyApp com.example.myapp MyApp

# 编译
apk-builder.sh build MyApp

# 安装
termux-open MyApp/build/app.apk
```

## 目录结构

```
termux-apk-builder/
├── android-sdk/
│   └── android-34/
│       └── android.jar          # Android 框架类（编译用）
├── tools/
│   └── apk-builder.sh           # 编译脚本
├── examples/
│   └── calculator.apk           # 示例计算器 App
└── README.md
```

## 编译脚本用法

```bash
apk-builder.sh init <项目目录> <包名> <应用名>  # 初始化新项目
apk-builder.sh build <项目目录> [输出名称]       # 编译项目
apk-builder.sh clean <项目目录>                  # 清理构建文件
apk-builder.sh check                             # 检查依赖
apk-builder.sh help                              # 显示帮助
```

## 编译流程

1. **aapt2 compile** - 编译资源文件为 .flat 格式
2. **aapt2 link** - 链接资源并生成 R.java
3. **javac** - 编译 Java 代码
4. **dx** - 转换为 DEX 格式
5. **zipalign** - 优化 APK 对齐
6. **apksigner** - 签名 APK

## 注意事项

- UI 只能用纯 Java 代码创建，不能使用 XML 布局文件
- 生成的 APK 需要 Android 5.0+ (API 21+)
- 使用调试密钥签名，适合开发测试
- 安装 APK 需要使用 `termux-open` 或文件管理器

## 示例项目

`examples/calculator.apk` 是一个编译好的计算器 App，可以直接安装体验。

## 依赖说明

| 工具 | 用途 | 安装命令 |
|------|------|----------|
| java | 编译 Java 代码 | `pkg install openjdk-17` |
| aapt2 | 编译资源文件 | `pkg install aapt2` |
| dx | 转换 DEX 格式 | `pkg install dx` |
| zipalign | 优化 APK | `pkg install zipalign` |
| apksigner | 签名 APK | `pkg install apksigner` |
| keytool | 生成密钥 | 随 Java 安装 |

## 常见问题

### Q: 安装 APK 时提示"解析安装包出现问题"
A: 确保使用 aapt2 编译，而不是旧版 aapt。

### Q: 如何在 MT 管理器中找到 APK？
A: APK 位于项目的 `build/` 目录下，完整路径如：
```
/data/data/com.termux/files/home/MyApp/build/app.apk
```

### Q: 如何复制 APK 到下载目录？
A: 使用命令：
```bash
cp MyApp/build/app.apk ~/storage/downloads/
```

## 许可证

MIT License

---

## 作者有话说

大家好，我是**星社**！

这个项目诞生于一个简单的想法：能不能在手机上直接编译 Android App，不需要电脑，不需要 Android Studio？

经过反复尝试和踩坑，终于在 Termux 上实现了这个目标。过程中遇到了很多问题：
- aapt v0.2 太旧，生成的 APK 在新系统上无法安装
- aapt2 的 ARM 版本难以获取
- Android 16 的 SELinux 策略更加严格

最终通过安装 Termux 官方源的 aapt2 包解决了所有问题。

**希望这个工具能帮到你！** 如果觉得有用，欢迎 Star 支持一下~

有问题或建议，欢迎提 Issue！

---

> 星社 | 2026.05.04
> 
> "在终端里，我们也能创造属于自己的 App。"
