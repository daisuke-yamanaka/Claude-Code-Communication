# Claude Code エージェント通信システム

複数のAIが協力して働く、まるで会社のような開発システムです

## これは何？

**3行で説明すると：**
1. 複数のAIエージェント（社長・マネージャー・作業者）が協力して開発
2. それぞれ異なるターミナルウィンドウで動作し、メッセージを送り合う
3. 人間の組織のように役割分担して、効率的に開発を進める

**実際の成果：**
- 3時間で完成したアンケートシステム（EmotiFlow）
- 12個の革新的アイデアを生成
- 100%のテストカバレッジ

## 5分で動かしてみよう！

### 必要なもの
- **Windows** + **Git Bash** (Git for Windows)
- **Claude Code CLI**
- **PowerShell** (Windows標準搭載)

### 手順

#### 1. ダウンロード（30秒）
```bash
git clone https://github.com/nishimoto265/Claude-Code-Communication.git
cd Claude-Code-Communication
```

#### 2. 環境構築＆Claude起動（2分）
```bash
./setup.sh
```
これで5つのGit Bashウィンドウが開き、各ウィンドウでClaudeが自動起動します！
各ウィンドウでブラウザ認証を完了してください。

```
┌─────────────────────┐
│  Claude-president   │  ← 社長の画面
└─────────────────────┘

┌───────────┬───────────┐
│Claude-boss1│Claude-worker1│  ← それぞれ独立した
├───────────┼───────────┤     Git Bashウィンドウ
│Claude-worker2│Claude-worker3│
└───────────┴───────────┘
```

#### 3. 魔法の言葉を入力（30秒）

PRESIDENTウィンドウ（Claude-president）で入力：
```
あなたはpresidentです。おしゃれな充実したIT企業のホームページを作成して。
```

**すると自動的に：**
1. 社長がマネージャーに指示
2. マネージャーが3人の作業者に仕事を割り振り
3. みんなで協力して開発
4. 完成したら社長に報告

## 登場人物（エージェント）

### 社長（PRESIDENT）
- **役割**: 全体の方針を決める
- **特徴**: ユーザーの本当のニーズを理解する天才
- **ウィンドウ**: Claude-president

### マネージャー（boss1）
- **役割**: チームをまとめる中間管理職
- **特徴**: メンバーの創造性を引き出す達人
- **ウィンドウ**: Claude-boss1

### 作業者たち（worker1, 2, 3）
- **worker1**: デザイン担当（UI/UX） - Claude-worker1
- **worker2**: データ処理担当 - Claude-worker2
- **worker3**: テスト担当 - Claude-worker3

## どうやってコミュニケーションする？

### メッセージの送り方
```bash
./agent-send.sh [相手の名前] "[メッセージ]"

# 例：マネージャーに送る
./agent-send.sh boss1 "新しいプロジェクトです"

# 例：作業者1に送る
./agent-send.sh worker1 "UIを作ってください"
```

### 仕組み
PowerShell SendKeysを使用して、ウィンドウタイトルで対象を特定し、キー入力を自動送信します。

```
送信側: agent-send.sh boss1 "メッセージ"
         ↓
    PowerShell SendKeys で対象ウィンドウにキー送信
         ↓
受信側: boss1のGit Bashウィンドウ（タイトル: Claude-boss1）
    → Claude Codeに自動入力される
```

## 重要なファイルの説明

### 指示書（instructions/）
各エージェントの行動マニュアルです

- **president.md** - 社長の指示書
- **boss.md** - マネージャーの指示書
- **worker.md** - 作業者の指示書

### CLAUDE.md
システム全体の設定ファイル

### スクリプト
- **setup.sh** - 環境構築（5つのウィンドウ起動＆Claude自動起動）
- **agent-send.sh** - メッセージ送信
- **project-status.sh** - 進捗確認

## 困ったときは

### Q: ウィンドウが開かない
```bash
# Git for Windowsがインストールされているか確認
which mintty

# 手動でウィンドウを開く場合
mintty --title "Claude-boss1" &
```

### Q: メッセージが届かない
```bash
# ログを確認
cat logs/send_log.txt

# ウィンドウタイトルを確認
# 各ウィンドウのタイトルバーに「Claude-xxx」と表示されているか確認

# 手動でテスト
./agent-send.sh boss1 "テスト"
```

### Q: PowerShellエラーが出る
- PowerShellの実行ポリシーを確認
- 管理者権限でGit Bashを起動してみる

### Q: 最初からやり直したい
```bash
# 全ウィンドウを閉じて
rm -rf ./tmp/*
./setup.sh
```

