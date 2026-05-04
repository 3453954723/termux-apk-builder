#!/bin/bash
# Android APK Builder for Termux
# 终端专用Android编译器 (使用 aapt2)

# 错误处理在各步骤中手动进行

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
ANDROID_SDK="/data/data/com.termux/files/home/android-sdk"
ANDROID_JAR="$ANDROID_SDK/android-34/android.jar"
DEBUG_KEYSTORE="$ANDROID_SDK/debug.keystore"

# 打印带颜色的消息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检查依赖
check_dependencies() {
    local deps=("java" "aapt2" "dx" "zipalign" "apksigner" "keytool")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "缺少依赖: $dep"
        fi
    done
    success "所有依赖已安装"
}

# 初始化项目
init_project() {
    local project_dir="$1"
    local package_name="$2"
    local app_name="$3"

    if [ -z "$project_dir" ] || [ -z "$package_name" ] || [ -z "$app_name" ]; then
        error "用法: $0 init <项目目录> <包名> <应用名>"
    fi

    if [ -d "$project_dir" ]; then
        error "项目目录已存在: $project_dir"
    fi

    info "初始化项目: $app_name"

    # 创建目录结构
    mkdir -p "$project_dir"/{src/$(echo "$package_name" | tr '.' '/'),res/values,build}

    # 创建AndroidManifest.xml
    cat > "$project_dir/AndroidManifest.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$package_name">

    <application android:label="@string/app_name">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

    # 创建MainActivity.java (纯代码UI，不依赖XML布局)
    cat > "$project_dir/src/$(echo "$package_name" | tr '.' '/')/MainActivity.java" << EOF
package $package_name;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.LinearLayout;
import android.view.Gravity;
import android.graphics.Color;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(Color.WHITE);

        TextView tv = new TextView(this);
        tv.setText("Hello, $app_name!");
        tv.setTextSize(24);
        tv.setTextColor(Color.BLACK);
        tv.setGravity(Gravity.CENTER);

        layout.addView(tv);
        setContentView(layout);
    }
}
EOF

    # 创建字符串资源
    cat > "$project_dir/res/values/strings.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$app_name</string>
</resources>
EOF

    # 生成调试密钥库
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        info "生成调试密钥库..."
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -storepass android -alias androiddebugkey \
            -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
    fi

    success "项目初始化完成: $project_dir"
    echo ""
    echo "项目结构:"
    echo "  $project_dir/"
    echo "  ├── AndroidManifest.xml"
    echo "  ├── src/"
    echo "  │   └── $(echo "$package_name" | tr '.' '/')/"
    echo "  │       └── MainActivity.java"
    echo "  ├── res/"
    echo "  │   └── values/"
    echo "  │       └── strings.xml"
    echo "  └── build/"
    echo ""
    echo "编译命令: $0 build $project_dir"
}

