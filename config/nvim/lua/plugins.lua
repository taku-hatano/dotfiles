-- packer.nvimのインストール
local ensure_packer = function()
	local fn = vim.fn
	local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
	if fn.empty(fn.glob(install_path)) > 0 then
		fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
		vim.cmd [[packadd packer.nvim]]
		return true
	end
	return false
end

local packer_bootstrap = ensure_packer()

local packer = require('packer')

vim.cmd [[packadd packer.nvim]]
packer.init({
	display = {
		open_fn = require("packer.util").float,
	},
})
packer.startup(function()
  -- Package Manager
	use 'wbthomason/packer.nvim'

  -- Lua Library
  use "nvim-lua/popup.nvim"
  use "nvim-lua/plenary.nvim"
  use "kkharji/sqlite.lua"
  use "nvim-tree/nvim-web-devicons"

  -- Treesitter
	use {
		'nvim-treesitter/nvim-treesitter',
        event = { "BufReadPost" },
		run = function()
			local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
			ts_update()
		end,
	}
  use {
    "lukas-reineke/indent-blankline.nvim",
    event = "VimEnter",
    config = function()
      require("indent_blankline").setup({
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
      })
    end
  }

	-- Colorscheme
	use { 
		'EdenEast/nightfox.nvim',
        event = { "BufReadPre", "BufWinEnter" },
		config = function()
			vim.cmd("colorscheme nightfox")
		end
	}

	-- Statusline
	use {
		"nvim-lualine/lualine.nvim",
        event = "VimEnter",
		config = function()
			require("rc/lualine")
		end
	}
	-- Bufferline
	use {
		"akinsho/bufferline.nvim",
        event = "VimEnter",
		config = function()
			require("rc/bufferline")
		end
	}

    -- Autopair
    use {
        "windwp/nvim-autopairs",
        config = function()
            require("nvim-autopairs").setup({})
        end
    }

    -- FuzzyFinder
    use {
        "nvim-telescope/telescope.nvim",
        event = { "VimEnter" },
        config = function()
            vim.api.nvim_set_keymap("n", "<Leader>ff", "<Cmd>Telescope find_files<CR>", { noremap = true, silent = true })
            vim.api.nvim_set_keymap("n", "<Leader>fg", "<Cmd>Telescope live_grep<CR>", { noremap = true, silent = true })
        end
    }
end)
