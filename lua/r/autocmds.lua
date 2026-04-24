local M = {}

local function r_filetypes()
    local ok, ft = pcall(vim.api.nvim_get_var, "R_filetypes")
    if not ok then ft = { "r", "rnoweb", "rmd", "quarto" } end
    return ft
end

--- Refresh the libnames file whenever the user saves an R-flavoured buffer,
--- so that newly added `library()` / `require()` / `box::use()` calls become
--- visible to rnvimserver on its next start. Opt-in via `compl_method = "buffer"`.
M.setup = function()
    local config = require("r.config").get_config()
    if config.compl_method ~= "buffer" then return end

    vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("RNVIM_update_packages", { clear = true }),
        callback = function(ev)
            local ft = vim.bo[ev.buf].filetype
            if ft == "rhelp" or not vim.tbl_contains(r_filetypes(), ft) then
                return
            end
            require("r.server").refresh_libnames_file()
        end,
    })
end

return M
