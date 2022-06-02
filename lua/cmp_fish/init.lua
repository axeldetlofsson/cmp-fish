local source = {}

source.new = function()
      return setmetatable({}, { __index = source })
end
local shell = {}

function shell.escape(args)
    local ret = {}
    for _, a in pairs(args) do
        s = tostring(a)
        if s:match("[^A-Za-z0-9_/:=-]") then
            s = "'" .. s:gsub("'", "'\\''") .. "'"
        end
        table.insert(ret, s)
    end
    return table.concat(ret, " ")
end

function shell.run(args)
    local h = io.popen(shell.escape(args))
    if h then
        local outstr = h:read("*a")
        return h:close(), outstr
            else
        return nil
    end
end

local function split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end


---Return this source is available in current context or not. (Optional)
---@return boolean
function source:is_available()
    local filetype = vim.api.nvim_buf_get_option(0, 'filetype')
    return filetype == 'fish'
end

---Return the debug name of this source. (Optional)
---@return string
function source:get_debug_name() return 'fish' end

---Return keyword pattern for triggering completion. (Optional)
---If this is ommited, nvim-cmp will use default keyword pattern. See |cmp-config.completion.keyword_pattern|
---@return string
function source:get_keyword_pattern() return [[\k\+]] end

---Return trigger characters for triggering completion. (Optional)
function source:get_trigger_characters() return {'.', '-', '/', '$', ' '} end

---Invoke completion. (Required)
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)

function source:complete(params, callback)
    local completions = {}

    if params.context.cursor_before_line ~= nil then
        local cwd = vim.fn.getcwd()
        local sub_string = params.context.cursor_before_line:gsub("^%s*", "")

        if sub_string:sub(1, 1) == '-' or sub_string == nil or sub_string == "" then
            callback(completions)
            return
        end

        local quote_char = "'"
        local contain_quote = sub_string:match("[\"|']")

        if contain_quote and contain_quote == "'" then quote_char = '"' end

        local _, output = shell.run {
            "fish", "-C", 'cd ' .. cwd, "-c",
            "complete -C --escape " .. quote_char .. sub_string .. quote_char
            }

        if output ~= nil then
            local lines = split(output, "\n")
            for i, line in ipairs(lines) do
                if line ~= "" then
                    local parts = split(line, "\t")
                    local completion = {label = parts[1], detail = parts[2]}
                    table.insert(completions, completion)
                end
            end
        end
    end
    callback(completions)
end

---Resolve completion item. (Optional)
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
    callback(completion_item)
end

---Execute command after item was accepted.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback) callback(completion_item) end

---Register custom source to nvim-cmp.
return source
