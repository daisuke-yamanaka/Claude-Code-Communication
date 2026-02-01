#!/bin/bash

# AIエージェント一括起動スクリプト (Git Bash版)
# PowerShell SendKeysで全エージェントにClaude起動コマンドを送信

set -e  # エラー時に停止

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

echo "AIエージェント一括起動 (Git Bash版)"
echo "===================================="
echo ""

# ウィンドウ存在確認
check_window() {
    local title="$1"

    local result
    result=$(powershell.exe -Command "
        \$wshell = New-Object -ComObject wscript.shell
        if (\$wshell.AppActivate('$title')) {
            Write-Output 'FOUND'
        } else {
            Write-Output 'NOT_FOUND'
        }
    " 2>/dev/null)

    if [[ "$result" == *"NOT_FOUND"* ]]; then
        return 1
    fi
    return 0
}

# 全ウィンドウ確認
check_all_windows() {
    local all_exist=true
    local agents=("president" "boss1" "worker1" "worker2" "worker3")

    for agent in "${agents[@]}"; do
        local title="Claude-${agent}"
        if ! check_window "$title"; then
            log_warning "$title ウィンドウが見つかりません"
            all_exist=false
        fi
    done

    if [ "$all_exist" = false ]; then
        echo ""
        log_error "必要なウィンドウが見つかりません"
        echo "   先に ./setup.sh を実行してください"
        exit 1
    fi
}

# エージェント起動関数
launch_agent() {
    local agent=$1
    local title="Claude-${agent}"

    log_info "$agent を起動中..."

    # PowerShellでキー送信
    powershell.exe -Command "
        Add-Type -AssemblyName System.Windows.Forms

        \$wshell = New-Object -ComObject wscript.shell

        # ウィンドウをアクティブ化
        \$wshell.AppActivate('$title')
        Start-Sleep -Milliseconds 300

        # コマンド入力
        [System.Windows.Forms.SendKeys]::SendWait('claude --dangerously-skip-permissions')
        Start-Sleep -Milliseconds 100

        # Enter
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    " 2>/dev/null

    sleep 1
}

# メイン処理
main() {
    # ウィンドウ確認
    log_info "ウィンドウ確認中..."
    check_all_windows
    log_success "全ウィンドウ確認完了"
    echo ""

    echo "起動するエージェント:"
    echo "  - PRESIDENT (統括責任者)"
    echo "  - boss1 (チームリーダー)"
    echo "  - worker1, 2, 3 (実行担当者)"
    echo ""

    # 起動確認
    read -p "全エージェントを起動しますか？ (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "キャンセルしました"
        exit 0
    fi

    echo ""
    log_info "起動を開始します..."
    echo ""

    # 各エージェント起動
    launch_agent "president"
    launch_agent "boss1"
    launch_agent "worker1"
    launch_agent "worker2"
    launch_agent "worker3"

    echo ""
    log_success "全エージェントの起動コマンドを送信しました"
    echo ""
    echo "次のステップ:"
    echo "  1. 各ウィンドウでブラウザ認証を完了してください"
    echo "  2. PRESIDENTに指示を送信:"
    echo "     ./agent-send.sh president \"あなたはpresidentです。[プロジェクト内容]\""
    echo ""
    echo "ウィンドウタイトルで確認:"
    echo "  Claude-president    (社長画面)"
    echo "  Claude-boss1        (マネージャー画面)"
    echo "  Claude-worker1/2/3  (作業者画面)"
}

# 実行
main "$@"
