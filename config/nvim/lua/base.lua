vim.cmd("autocmd!")

-- Leader
vim.g.mapleader = " "

-- エンコーディング
vim.opt.encoding = "utf-8"

-- 行や列のハイライト
vim.opt.cursorline = true
vim.opt.cursorcolumn = false 

-- インデントの設定
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.list = true
vim.opt.listchars:append("space:⋅")
vim.opt.listchars:append("tab:>-")

-- 行番号の表示
vim.opt.number = true
vim.opt.relativenumber = true

-- 検索時の大文字小文字の無視
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- 検索時のハイライト
vim.opt.hlsearch = true
-- インクリメンタルサーチ
vim.opt.incsearch = true

-- 長い行を折り返す
vim.opt.wrap = true

-- 入力中のコマンドを表示
vim.opt.showcmd = true

-- TrueColorの設定
vim.opt.termguicolors = true

-- floating windowの設定
vim.opt.pumblend = 10
vim.opt.winblend = 10

-- yankしたときにハイライト
vim.cmd [[
	augroup highlight_yank
		autocmd!
		autocmd TextYankPost * silent! lua vim.highlight.on_yank({higroup="Visual", timeout=100})
	augroup END
]]
