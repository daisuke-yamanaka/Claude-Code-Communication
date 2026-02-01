#!/bin/bash

# Agent間メッセージ送信スクリプト (Git Bash版)
# PowerShell SendKeysを使用してウィンドウにキー入力を送信

# エージェント→ウィンドウタイトル マッピング
get_window_title() {
    case "$1" in
        "president") echo "Claude-president" ;;
        "boss1") echo "Claude-boss1" ;;
        "worker1") echo "Claude-worker1" ;;
        "worker2") echo "Claude-worker2" ;;
        "worker3") echo "Claude-worker3" ;;
        *) echo "" ;;
    esac
}

show_usage() {
    cat << EOF
Agent間メッセージ送信 (Git Bash版)

使用方法:
  $0 [エージェント名] [メッセージ]
  $0 --list

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
EOF
}

# エージェント一覧表示
show_agents() {
    echo "利用可能なエージェント:"
    echo "=========================="
    echo "  president → Claude-president   (プロジェクト統括責任者)"
    echo "  boss1     → Claude-boss1       (チームリーダー)"
    echo "  worker1   → Claude-worker1     (実行担当者A)"
    echo "  worker2   → Claude-worker2     (実行担当者B)"
    echo "  worker3   → Claude-worker3     (実行担当者C)"
}

# ログ記録
log_send() {
    local agent="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p logs
    echo "[$timestamp] $agent: SENT - \"$message\"" >> logs/send_log.txt
}

# SendKeys用に特殊文字をエスケープ
escape_for_sendkeys() {
    local text="$1"
    # SendKeysの特殊文字をエスケープ: + ^ % ~ { } [ ] ( )
    text="${text//\{/\{\{\}}"
    text="${text//\}/\{\}\}}"
    text="${text//\+/\{+\}}"
    text="${text//\^/\{^\}}"
    text="${text//%/\{%\}}"
    text="${text//~/\{~\}}"
    text="${text//\(/\{(\}}"
    text="${text//\)/\{)\}}"
    text="${text//\[/\{[\}}"
    text="${text//\]/\{]\}}"
    echo "$text"
}

# メッセージ送信
send_message() {
    local title="$1"
    local message="$2"

    echo "送信中: $title <- '$message'"

    # メッセージをエスケープ
    local escaped_message
    escaped_message=$(escape_for_sendkeys "$message")

    # PowerShellでキー送信
    powershell.exe -Command "
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName Microsoft.VisualBasic

        \$wshell = New-Object -ComObject wscript.shell

        # ウィンドウをアクティブ化
        \$activated = \$wshell.AppActivate('$title')
        if (-not \$activated) {
            Write-Host 'ERROR: Window not found: $title'
            exit 1
        }
        Start-Sleep -Milliseconds 300

        # Ctrl+C で現在の入力をクリア
        [System.Windows.Forms.SendKeys]::SendWait('^c')
        Start-Sleep -Milliseconds 200

        # メッセージを送信
        [System.Windows.Forms.SendKeys]::SendWait('$escaped_message')
        Start-Sleep -Milliseconds 100

        # Enterキー
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    " 2>/dev/null

    return $?
}

# ウィンドウ存在確認
check_window() {
    local title="$1"

    # PowerShellでウィンドウを検索
    local result
    result=$(powershell.exe -Command "
        Add-Type -AssemblyName Microsoft.VisualBasic
        \$wshell = New-Object -ComObject wscript.shell
        if (\$wshell.AppActivate('$title')) {
            Write-Output 'FOUND'
        } else {
            Write-Output 'NOT_FOUND'
        }
    " 2>/dev/null)

    if [[ "$result" == *"NOT_FOUND"* ]]; then
        echo "ERROR: ウィンドウ '$title' が見つかりません"
        echo "  先に ./setup.sh を実行してウィンドウを起動してください"
        return 1
    fi

    return 0
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

    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi

    local agent_name="$1"
    local message="$2"

    # ウィンドウタイトル取得
    local title
    title=$(get_window_title "$agent_name")

    if [[ -z "$title" ]]; then
        echo "ERROR: 不明なエージェント '$agent_name'"
        echo "利用可能エージェント: $0 --list"
        exit 1
    fi

    # ウィンドウ確認
    if ! check_window "$title"; then
        exit 1
    fi

    # メッセージ送信
    if send_message "$title" "$message"; then
        # ログ記録
        log_send "$agent_name" "$message"
        echo "送信完了: $agent_name に '$message'"
    else
        echo "ERROR: メッセージ送信に失敗しました"
        exit 1
    fi

    return 0
}

main "$@"
