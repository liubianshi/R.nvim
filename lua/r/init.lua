local M = {}

--- Quick setup: simply store user options
---@param opts? RConfigUserOpts
M.setup = function(opts)
    if opts then require("r.config").store_user_opts(opts) end
    require("r.autocmds").update_compl_packages()
end

return M