# 编译项目
build_project() {
    local project_dir="$1"
    local output_name="${2:-app}"

    if [ -z "$project_dir" ]; then
        error "用法: $0 build <项目目录> [输出名称]"
    fi

    if [ ! -d "$project_dir" ]; then
        error "项目目录不存在: $project_dir"
    fi

    cd "$project_dir"

    # 清理构建目录
    rm -rf build
    mkdir -p build/classes build/compiled_res

    info "开始编译..."

    # 步骤1: 用aapt2编译资源
    info "步骤 1/6: 编译资源文件..."
    local aapt2_compile_output
    aapt2_compile_output=$(aapt2 compile --dir res -o build/compiled_res/ 2>&1)
    local aapt2_compile_result=$?
    if [ -n "$aapt2_compile_output" ]; then
        echo "$aapt2_compile_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $aapt2_compile_result -ne 0 ]; then
        error "资源编译失败"
    fi
    success "资源编译完成"

    # 步骤2: 用aapt2链接资源并生成R.java
    info "步骤 2/6: 链接资源..."
    local aapt2_link_output
    aapt2_link_output=$(aapt2 link -o build/app.apk \
        -I "$ANDROID_JAR" \
        --manifest AndroidManifest.xml \
        --java build/src \
        build/compiled_res/*.flat 2>&1)
    local aapt2_link_result=$?
    if [ -n "$aapt2_link_output" ]; then
        echo "$aapt2_link_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $aapt2_link_result -ne 0 ]; then
        error "资源链接失败"
    fi
    success "资源链接完成"

    # 步骤3: 编译Java代码
    info "步骤 3/6: 编译Java代码..."
    find src build/src -name "*.java" > build/sources.txt 2>/dev/null
    local javac_output
    javac_output=$(javac -source 1.8 -target 1.8 \
        -cp "$ANDROID_JAR" \
        -d build/classes \
        @build/sources.txt 2>&1)
    local javac_result=$?
    if [ -n "$javac_output" ]; then
        echo "$javac_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $javac_result -ne 0 ]; then
        error "Java编译失败"
    fi
    success "Java编译完成"

    # 步骤4: 转换为DEX
    info "步骤 4/6: 转换为DEX格式..."
    local dx_output
    dx_output=$(dx --dex --output=build/classes.dex build/classes/ 2>&1)
    local dx_result=$?
    if [ -n "$dx_output" ]; then
        echo "$dx_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $dx_result -ne 0 ]; then
        error "DEX转换失败"
    fi
    success "DEX转换完成"

    # 步骤5: 添加DEX到APK
    info "步骤 5/6: 打包APK..."
    local aapt_add_output
    aapt_add_output=$(aapt add build/app.apk build/classes.dex 2>&1)
    local aapt_add_result=$?
    if [ -n "$aapt_add_output" ]; then
        echo "$aapt_add_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $aapt_add_result -ne 0 ]; then
        error "添加DEX文件失败"
    fi
    success "APK打包完成"

    # 步骤6: 优化并签名APK
    info "步骤 6/6: 优化并签名APK..."
    zipalign -f 4 build/app.apk build/app.aligned.apk 2>&1

    # 生成调试密钥库
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -storepass android -alias androiddebugkey \
            -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
    fi

    local apksigner_output
    apksigner_output=$(apksigner sign \
        --ks "$DEBUG_KEYSTORE" \
        --ks-pass pass:android \
        --ks-key-alias androiddebugkey \
        --key-pass pass:android \
        --min-sdk-version 21 \
        --out "build/${output_name}.apk" \
        build/app.aligned.apk 2>&1)
    local apksigner_result=$?
    if [ -n "$apksigner_output" ]; then
        echo "$apksigner_output" | while read line; do
            echo "  $line"
        done
    fi
    if [ $apksigner_result -ne 0 ]; then
        error "APK签名失败"
    fi
    success "APK签名完成"

    # 显示结果
    echo ""
    echo "=========================================="
    success "编译完成!"
    echo "=========================================="
    echo ""
    echo "输出文件: $project_dir/build/${output_name}.apk"
    echo "文件大小: $(ls -lh "build/${output_name}.apk" | awk '{print $5}')"
    echo ""
    echo "安装命令:"
    echo "  termux-open build/${output_name}.apk"
}

# 清理构建文件
clean_project() {
    local project_dir="$1"

    if [ -z "$project_dir" ]; then
        error "用法: $0 clean <项目目录>"
    fi

    if [ ! -d "$project_dir" ]; then
        error "项目目录不存在: $project_dir"
    fi

    info "清理构建文件..."
    rm -rf "$project_dir/build"
    rm -f "$project_dir/src"/*/R.java
    success "清理完成"
}

# 显示帮助
show_help() {
    echo "Android APK Builder for Termux"
    echo "终端专用Android编译器"
    echo ""
    echo "用法:"
    echo "  $0 init <项目目录> <包名> <应用名>  初始化新项目"
    echo "  $0 build <项目目录> [输出名称]       编译项目"
    echo "  $0 clean <项目目录>                  清理构建文件"
    echo "  $0 check                             检查依赖"
    echo "  $0 help                              显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 init MyApp com.example.myapp MyApp"
    echo "  $0 build MyApp"
    echo "  $0 clean MyApp"
    echo ""
    echo "环境变量:"
    echo "  ANDROID_SDK    Android SDK路径 (默认: $ANDROID_SDK)"
    echo "  ANDROID_JAR    android.jar路径 (默认: $ANDROID_JAR)"
}

# 主函数
main() {
    local command="$1"
    shift

    case "$command" in
        init)
            init_project "$@"
            ;;
        build)
            build_project "$@"
            ;;
        clean)
            clean_project "$@"
            ;;
        check)
            check_dependencies
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "未知命令: $command\n使用 '$0 help' 查看帮助"
            ;;
    esac
}

# 运行主函数
main "$@"