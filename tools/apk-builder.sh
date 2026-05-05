#!/bin/bash
# Android APK Builder for Termux v2.0
# 终端专用Android编译器 - 支持XML布局

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
ANDROID_SDK="/data/data/com.termux/files/home/android-sdk"
ANDROID_JAR="$ANDROID_SDK/android-34/android.jar"
DEBUG_KEYSTORE="$ANDROID_SDK/debug.keystore"

# 打印消息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${CYAN}[$1/$2]${NC} $3"; }

# 检查依赖
check_dependencies() {
    local missing=()
    for dep in java aapt2 dx zipalign apksigner keytool; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "缺少依赖: ${missing[*]}\n安装命令: pkg install ${missing[*]}"
    fi

    if [ ! -f "$ANDROID_JAR" ]; then
        error "android.jar 不存在: $ANDROID_JAR"
    fi

    success "所有依赖已安装"
    echo "  java:     $(java -version 2>&1 | head -1)"
    echo "  aapt2:    $(aapt2 version 2>&1 | head -1)"
}

# 初始化项目
init_project() {
    local project_dir="$1"
    local package_name="$2"
    local app_name="$3"

    if [ -z "$project_dir" ] || [ -z "$package_name" ] || [ -z "$app_name" ]; then
        echo "用法: $0 init <项目目录> <包名> <应用名>"
        echo "示例: $0 init MyApp com.example.myapp MyApp"
        exit 1
    fi

    if [ -d "$project_dir" ]; then
        error "项目目录已存在: $project_dir"
    fi

    local pkg_path=$(echo "$package_name" | tr '.' '/')

    info "初始化项目: $app_name"

    # 创建目录结构
    mkdir -p "$project_dir"/{src/"$pkg_path",res/{layout,values,drawable,mipmap-hdpi},build}

    # 创建AndroidManifest.xml
    cat > "$project_dir/AndroidManifest.xml" << MANIFEST
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$package_name">

    <application
        android:label="@string/app_name"
        android:theme="@android:style/Theme.Material.Light.DarkActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
MANIFEST

    # 创建主布局文件
    cat > "$project_dir/res/layout/activity_main.xml" << 'LAYOUT'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="24dp"
    android:background="#FFFFFF">

    <TextView
        android:id="@+id/title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/hello"
        android:textSize="28sp"
        android:textColor="#333333"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/subtitle"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/welcome"
        android:textSize="16sp"
        android:textColor="#666666"
        android:layout_marginTop="8dp" />

    <Button
        android:id="@+id/btn_click"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/click_me"
        android:layout_marginTop="24dp" />

</LinearLayout>
LAYOUT

    # 创建字符串资源
    cat > "$project_dir/res/values/strings.xml" << STRINGS
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$app_name</string>
    <string name="hello">Hello World!</string>
    <string name="welcome">Welcome to $app_name</string>
    <string name="click_me">Click Me</string>
</resources>
STRINGS

    # 创建颜色资源
    cat > "$project_dir/res/values/colors.xml" << 'COLORS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF6200EE</color>
    <color name="primary_dark">#FF3700B3</color>
    <color name="accent">#FF03DAC5</color>
    <color name="white">#FFFFFFFF</color>
    <color name="black">#FF000000</color>
</resources>
COLORS

    # 创建MainActivity.java
    cat > "$project_dir/src/$pkg_path/MainActivity.java" << JAVA
package $package_name;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Button;
import android.view.View;
import android.widget.Toast;

public class MainActivity extends Activity {

    private int clickCount = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        final TextView subtitle = (TextView) findViewById(R.id.subtitle);
        Button btnClick = (Button) findViewById(R.id.btn_click);

        btnClick.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                clickCount++;
                subtitle.setText("Clicked " + clickCount + " times!");
                Toast.makeText(MainActivity.this, "Button clicked!", Toast.LENGTH_SHORT).show();
            }
        });
    }
}
JAVA

    # 生成调试密钥库
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        info "生成调试密钥库..."
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -storepass android -alias androiddebugkey \
            -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
    fi

    success "项目初始化完成!"
    echo ""
    echo "项目结构:"
    find "$project_dir" -type f | sort | sed "s|$project_dir/|  $project_dir/|"
    echo ""
    echo "编译: $0 build $project_dir"
    echo "安装: termux-open $project_dir/build/app.apk"
}

