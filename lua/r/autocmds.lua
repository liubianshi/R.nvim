local C = require("r.config")
local P = require("r.packages")
local U = require("r.utils")
local M = {}

-- auto update packages based on buffer lines
M.update_compl_packages = function()
    local compl_method = C.get_option("compl_method")
    if not compl_method or compl_method ~= "buffer" then return end

    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("RNVIM_update_packages", { clear = true }),
        callback = function(ev)
            local ft = vim.bo[ev.buf].filetype
            local ok, R_filetypes = pcall(vim.api.nvim_get_var, "R_filetypes")
            if not ok then R_filetypes = { "r", "rnoweb", "rmd", "quarto" } end
            if not vim.tbl_contains(R_filetypes, ft) or ft == "rhelp" then return end
            local packages = U.extract_packages_from_buffer(ev.buf)
            P.update_compl_packages(packages)
        end,
    })
end

return M
