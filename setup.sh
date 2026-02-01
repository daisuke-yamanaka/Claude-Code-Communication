#!/bin/bash

# Multi-Agent Communication Demo 環境構築 (Git Bash版)
# 各エージェント用のGit Bashウィンドウを起動

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

echo "Multi-Agent Communication Demo 環境構築 (Git Bash版)"
echo "======================================================"
echo ""

# STEP 1: ディレクトリ準備
log_info "ディレクトリ準備中..."

mkdir -p ./tmp ./logs ./messages
rm -f ./tmp/worker*_done.txt 2>/dev/null && log_info "既存の完了ファイルをクリア" || true

log_success "ディレクトリ準備完了"
echo ""

# STEP 2: minttyのパス確認
log_info "Git Bash (mintty) パス確認中..."

# 可能なminttyのパス
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
    log_warning "mintty.exe が見つかりません"
    log_warning "Git for Windows がインストールされていることを確認してください"
    exit 1
fi

log_info "mintty found: $MINTTY_PATH"
echo ""

# 作業ディレクトリ（Windows形式に変換）
WORK_DIR=$(pwd)
WORK_DIR_WIN=$(cygpath -w "$WORK_DIR" 2>/dev/null || echo "$WORK_DIR")

# STEP 3: 各エージェント用ウィンドウを起動
log_info "エージェントウィンドウを起動中..."

# エージェント定義（名前と表示色）
declare -A AGENT_COLORS=(
    ["president"]="135"   # 紫
    ["boss1"]="196"       # 赤
    ["worker1"]="33"      # 青
    ["worker2"]="33"      # 青
    ["worker3"]="33"      # 青
)

AGENTS=("president" "boss1" "worker1" "worker2" "worker3")

for agent in "${AGENTS[@]}"; do
    title="Claude-${agent}"
    color="${AGENT_COLORS[$agent]}"

    log_info "$agent ウィンドウを起動中 (タイトル: $title)..."

    # minttyを起動（タイトル設定付き）
    "$MINTTY_PATH" --title "$title" --size 120,30 --exec /bin/bash -c "
        cd '$WORK_DIR'

        # カラープロンプト設定
        export PS1='(\[\033[38;5;${color}m\]${agent}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '

        # ウェルカムメッセージ
        echo ''
        echo '==================================='
        echo '  $agent エージェント'
        echo '==================================='
        echo ''
        echo 'Claudeを起動するには以下を実行:'
        echo '  claude --dangerously-skip-permissions'
        echo ''

        exec bash
    " &

    sleep 0.5
done

log_success "全ウィンドウの起動完了"
echo ""

# STEP 4: 環境確認・表示
echo ""
echo "セットアップ結果:"
echo "==================="
echo ""
echo "起動したウィンドウ:"
echo "  Claude-president   (プロジェクト統括責任者)"
echo "  Claude-boss1       (チームリーダー)"
echo "  Claude-worker1     (実行担当者A)"
echo "  Claude-worker2     (実行担当者B)"
echo "  Claude-worker3     (実行担当者C)"
echo ""
echo "ウィンドウ構成:"
echo "  各エージェントは独立したGit Bashウィンドウで動作します"
echo ""

log_success "Demo環境セットアップ完了！"
echo ""
echo "次のステップ:"
echo "  1. 全エージェントでClaude起動:"
echo "     ./launch-agents.sh"
echo ""
echo "  2. 手動で起動する場合:"
echo "     各ウィンドウで 'claude --dangerously-skip-permissions' を実行"
echo "     ※ ブラウザ認証が必要な場合があります"
echo ""
echo "  3. メッセージ送信テスト:"
echo "     ./agent-send.sh boss1 \"テストメッセージ\""
echo ""
echo "  4. デモ実行:"
echo "     PRESIDENTウィンドウに「あなたはpresidentです。指示書に従って」と入力"