# 编译项目
build_project() {
    local project_dir="$1"
    local output_name="${2:-app}"
    local total_steps=6

    if [ -z "$project_dir" ]; then
        error "用法: $0 build <项目目录> [输出名称]"
    fi

    if [ ! -d "$project_dir" ]; then
        error "项目目录不存在: $project_dir"
    fi

    cd "$project_dir"

    # 清理构建目录
    rm -rf build
    mkdir -p build/classes build/compiled_res build/gen

    echo ""
    info "开始编译项目..."
    echo ""

    # 步骤1: 编译资源文件
    step 1 $total_steps "编译资源文件 (aapt2 compile)..."
    if [ -d "res" ]; then
        local res_files=$(find res -type f | head -100)
        if [ -n "$res_files" ]; then
            aapt2 compile --dir res -o build/compiled_res/ 2>&1 | sed 's/^/  /'
            if [ ${PIPESTATUS[0]} -ne 0 ]; then
                error "资源编译失败"
            fi
            success "资源编译完成"
        else
            warn "没有资源文件，跳过"
        fi
    else
        warn "没有res目录，跳过"
    fi

    # 步骤2: 链接资源，生成R.java和基础APK
    step 2 $total_steps "链接资源 (aapt2 link)..."
    local flat_files=$(ls build/compiled_res/*.flat 2>/dev/null)
    if [ -n "$flat_files" ]; then
        aapt2 link -o build/app.apk \
            -I "$ANDROID_JAR" \
            --manifest AndroidManifest.xml \
            --java build/gen \
            --auto-add-overlay \
            --min-sdk-version 21 \
            --target-sdk-version 34 \
            build/compiled_res/*.flat 2>&1 | sed 's/^/  /'
    else
        aapt2 link -o build/app.apk \
            -I "$ANDROID_JAR" \
            --manifest AndroidManifest.xml \
            --java build/gen \
            --min-sdk-version 21 \
            --target-sdk-version 34 2>&1 | sed 's/^/  /'
    fi

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "资源链接失败"
    fi
    success "资源链接完成"

    # 步骤3: 编译Java代码 (使用Java 8兼容dx)
    step 3 $total_steps "编译Java代码 (javac)..."
    find src build/gen -name "*.java" > build/sources.txt 2>/dev/null
    local src_count=$(wc -l < build/sources.txt)
    info "找到 $src_count 个Java源文件"

    javac --release 8 \
        -cp "$ANDROID_JAR" \
        -d build/classes \
        @build/sources.txt 2>&1 | sed 's/^/  /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "Java编译失败"
    fi
    success "Java编译完成"

    # 步骤4: 转换为DEX
    step 4 $total_steps "转换为DEX (dx)..."
    local class_files=$(find build/classes -name "*.class" 2>/dev/null)
    if [ -z "$class_files" ]; then
        error "没有找到class文件"
    fi

    dx --dex --output=build/classes.dex build/classes/ 2>&1 | sed 's/^/  /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "DEX转换失败"
    fi

    if [ -f "build/classes.dex" ]; then
        success "DEX转换完成"
    else
        error "DEX文件未生成"
    fi

    # 步骤5: 打包APK
    step 5 $total_steps "打包APK..."
    cp build/app.apk build/app-unsigned.apk

    aapt add -f build/app-unsigned.apk build/classes.dex 2>&1 | sed 's/^/  /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "添加DEX失败"
    fi
    success "APK打包完成"

    # 步骤6: 对齐并签名
    step 6 $total_steps "对齐并签名..."

    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -storepass android -alias androiddebugkey \
            -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
    fi

    zipalign -f 4 build/app-unsigned.apk build/app-aligned.apk 2>&1 | sed 's/^/  /'

    apksigner sign \
        --ks "$DEBUG_KEYSTORE" \
        --ks-pass pass:android \
        --ks-key-alias androiddebugkey \
        --key-pass pass:android \
        --min-sdk-version 21 \
        --out "build/${output_name}-signed.apk" \
        build/app-aligned.apk 2>&1 | sed 's/^/  /'

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "APK签名失败"
    fi
    success "APK签名完成"

    # 重命名并清理临时文件
    mv "build/${output_name}-signed.apk" "build/${output_name}.apk"
    rm -f build/app-unsigned.apk build/app-aligned.apk build/*.idsig

    # 显示结果
    echo ""
    echo "=========================================="
    success "编译完成!"
    echo "=========================================="
    echo ""
    echo "  输出: $project_dir/build/${output_name}.apk"
    echo "  大小: $(ls -lh "build/${output_name}.apk" | awk '{print $5}')"
    echo ""
    echo "  安装: termux-open build/${output_name}.apk"
    echo ""
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
    success "清理完成"
}

# 显示帮助
show_help() {
    cat << 'EOF'
Android APK Builder for Termux v2.0
终端专用Android编译器 - 支持XML布局

用法:
  apk-builder init <目录> <包名> <应用名>  初始化新项目
  apk-builder build <目录> [输出名]        编译项目
  apk-builder clean <目录>                 清理构建
  apk-builder check                        检查依赖
  apk-builder help                         显示帮助

示例:
  apk-builder init MyApp com.example.myapp MyApp
  apk-builder build MyApp
  apk-builder build MyApp myapp  # 输出 myapp.apk

项目结构:
  MyApp/
  ├── AndroidManifest.xml
  ├── src/
  │   └── com/example/myapp/
  │       └── MainActivity.java
  ├── res/
  │   ├── layout/
  │   │   └── activity_main.xml    # XML布局
  │   ├── values/
  │   │   ├── strings.xml
  │   │   └── colors.xml
  │   └── drawable/
  └── build/

特性:
  - 支持XML布局文件
  - 支持资源文件 (strings, colors, drawables)
  - 自动生成R.java
  - 自动签名和对齐

依赖:
  pkg install aapt2 dx openjdk-17
EOF
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

main "$@"