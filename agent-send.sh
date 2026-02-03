#!/bin/bash

# Agent間メッセージ送信スクリプト (Git Bash版 - ファイルベース)
# メッセージをファイルに保存し、短い通知をウィンドウに送信
# 複数行メッセージに対応

HANDLES_DIR="./tmp/handles"
MESSAGES_DIR="./messages"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 保存されたハンドルを読み込む
get_saved_handle() {
    local agent="$1"
    local handle_file="${HANDLES_DIR}/${agent}.hwnd"

    if [[ -f "$handle_file" ]]; then
        cat "$handle_file" | tr -d '\r\n'
    else
        echo ""
    fi
}

# ハンドルが有効か確認
check_handle_valid() {
    local hwnd="$1"
    local result
    result=$(powershell.exe -Command "
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32Check {
    [DllImport(\"user32.dll\")] public static extern bool IsWindow(IntPtr hWnd);
}
'@
        \$hwnd = [IntPtr]$hwnd
        if ([Win32Check]::IsWindow(\$hwnd)) { 'VALID' } else { 'INVALID' }
    " 2>/dev/null | tr -d '\r\n')

    [[ "$result" == "VALID" ]]
}

show_usage() {
    cat << EOF
Agent間メッセージ送信 (Git Bash版 - ファイルベース)

使用方法:
  $0 [エージェント名] "[メッセージ]"
  $0 --list
  $0 --status

利用可能エージェント:
  president - プロジェクト統括責任者
  boss1     - チームリーダー
  worker1   - 実行担当者A
  worker2   - 実行担当者B
  worker3   - 実行担当者C

使用例:
  $0 president "指示書に従って"
  $0 boss1 "Hello World プロジェクト開始指示"
  $0 worker1 "作業完了しました"

注意:
  先に ./setup.sh を実行してウィンドウを起動してください
EOF
}

# エージェント一覧表示
show_agents() {
    echo "利用可能なエージェント:"
    echo "=========================="

    if [[ ! -d "$HANDLES_DIR" ]]; then
        echo "ERROR: ハンドルディレクトリが見つかりません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi

    local found_any=false
    for agent in president boss1 worker1 worker2 worker3; do
        local hwnd
        hwnd=$(get_saved_handle "$agent")
        if [[ -n "$hwnd" ]]; then
            if check_handle_valid "$hwnd"; then
                echo "  $agent → HWND: $hwnd (有効)"
                found_any=true
            else
                echo "  $agent → HWND: $hwnd (無効 - ウィンドウが閉じられた)"
            fi
        else
            echo "  $agent → 未登録"
        fi
    done

    if [[ "$found_any" == false ]]; then
        echo ""
        echo "ERROR: 有効なエージェントが見つかりません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi
}

# ステータス確認
show_status() {
    echo "エージェントステータス:"
    echo "=========================="

    if [[ ! -d "$HANDLES_DIR" ]]; then
        echo "ERROR: ハンドルディレクトリが見つかりません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi

    local all_valid=true
    local found_any=false

    for agent in president boss1 worker1 worker2 worker3; do
        local hwnd
        hwnd=$(get_saved_handle "$agent")
        if [[ -n "$hwnd" ]]; then
            found_any=true
            if check_handle_valid "$hwnd"; then
                echo "  $agent: ✅ 有効 (HWND: $hwnd)"
            else
                echo "  $agent: ❌ 無効 (HWND: $hwnd - ウィンドウが閉じられた)"
                all_valid=false
            fi
        else
            echo "  $agent: ⚠️  未登録"
            all_valid=false
        fi
    done

    if [[ "$found_any" == false ]]; then
        echo ""
        echo "ERROR: 登録されたエージェントが見つかりません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi

    if [[ "$all_valid" == false ]]; then
        echo ""
        echo "WARNING: 一部のエージェントが無効です"
        echo "  ./setup.sh を再実行してウィンドウを起動してください"
        exit 1
    fi
}

# ログ記録
log_send() {
    local agent="$1"
    local msg_file="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p logs
    echo "[$timestamp] → $agent: $msg_file" >> logs/send_log.txt
}

# メッセージをファイルに保存
save_message() {
    local agent="$1"
    local message="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local msg_dir="${MESSAGES_DIR}/${agent}"

    mkdir -p "$msg_dir"

    local msg_file="${msg_dir}/${timestamp}.msg"
    echo "$message" > "$msg_file"

    echo "$msg_file"
}

# 短い通知をウィンドウに送信 (keybd_event + VkKeyScanW - クリップボード不使用)
send_notification() {
    local hwnd="$1"
    local notification="$2"

    # 通知をBase64エンコード
    local encoded_msg
    encoded_msg=$(echo -n "$notification" | base64 -w 0)

    # PowerShellスクリプトをファイルに書き出して実行
    local ps_script="./tmp/send_notify.ps1"
    cat > "$ps_script" << 'PSEOF'
param([string]$TargetHwnd, [string]$EncodedMsg)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Key {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern short VkKeyScanW(char ch);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
"@

$hwnd = [IntPtr]::new([long]$TargetHwnd)
$msg = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedMsg))

try {
    if (-not [Win32Key]::IsWindow($hwnd)) {
        Write-Output "ERROR: Invalid window handle $TargetHwnd"
        exit 1
    }

    # AttachThreadInput でフォアグラウンド制限を回避
    $currentThread = [Win32Key]::GetCurrentThreadId()
    $targetProcessId = [uint32]0
    $targetThread = [Win32Key]::GetWindowThreadProcessId($hwnd, [ref]$targetProcessId)

    $fgWnd = [Win32Key]::GetForegroundWindow()
    $fgProcessId = [uint32]0
    $fgThread = [Win32Key]::GetWindowThreadProcessId($fgWnd, [ref]$fgProcessId)

    $attached1 = [Win32Key]::AttachThreadInput($currentThread, $fgThread, $true)
    $attached2 = [Win32Key]::AttachThreadInput($currentThread, $targetThread, $true)

    # ウィンドウを復元して前面に
    [Win32Key]::ShowWindow($hwnd, 9) | Out-Null
    Start-Sleep -Milliseconds 100
    $fgResult = [Win32Key]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 400

    # デタッチ
    if ($attached1) { [Win32Key]::AttachThreadInput($currentThread, $fgThread, $false) | Out-Null }
    if ($attached2) { [Win32Key]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null }

    # メッセージを keybd_event + VkKeyScanW で1文字ずつ入力
    foreach ($char in $msg.ToCharArray()) {
        $vkResult = [Win32Key]::VkKeyScanW($char)
        if ($vkResult -eq -1) { continue }

        $vkCode = [byte]($vkResult -band 0xFF)
        $shiftState = ($vkResult -shr 8) -band 0xFF
        $needShift = ($shiftState -band 1) -ne 0

        if ($needShift) { [Win32Key]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero) }
        [Win32Key]::keybd_event($vkCode, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 5
        [Win32Key]::keybd_event($vkCode, 0, 2, [UIntPtr]::Zero)
        if ($needShift) { [Win32Key]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero) }
        Start-Sleep -Milliseconds 10
    }

    # keybd_event のテキストが入力キュー経由でターミナルに到達するのを待つ
    Start-Sleep -Milliseconds 1000

    # Enter キー（SendKeys で確実に送信）
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 200

    Write-Output "SUCCESS (fg=$fgResult)"
} catch {
    Write-Output ("ERROR: " + $_.Exception.Message)
    exit 1
}
PSEOF

    # LF→CRLF変換（PowerShellのhere-stringはCRLFが必要）
    sed -i 's/$/\r/' "$ps_script"

    # PowerShellスクリプトをファイルから実行
    local result
    result=$(powershell.exe -ExecutionPolicy Bypass -File "$(cygpath -w "$ps_script")" -TargetHwnd "$hwnd" -EncodedMsg "$encoded_msg" 2>&1 | tr -d '\r')

    echo "$result"

    if [[ "$result" == *"SUCCESS"* ]]; then
        return 0
    else
        return 1
    fi
}

# メイン処理
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # --listオプション
    if [[ "$1" == "--list" ]]; then
        show_agents
        exit 0
    fi

    # --statusオプション
    if [[ "$1" == "--status" ]]; then
        show_status
        exit 0
    fi

    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi

    local agent_name="$1"
    local message="$2"

    # ハンドルファイル確認
    if [[ ! -d "$HANDLES_DIR" ]]; then
        echo "ERROR: ハンドルディレクトリが見つかりません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi

    # 保存されたハンドルを取得
    local hwnd
    hwnd=$(get_saved_handle "$agent_name")

    if [[ -z "$hwnd" ]]; then
        echo "ERROR: エージェント '$agent_name' のハンドルが登録されていません"
        echo "  先に ./setup.sh を実行してください"
        exit 1
    fi

    # ハンドルが有効か確認
    if ! check_handle_valid "$hwnd"; then
        echo "ERROR: エージェント '$agent_name' のウィンドウが閉じられています (HWND: $hwnd)"
        echo "  先に ./setup.sh を実行してウィンドウを起動してください"
        exit 1
    fi

    echo "ウィンドウ検出: HWND = $hwnd"

    # メッセージをファイルに保存
    local msg_file
    msg_file=$(save_message "$agent_name" "$message")
    echo "メッセージ保存: $msg_file"

    # 絶対パスを取得
    local abs_msg_file
    abs_msg_file=$(cd "$SCRIPT_DIR" && realpath "$msg_file" 2>/dev/null || echo "${SCRIPT_DIR}/${msg_file}")

    # 短い通知をウィンドウに送信（ASCII のみ - VkKeyScanW 対応）
    local notification="Read ${abs_msg_file} and follow the instructions."

    echo "通知送信中..."
    if send_notification "$hwnd" "$notification"; then
        log_send "$agent_name" "$msg_file"
        echo "送信完了: $agent_name (HWND: $hwnd)"
        echo "  メッセージファイル: $msg_file"
    else
        echo "ERROR: 通知送信に失敗しました"
        exit 1
    fi

    return 0
}

main "$@"
