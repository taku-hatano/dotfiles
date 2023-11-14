require("base")
require("plugins")

local has = vim.fn.has
local is_win = has "win32"
local is_wsl = has "wsl"

if is_win then
  require("windows")
end
if is_wsl then
  require("wsl")
end

vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "plugins.lua" },
    command = "PackerCompile",
})
