# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

このリポジトリはAnsibleによる自動化を通じて開発環境のセットアップを管理するdotfilesリポジトリです。WSL（Windows Subsystem for Linux）に最適化された完全な開発環境を提供するように構成されています。

## インストールとセットアップコマンド

### 初回インストール
```bash
# リモートインストール（SSH鍵を生成し、すべてをセットアップ）
bash <(curl -sL https://raw.githubusercontent.com/taku-hatano/dotfiles/main/install.sh)

# ローカルセットアップ（リポジトリが既にクローンされている場合）
bash scripts/setup.sh
```

### Ansibleコマンド
```bash
# フルセットアップの実行
cd ansible
ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=$(whoami) --extra-vars ansible_exec_user_home=${HOME} ./site.yml

# タグを使用した特定のロールの実行
ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=$(whoami) --extra-vars ansible_exec_user_home=${HOME} ./site.yml --tags "apt,homebrew"
```

### 利用可能なAnsibleタグ
- `sudoers` - パスワードなしsudoの設定
- `apt` - システムパッケージのインストール
- `homebrew` - Homebrewとパッケージのインストール
- `ssh` - SSHサーバーの設定
- `links` - 設定ファイルのシンボリックリンク作成
- `docker` - Dockerのインストールと設定
- `zsh` - ZinitによるZshのセットアップ
- `mise` - miseツールバージョンマネージャーのインストール
- `rye` - Rye Pythonマネージャーのインストール
- `awscli` - AWS CLIのインストール
- `win32yank` - WSL用クリップボード統合のインストール

## アーキテクチャと主要コンポーネント

### 設定管理
- すべてのアプリケーション設定は`config/`ディレクトリに保存
- Ansibleの`links`ロールが`~/.config/`から`config/`サブディレクトリへのシンボリックリンクを作成
- ほとんどのツールでXDG Base Directory仕様に準拠

### ディレクトリ構造
```
config/           - アプリケーション設定ファイル
├── git/         - モジュラーconf.d/構造を持つGit設定
├── nvim/        - LuaによるNeovim設定
├── zsh/         - 関心事別に分割されたZsh設定
├── tmux/        - Tmux設定
├── starship/    - シェルプロンプト設定
└── zeno/        - インタラクティブコマンド補完スクリプト

ansible/         - 環境セットアップ用Ansible自動化
├── roles/       - 個別のセットアップロール（上記タグを参照）
├── site.yml     - すべてのロールを統括するメインPlaybook
└── vars/        - グローバル変数とXDGパス定義

scripts/         - セットアップとユーティリティスクリプト
```

### 主要な設計パターン

1. **モジュラー設定**: Git設定は`conf.d/`パターンを使用し、エイリアス、コア設定、delta、ユーザー設定を別ファイルに分離

2. **XDG準拠**: `ansible/vars/default.yml`の変数がロール全体で使用されるXDGパスを定義

3. **WSL最適化**: クリップボード（`win32yank`）、`xdg-open`へのシンボリックリンク、Windows統合の特別な処理

4. **ツールバージョン管理**: `config/mise/config.toml`の設定で言語ランタイム管理に`mise`を使用

### 重要なファイル
- `install.sh` - SSH鍵生成とリポジトリクローンを処理するエントリーポイントスクリプト
- `scripts/setup.sh` - Ansibleをインストールしてplaybookを実行するメインセットアップスクリプト
- `ansible/vars/default.yml` - パスとユーザーコンテキストを定義するグローバル変数
- `config/claude/CLAUDE.md` - 開発者固有のルールと規約（日本語）

## 開発ガイドライン

### ブランチ命名
- 利用可能な場合はJIRAチケットプレフィックスを使用: `JIRA-123-説明`
- GitHubイシュー番号を使用: `123-説明`
- それ以外の場合は説明的な名前を使用

### コミットメッセージ
- プロジェクト固有の規約がない場合は日本語で記述
- conventional commitフォーマットに従う: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`