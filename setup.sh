#!/bin/bash

# Multi-Agent Communication Demo 環境構築 (Git Bash版)
# 各エージェント用のGit Bashウィンドウを起動し、Claudeを自動起動
# ウィンドウハンドルで管理

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

echo "Multi-Agent Communication Demo 環境構築 (Git Bash版)"
echo "======================================================"
echo ""

# STEP 1: ディレクトリ準備
log_info "ディレクトリ準備中..."

mkdir -p ./tmp ./logs ./messages ./tmp/handles
rm -f ./tmp/worker*_done.txt 2>/dev/null && log_info "既存の完了ファイルをクリア" || true
rm -f ./tmp/handles/*.hwnd 2>/dev/null && log_info "既存のハンドルファイルをクリア" || true

log_success "ディレクトリ準備完了"
echo ""

# STEP 2: minttyのパス確認
log_info "Git Bash (mintty) パス確認中..."

MINTTY_PATHS=(
    "/c/Program Files/Git/usr/bin/mintty.exe"
    "/c/Program Files (x86)/Git/usr/bin/mintty.exe"
    "$(which mintty 2>/dev/null || echo '')"
)

MINTTY_PATH=""
for path in "${MINTTY_PATHS[@]}"; do
    if [[ -n "$path" && -f "$path" ]]; then
        MINTTY_PATH="$path"
        break
    fi
done

if [[ -z "$MINTTY_PATH" ]]; then
    log_error "mintty.exe が見つかりません"
    log_error "Git for Windows がインストールされていることを確認してください"
    exit 1
fi

log_info "mintty found: $MINTTY_PATH"
echo ""

# 作業ディレクトリ
WORK_DIR=$(pwd)

# エージェント定義
declare -A AGENT_COLORS=(
    ["president"]="135"   # 紫
    ["boss1"]="196"       # 赤
    ["worker1"]="33"      # 青
    ["worker2"]="33"      # 青
    ["worker3"]="33"      # 青
)

AGENTS=("president" "boss1" "worker1" "worker2" "worker3")

# STEP 3: 各エージェント用ウィンドウを起動
log_info "エージェントウィンドウを起動中..."

for agent in "${AGENTS[@]}"; do
    title="Claude-${agent}"
    color="${AGENT_COLORS[$agent]}"

    log_info "$agent ウィンドウを起動中 (タイトル: $title)..."

    "$MINTTY_PATH" --title "$title" --size 120,30 --exec /bin/bash -c "
        cd '$WORK_DIR'
        export PS1='(\[\033[38;5;${color}m\]${agent}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '

        echo ''
        echo '==================================='
        echo '  $agent エージェント'
        echo '==================================='
        echo ''

        exec bash --norc --noprofile
    " &

    sleep 1
done

log_success "全ウィンドウの起動完了"
echo ""

# STEP 4: ウィンドウハンドル取得・保存
log_info "ウィンドウハンドル取得中..."
sleep 1

all_handles_ok=true

for agent in "${AGENTS[@]}"; do
    title="Claude-${agent}"
    hwnd=$(powershell.exe -Command "
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport(\"user32.dll\")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport(\"user32.dll\")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport(\"user32.dll\")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
'@
        \$found = [IntPtr]::Zero
        \$callback = [Win32+EnumWindowsProc]{
            param(\$hwnd, \$lparam)
            if ([Win32]::IsWindowVisible(\$hwnd)) {
                \$sb = New-Object System.Text.StringBuilder 256
                [Win32]::GetWindowText(\$hwnd, \$sb, 256) | Out-Null
                if (\$sb.ToString().StartsWith('$title')) {
                    \$script:found = \$hwnd
                    return \$false
                }
            }
            return \$true
        }
        [Win32]::EnumWindows(\$callback, [IntPtr]::Zero) | Out-Null
        if (\$found -ne [IntPtr]::Zero) { \$found.ToInt64() }
    " 2>/dev/null | tr -d '\r\n')

    if [[ -n "$hwnd" && "$hwnd" != "0" ]]; then
        echo "$hwnd" > "./tmp/handles/${agent}.hwnd"
        log_info "$agent: HWND = $hwnd (保存済み)"
    else
        log_warning "$agent: ウィンドウが見つかりません"
        all_handles_ok=false
    fi
done

if [[ "$all_handles_ok" != true ]]; then
    log_error "一部のウィンドウが見つかりません。処理を中断します。"
    exit 1
fi

log_success "全ハンドル取得完了"
echo ""

# STEP 5: 各エージェントでClaude起動
log_info "各エージェントでClaudeを起動中..."
echo ""

for agent in "${AGENTS[@]}"; do
    hwnd=$(cat "./tmp/handles/${agent}.hwnd" 2>/dev/null | tr -d '\r\n')

    if [[ -z "$hwnd" ]]; then
        log_warning "$agent: ハンドルファイルが見つかりません"
        continue
    fi

    log_info "$agent を起動中 (HWND: $hwnd)..."

    result=$(powershell.exe -Command "
        Add-Type -AssemblyName System.Windows.Forms

        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32Launch {
    [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport(\"user32.dll\")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport(\"user32.dll\")] public static extern bool IsWindow(IntPtr hWnd);
}
'@

        \$hwnd = [IntPtr]$hwnd

        try {
            if (-not [Win32Launch]::IsWindow(\$hwnd)) {
                Write-Output 'ERROR: Invalid window handle'
                exit 1
            }

            [Win32Launch]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 50
            [Win32Launch]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 50

            [Win32Launch]::ShowWindow(\$hwnd, 9) | Out-Null
            Start-Sleep -Milliseconds 100

            [Win32Launch]::SetForegroundWindow(\$hwnd) | Out-Null
            Start-Sleep -Milliseconds 500

            [System.Windows.Forms.SendKeys]::SendWait('claude --dangerously-skip-permissions')
            Start-Sleep -Milliseconds 200

            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

            Write-Output 'SUCCESS'
        } catch {
            Write-Output ('ERROR: ' + \$_.Exception.Message)
            exit 1
        }
    " 2>&1 | tr -d '\r')

    if [[ "$result" == *"SUCCESS"* ]]; then
        log_success "$agent: Claude起動コマンド送信完了"
    else
        log_warning "$agent: 起動に失敗 - $result"
    fi

    sleep 2
done

echo ""
log_success "セットアップ完了！"
echo ""
echo "========================================"
echo "起動したエージェント:"
echo "  Claude-president   (プロジェクト統括責任者)"
echo "  Claude-boss1       (チームリーダー)"
echo "  Claude-worker1     (実行担当者A)"
echo "  Claude-worker2     (実行担当者B)"
echo "  Claude-worker3     (実行担当者C)"
echo "========================================"
echo ""
echo "次のステップ:"
echo "  1. 各ウィンドウでブラウザ認証を完了してください"
echo ""
echo "  2. PRESIDENTに指示を送信:"
echo "     ./agent-send.sh president \"あなたはpresidentです。[プロジェクト内容]\""
echo ""
echo "  3. ステータス確認:"
echo "     ./agent-send.sh --status"
