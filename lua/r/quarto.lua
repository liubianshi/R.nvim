local M = {}

local Chunk = {}
Chunk.__index = Chunk

--- Constructor for the Chunk class
---@param content string The content of the code chunk.
---@param start_row integer The starting row of the code chunk.
---@param end_row integer The ending row of the code chunk.
---@param info_string_params table The parameters specified in the info string of the code chunk.
---@param comment_params table The parameters specified in the code chunk with #|
---@param lang string The language of the code chunk.
---@param code_block_node TSNode|nil The code block node.
---@return table
function Chunk:new(
    content,
    start_row,
    end_row,
    info_string_params,
    comment_params,
    lang,
    code_block_node
)
    local chunk = {
        content = content,
        start_row = start_row,
        end_row = end_row,
        info_string_params = info_string_params,
        comment_params = comment_params,
        lang = lang,
        code_block_node = code_block_node, -- not used yet, but could be useful in the future
    }

    setmetatable(chunk, Chunk)

    return chunk
end

--- Get the child parameter of the code chunk (a file name)
---@return string|nil
function Chunk:get_child_param()
    local child = self.comment_params and self.comment_params.child
        or self.info_string_params and self.info_string_params.child

    if child then
        child = vim.fs.normalize(child) -- Normalize path
        return child
    end

    return nil
end

--- Get the range of the code chunk
---@return integer,integer
function Chunk:get_range() return self.start_row, self.end_row end

--- Get the content of the code chunk
---@return string
function Chunk:get_content() return self.content end

--- Get the language of the code chunk
---@return string
function Chunk:get_lang() return self.lang end

--- Get the type of the code chunk
---@return string
function Chunk:get_chunk_section_at_cursor()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

    if
        (self.info_string_params.child or self.comment_params.child)
        and row == self.start_row
    then
        return "chunk_child"
    end

    if row == self.start_row then return "chunk_header" end

    if row == self.end_row then return "chunk_end" end

    return "chunk_body"
end

--- Get the info string parameters of the code chunk
---@return table
function Chunk:get_info_string_params() return self.info_string_params end
--- Get the comment parameters of the code chunk
---@return table
function Chunk:get_comment_params() return self.comment_params end

M.command = function(what)
    local config = require("r.config").get_config()
    local send_cmd = require("r.send").cmd
    if what == "stop" then
        send_cmd("quarto::quarto_preview_stop()")
        return
    end

    vim.cmd("update")
    local qa = what == "render" and config.quarto_render_args
        or config.quarto_preview_args
    local cmd = "quarto::quarto_"
        .. what
        .. '("'
        .. vim.fn.expand("%"):gsub("\\", "/")
        .. '"'
        .. qa
        .. ")"
    send_cmd(cmd)
end

--- Helper function to get code block from Rmd or Quarto document.
--- The function is called by cmp_r too.
---@param bufnr  integer The buffer number.
---@return table|nil
M.get_code_chunks = function(bufnr)
    local root = require("r.utils").get_root_node()
    if not root then return nil end

    local query = vim.treesitter.query.parse(
        "markdown",
        [[
                (fenced_code_block)
                     @fenced_code_block
            ]]
    )

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local code_chunks = {}

    for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]

        if capture_name == "fenced_code_block" then
            -- Loop through all children of the node and print their type and text
            local lang
            local info_string_params = {}
            local comment_params = {}
            local content_text = ""
            local start_row, _, end_row, _ = node:range()

            for child in node:iter_children() do
                if child:type() == "info_string" then
                    local info_string = vim.treesitter.get_node_text(child, bufnr)
                    lang, info_string_params = M.parse_info_string_params(info_string)
                end

                if child:type() == "code_fence_content" then
                    content_text = vim.treesitter.get_node_text(child, bufnr)

                    -- Get the parameters specified in the code chunk with #|
                    comment_params =
                        M.parse_comment_params(vim.treesitter.get_node_text(node, bufnr))
                end
            end

            -- Create the chunk object with the extracted information
            local chunk = Chunk:new(
                content_text,
                start_row + 1,
                end_row,
                info_string_params,
                comment_params,
                lang,
                node
            )

            table.insert(code_chunks, chunk)
        end
    end

    return code_chunks