## 自分のプロジェクトを作る

### 簡単な例：TODOアプリを作る

PRESIDENTウィンドウで入力：
```
あなたはpresidentです。
TODOアプリを作ってください。
シンプルで使いやすく、タスクの追加・削除・完了ができるものです。
```

すると自動的に：
1. マネージャーがタスクを分解
2. worker1がUI作成
3. worker2がデータ管理
4. worker3がテスト作成
5. 完成！

## システムの仕組み（図解）

### ウィンドウ構成
```
┌─────────────────┐
│ Claude-president │ ← 社長の画面（紫色プロンプト）
└─────────────────┘

各エージェントは独立したGit Bashウィンドウ：
┌────────────────┐  ┌────────────────┐
│ Claude-boss1   │  │ Claude-worker1 │
│ (赤プロンプト) │  │ (青プロンプト) │
└────────────────┘  └────────────────┘
┌────────────────┐  ┌────────────────┐
│ Claude-worker2 │  │ Claude-worker3 │
│ (青プロンプト) │  │ (青プロンプト) │
└────────────────┘  └────────────────┘
```

### コミュニケーションの流れ
```
社長
 ↓ 「ビジョンを実現して」
マネージャー
 ↓ 「みんな、アイデア出して」
作業者たち
 ↓ 「できました！」
マネージャー
 ↓ 「全員完了です」
社長
```

### 進捗管理の仕組み
```
./tmp/
├── worker1_done.txt     # 作業者1が完了したらできるファイル
├── worker2_done.txt     # 作業者2が完了したらできるファイル
├── worker3_done.txt     # 作業者3が完了したらできるファイル
└── worker*_progress.log # 進捗の記録
```

## なぜこれがすごいの？

### 従来の開発
```
人間 → AI → 結果
```

### このシステム
```
人間 → AI社長 → AIマネージャー → AI作業者×3 → 統合 → 結果
```

**メリット：**
- 並列処理で3倍速い
- 専門性を活かせる
- アイデアが豊富
- 品質が高い

## 技術的な詳細

### PowerShell SendKeysについて
- `AppActivate` でウィンドウをアクティブ化
- `SendKeys` でキー入力を送信
- 特殊文字（`+`, `^`, `%`, `{`, `}` など）は自動エスケープ

### ウィンドウタイトルの重要性
- 各ウィンドウに `Claude-[agent]` 形式の固有タイトルを設定
- 同名のウィンドウが複数あると誤動作の可能性あり

## まとめ

このシステムは、複数のAIが協力することで：
- **3時間**で本格的なWebアプリが完成
- **12個**の革新的アイデアを生成
- **100%**のテストカバレッジを実現

ぜひ試してみて、AIチームの力を体験してください！

---

**作者**: [GitHub](https://github.com/nishimoto265/Claude-Code-Communication)
**ライセンス**: MIT
**質問**: [Issues](https://github.com/nishimoto265/Claude-Code-Communication/issues)へどうぞ！

## 参考リンク

・Claude Code公式
  URL: https://docs.anthropic.com/ja/docs/claude-code/overview

・Akira-Papa/Claude-Code-Communication
  URL: https://github.com/Akira-Papa/Claude-Code-Communication

・【tmuxでClaude CodeのMaxプランでAI組織を動かし放題のローカル環境ができた〜〜〜！ので、やり方をシェア！！】 #AIエージェント - Qiita
  URL: https://qiita.com/akira_papa_AI/items/9f6c6605e925a88b9ac5

・Claude Code コマンドチートシート完全ガイド #ClaudeCode - Qiita
  URL: https://qiita.com/akira_papa_AI/items/d68782fbf03ffd9b2f43

※以下の情報を参考に、今回のClaude Code組織環境を構築することができました。本当にありがとうございました！

◇Claude Code双方向通信をシェルで一撃構築できるようにした発案者の元木さん
参考GitHub：
haconiwa/README_JA.md at main · dai-motoki/haconiwa
  URL: https://github.com/dai-motoki/haconiwa/blob/main/README_JA.md

・神威/KAMUI（@kamui_qai）さん / X
  URL: https://x.com/kamui_qai

◇簡単にClaude Code双方向通信環境を構築できるようシェアして頂いたダイコンさん
参考GitHub：
nishimoto265/Claude-Code-Communication
  URL: https://github.com/nishimoto265/Claude-Code-Communication

・ダイコン（@daikon265）さん / X
  URL: https://x.com/daikon265

◇Claude Code公式解説動画：
Mastering Claude Code in 30 minutes - YouTube
  URL: https://www.youtube.com/live/6eBSHbLKuN0?t=1356s
