# Agent Communication System

## エージェント構成
- **PRESIDENT** (Claude-president): 統括責任者
- **boss1** (Claude-boss1): チームリーダー
- **worker1,2,3** (Claude-worker1/2/3): 実行担当

## あなたの役割
- **PRESIDENT**: @instructions/president.md
- **boss1**: @instructions/boss.md
- **worker1,2,3**: @instructions/worker.md

## メッセージ送信
```bash
./agent-send.sh [相手] "[メッセージ]"
```

## 基本フロー
PRESIDENT → boss1 → workers → boss1 → PRESIDENT

## ウィンドウ構成 (Git Bash版)
各エージェントは独立したGit Bashウィンドウで動作します。
ウィンドウタイトルで識別されます：
- Claude-president
- Claude-boss1
- Claude-worker1
- Claude-worker2
- Claude-worker3