end

local function unquote(str) return str and str:match("^['\"]?(.-)['\"]?$") or str end

--- Helper function to parse the info string of a code block
---@param info_string string The info string of the code block.
---@return string,table
M.parse_info_string_params = function(info_string)
    local params = {}

    if info_string == nil then return "", params end

    local lang = info_string:match("^%s*{?([^%s,{}]+)")
    if lang == nil then return "", params end

    local param_str = info_string:sub(#lang + 1):gsub("[{}]", "") -- Remove { and }
    local param_list = vim.split(param_str, ",")
    for _, param in ipairs(param_list) do
        local key, value = param:match("^%s*([^=]+)%s*=%s*([^%s]+)%s*$")

        if key and value then
            key = key:match("^%s*(.-)%s*$")
            value = value:match("^%s*(.-)%s*$")
            value = unquote(value)
            params[key] = value
        end
    end

    return lang, params
end

--- Helper function to parse the parameters specified in the code chunk with #|
---@param code_content string The content of the code chunk.
---@return table
M.parse_comment_params = function(code_content)
    local params = {}

    for line in code_content:gmatch("[^\r\n]+") do
        local key, value = line:match("^#|%s*([^:]+)%s*:%s*(.+)%s*$")
        if key and value then
            key = key:match("^%s*(.-)%s*$")
            value = value:match("^%s*(.-)%s*$")
            value = unquote(value)
            params[key] = value
        end
    end

    return params
end

--- This function gets the current code chunk based on the cursor position
---@param bufnr integer The buffer number.
---@return table
M.get_current_code_chunk = function(bufnr)
    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

    local chunks = M.get_code_chunks(bufnr)
    if not chunks then return {} end

    for _, chunk in ipairs(chunks) do
        local chunk_start_row, chunk_end_row = chunk:get_range()
        if row >= chunk_start_row and row <= chunk_end_row then return chunk end
    end

    return {}
end

-- Function to get all code chunks above the current cursor position
---@param bufnr integer The buffer number.
---@return table
M.get_chunks_above_cursor = function(bufnr)
    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

    local chunks = M.get_code_chunks(bufnr)

    if not chunks then return {} end

    local chunks_above = {}

    for _, chunk in ipairs(chunks) do
        local _, chunk_end_row = chunk:get_range()

        if chunk_end_row < row then table.insert(chunks_above, chunk) end
    end

    return chunks_above
end

-- Function to get all code chunks below the current cursor position
---@param bufnr integer The buffer number.
---@return table
M.get_chunks_below_cursor = function(bufnr)
    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

    local chunks = M.get_code_chunks(bufnr)

    if not chunks then return {} end

    local chunks_below = {}

    for _, chunk in ipairs(chunks) do
        local chunk_start_row, _ = chunk:get_range()

        if chunk_start_row > row then table.insert(chunks_below, chunk) end
    end

    return chunks_below
end

--- This function gets the supported languages for code execution
---@return string[]
M.get_supported_chunk_langs = function() return { "r", "webr", "python", "pyodide" } end

--- This function filters the code chunks based on the supported languages
---@param chunks table The code chunks.
---@return table The filtered code chunks.
M.filter_supported_langs = function(chunks)
    if type(chunks) ~= "table" or vim.tbl_isempty(chunks) then return {} end

    -- If chunks is a single chunk (table), wrap it in a table to ensure uniform processing
    if type(chunks) ~= "table" or (type(chunks) == "table" and #chunks == 0) then
        chunks = { chunks }
    end

    local supported_chunks = {}
    local supported_langs = M.get_supported_chunk_langs()
    for _, chunk in ipairs(chunks) do
        if vim.tbl_contains(supported_langs, chunk.lang) then
            table.insert(supported_chunks, chunk)
        end
    end
    return supported_chunks
end

--- This function checks if a language is supported
---@param lang string
---@return boolean
M.is_supported_lang = function(lang) return M.is_r(lang) or M.is_python(lang) end

--- This function checks if a language is either "r" or "webr"
---@param lang string
---@return boolean
M.is_r = function(lang)
    local r_langs = { r = true, webr = true }
    return r_langs[lang] or false
end

--- This function checks if a language is "python"
---@param lang string
---@return boolean
M.is_python = function(lang)
    local python_langs = { python = true, pyodide = true }
    return python_langs[lang] or false
end

--- This function filters the code chunks based on the eval parameter. If the eval parameter is not found it is assumed to be true
---@param chunks table
---@return table
M.filter_code_chunks_by_eval = function(chunks)
    if type(chunks) ~= "table" or vim.tbl_isempty(chunks) then return {} end

    -- If chunks is a single chunk (table), wrap it in a table to ensure uniform processing
    if type(chunks) ~= "table" or (type(chunks) == "table" and #chunks == 0) then
        chunks = { chunks }
    end

    return vim.tbl_filter(function(chunk)
        if type(chunk) ~= "table" then
            return false -- Skip this chunk if it’s not a table
        end

        -- Default eval is true if not provided
        local eval = true

        -- Check for eval in comment_params
        if chunk:get_comment_params() and chunk:get_comment_params().eval then
            eval = chunk:get_comment_params().eval ~= "false"
        -- Check for eval in info_string_params
        elseif chunk:get_info_string_params() and chunk:get_info_string_params().eval then
            eval = chunk:get_info_string_params().eval ~= "FALSE"
        end

        return eval -- Return true if eval is "true"
    end, chunks)
end

--- Formats the code chunks into a list of code lines that can be executed in
--- R. The code lines are formatted based on the language of the code chunk. If
--- the language is python, the code line is wrapped in
--- reticulate::py_run_string. If the language is R, the code line is returned
--- as is.
---@param chunks table The code chunks.
---@return table
M.codelines_from_chunks = function(chunks)
    local codelines = {}

    for _, chunk in ipairs(chunks) do
        local lang = chunk:get_lang()
        local content = chunk:get_content()
        if M.is_python(lang) then
            content = 'reticulate::py_run_string(r"(' .. content .. ')")'
        end
        if M.is_python(lang) or M.is_r(lang) then
            local lines = vim.fn.split(content, "\n")
            for _, v in pairs(lines) do
                table.insert(codelines, v)
            end
        end
    end

    return codelines
end

local ns = vim.api.nvim_create_namespace("RQuartoNamespace")

--- Special highlight for Quarto and Rmd code blocks
M.hl_code_bg = function()
    local config = require("r.config").get_config()
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local chunks = M.get_code_chunks(0)
    if not chunks then return end
    for _, c in pairs(chunks) do
        local hl_grp = "RCodeBlock"
        if
            (c.info_string_params.eval and c.info_string_params.eval == "FALSE")
            or (c.comment_params.eval and c.comment_params.eval == "false")
        then
            hl_grp = "RCodeComment"
        end
        vim.api.nvim_buf_set_extmark(0, ns, c.start_row - 1, 0, {
            end_col = 0,
            end_row = c.end_row,
            hl_group = hl_grp,
            virt_text = (c.lang and config.quarto_chunk_hl.virtual_title) and {
                { c.lang .. " ", { hl_grp, "Title" } },
            } or nil,
            virt_text_pos = "right_align",
            hl_eol = true,
        })
        if c.info_string_params.child or c.comment_params.child then
            for i = c.start_row, c.end_row - 2, 1 do
                local line = vim.api.nvim_buf_get_lines(0, i, i + 1, true)[1]
                if not line:find("#| child:") then
                    vim.api.nvim_buf_set_extmark(0, ns, i, 0, {
                        end_col = 0,
                        end_row = i + 1,
                        hl_group = "RCodeIgnore",
                        hl_eol = true,
                    })
                end
            end
        end
    end
end

return M
