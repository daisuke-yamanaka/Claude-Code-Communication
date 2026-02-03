#!/bin/bash

# Agent間メッセージ送信スクリプト (Git Bash版)
# 保存されたウィンドウハンドルを使用してメッセージを送信
# ウィンドウが存在しない場合はエラー終了（新規ウィンドウは開かない）

HANDLES_DIR="./tmp/handles"

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
Agent間メッセージ送信 (Git Bash版 - ウィンドウハンドル管理)

使用方法:
  $0 [エージェント名] [メッセージ]
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
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p logs
    echo "[$timestamp] $agent: SENT - \"$message\"" >> logs/send_log.txt
}

# メッセージ送信 (ウィンドウハンドルベース)
send_message_by_hwnd() {
    local hwnd="$1"
    local message="$2"

    echo "送信中: HWND $hwnd <- '$message'"

    # メッセージをBase64エンコード（日本語対応）
    local encoded_msg
    encoded_msg=$(echo -n "$message" | base64 -w 0)

    # PowerShellでウィンドウハンドルに直接キー送信
    local result
    result=$(powershell.exe -Command "
        Add-Type -AssemblyName System.Windows.Forms

        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32Send {
    [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport(\"user32.dll\")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport(\"user32.dll\")] public static extern bool IsWindow(IntPtr hWnd);
}
'@

        \$hwnd = [IntPtr]$hwnd
        \$encodedMsg = '$encoded_msg'
        \$msg = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\$encodedMsg))

        try {
            if (-not [Win32Send]::IsWindow(\$hwnd)) {
                Write-Output 'ERROR: Invalid window handle'
                exit 1
            }

            # Altキーを押す（フォアグラウンド制限回避）
            [Win32Send]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 50
            [Win32Send]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 50

            # ウィンドウを復元 (SW_RESTORE = 9)
            [Win32Send]::ShowWindow(\$hwnd, 9) | Out-Null
            Start-Sleep -Milliseconds 100

            # フォアグラウンドに設定
            [Win32Send]::SetForegroundWindow(\$hwnd) | Out-Null
            Start-Sleep -Milliseconds 300

            # Ctrl+C で現在の入力をクリア
            [System.Windows.Forms.SendKeys]::SendWait('^c')
            Start-Sleep -Milliseconds 200

            # メッセージを送信（特殊文字をエスケープ）
            \$escapedMsg = \$msg -replace '([+^%~{}\[\]()])', '{\$1}'
            [System.Windows.Forms.SendKeys]::SendWait(\$escapedMsg)
            Start-Sleep -Milliseconds 100

            # Enterキー（Windows改行: 2回送信で確実に実行）
            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
            Start-Sleep -Milliseconds 100
            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

            Write-Output 'SUCCESS'
        } catch {
            Write-Output ('ERROR: ' + \$_.Exception.Message)
            exit 1
        }
    " 2>&1 | tr -d '\r')

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

    # メッセージ送信
    if send_message_by_hwnd "$hwnd" "$message"; then
        log_send "$agent_name" "$message"
        echo "送信完了: $agent_name (HWND: $hwnd) に '$message'"
    else
        echo "ERROR: メッセージ送信に失敗しました"
        exit 1
    fi

    return 0
}

main "$@"
