---@type M0.Logger
local Logger = require 'm0.logger'

---@type M0.LLMAPIFactory
local LLMAPIFactory = require 'm0.llmapifactory'

---@type M0.Selector
local Selector = require 'm0.selector'

---@type M0.Utils
local Utils = require 'm0.utils'

---@alias backend_mode 'chat' | 'rewrite'

---@class Backend
---@field opts M0.BackendOptions
---@field chat fun(): nil
---@field rewrite fun(): nil

---@class State
---@field log_level integer?
---@field backend Backend?
---@field prompt string?
---@field prompt_name string?
---@field scan_project boolean?
---@field project_context string?

local M = {
  ---@type State
  State = {},
  ---@type M0.Config
  Config = require 'm0.config',
}
M.__index = M

---@type M0.VimBuffer
local VimBuffer = require 'm0.vimbuffer'

---@param API M0.LLMAPI The API handler.
---@param msg_buf M0.VimBuffer
---@param opts M0.BackendOptions
---@param state State
---@return Backend
local function make_backend(API, msg_buf, opts, state)
  local function make_curl_opts()
    local messages = msg_buf:get_messages()
    local body = API:make_body(messages)
    return {
      headers = API:make_headers(),
      body = vim.fn.json_encode(body),
    }
  end

  ---@return boolean success
  ---@return string? err
  local function scan_project()
    if state.scan_project ~= true then
      return true
    end
    -- If a scan of the project has been requested,
    -- re-scan on every turn, to catch code changes.
    -- FIXME: don't assume that cwd is project's root.
    local success, context =
      require('m0.scanproject'):get_context(vim.fn.getcwd())
    if not success then
      return false, 'Unable to scan project: ' .. context
    end
    state.project_context = context
    return true
  end

  ---@param mode backend_mode
  local function curl_stream_callback(mode)
    return vim.schedule_wrap(function(err, out, _job)
      M.Logger:log_trace(
        'Err: ' .. (err or '') .. '\nOut: ' .. (out or '')
        -- .. '\nJob: '
        -- .. (vim.inspect(_job) or '')
      )
      if err then
        M.Logger:log_error('Stream error: [' .. err .. '] [' .. out .. ']')
        return
      end
      -- When streaming, it seems the best chance to catch an API error
      -- is to parse stdout.
      if _job._stdout_results ~= {} then
        local json, _ = Utils:json_decode(_job._stdout_results)
        if json and json.error then
          M.Logger:log_error('Stream error: [' .. vim.inspect(json) .. ']')
          return
        end
      end

      local event, d = API:get_delta_text(out)
      if event == 'delta' then
        msg_buf:put_response(d)
      elseif event == 'error' then
        M.Logger:log_error(d)
      elseif event == 'stats' then
        M.Logger:log_info(d)
      elseif event == 'done' then
        msg_buf:close_buffer(mode)
      elseif d then
        M.Logger:log_trace('Unhandled stream results: ' .. d)
      end
    end)
  end

  ---@param mode backend_mode
  local function curl_callback(mode)
    return vim.schedule_wrap(function(out)
      if out and out.status and (out.status < 200 or out.status > 299) then
        M.Logger:log_error('Error in response: ' .. vim.inspect(out))
        return
      end

      local success, response, stats = API:get_response_text(out.body)
      if not success then
        M.Logger:log_error('Failed to parse response: ' .. vim.inspect(out))
        return
      end
      if response then
        msg_buf:put_response(response)
        msg_buf:close_buffer(mode)
      end
      if stats then
        M.Logger:log_info(stats)
      end
    end)
  end

  local function make_action(mode)
    return function()
      local success, err
      success, err = scan_project()
      if not success then
        M.Logger:log_error(err)
      end

      local curl_opts = make_curl_opts()

      if opts.stream == true then
        curl_opts.stream = curl_stream_callback(mode)
      else
        curl_opts.callback = curl_callback(mode)
      end

      -- close_buffer() is called by the callbacks.
      msg_buf:open_buffer(mode)
      local response = require('plenary.curl').post(opts.url, curl_opts)
      if not response then
        M.Logger:log_error 'Failed to obtain CuRL response.'
      end
    end
  end

  return {
    opts = opts,
    rewrite = make_action 'rewrite',
    chat = make_action 'chat',
  }
end

---Select backend interactively.
---@param backend_name string The name of the backend, as found in the user configuration.
---@return nil
function M:M0backend(backend_name)
  local msg_buf = VimBuffer:new(self.Config)
  -- Use deepcopy to avoid cluttering the configuration with backend-specific settings.
  local backend_opts = vim.deepcopy(self.Config.backends[backend_name])
  local provider_name = backend_opts.provider
  local provider_opts = vim.deepcopy(self.Config.providers[provider_name])
  local default_opts =
    vim.deepcopy(self.Config.defaults.providers[provider_name])

  if not backend_opts then
    self.Logger:log_error(
      "Backend '" .. backend_name .. "' not in configuration."
    )
    return
  end

  if not provider_opts then
    self.Logger:log_error(
      "Unable to find provider '"
        .. provider_name
        .. "' for backend '"
        .. backend_name
        .. "'."
    )
    return
  end

  -- Merge the defaults, provider opts, and backend opts.
  -- The former are overridden by the latter.
  backend_opts = vim.tbl_extend(
    'force',
    default_opts,
    provider_opts,
    backend_opts,
    { name = backend_name }
  )

  ---@type boolean,M0.LLMAPI|string
  local success, API =
    LLMAPIFactory.create(backend_opts.api_type, backend_opts, M.State)
  if not success then
    self.Logger:log_error(
      'Unable create API for ' .. backend_opts.api_type .. ': ' .. (API or '')
    )
    return
  end

  -- FIXME: constructor, maybe?
  self.State.backend = make_backend(API, msg_buf, backend_opts, M.State)
end

---Select prompt interactively.
---@param prompt_name string The name of the prompt, as found in the user configuration.
---@return nil
function M:M0prompt(prompt_name)
  if self.Config.prompts[prompt_name] == nil then
    self.Logger:log_error(
      "Prompt '" .. prompt_name .. "' not in configuration."
    )
    return
  end
  self.State.prompt_name = prompt_name
  self.State.prompt = self.Config.prompts[prompt_name]
end

---@return nil
function M:chat()
  M.State.backend.chat()
end
function M:rewrite()
  M.State.backend.rewrite()
end

---Returns printable debug information.
---@return string
function M:debug()
  return 'State:\n'
    .. vim.inspect(self.State)
    .. '\nConfiguration: '
    .. vim.inspect(self.Config)
end

--- Sets up the m0 plugin.
---@param user_config table The user configuration.
---@return nil
function M.setup(user_config)
  -- Merge user configuration, overriding defaults.
  M.Config = vim.tbl_extend('force', M.Config, user_config or {})

  -- Init the backend logger.
  M.State.log_level = M.Config.log_level or vim.log.levels.WARN
  M.Logger = Logger:new {
    log_level = M.State.log_level,
  }

  -- Sanity checks.
  local success, error = M.Config:validate()
  if not success then
    M.Logger:log_error(error)
    return
  end

  -- Activate defaults.
  M:M0prompt(M.Config.default_prompt_name)
  M:M0backend(M.Config.default_backend_name)

  -- Create keymaps.
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 backend)',
    ':M0 backend<CR>',
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n', 'v' },
    '<Plug>(M0 chat)',
    M.chat,
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 prompt)',
    ':M0 prompt<CR>',
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'v' },
    '<Plug>(M0 rewrite)',
    M.rewrite,
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 scan_project)',
    ':M0 scan_project<CR>',
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 info)',
    ':M0 info<CR>',
    { noremap = true, silent = true }
  )

  -- User commands
  -- See: https://github.com/nvim-neorocks/nvim-best-practices?tab=readme-ov-file
  -- -------------
  ---@class M0Subcommand
  ---@field impl fun(args:string[], opts: table) The command implementation
  ---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments

  ---@type table<string, M0Subcommand>
  local subcommand_tbl = {
    -- What backend to use.
    backend = {
      impl = function(_, _)
        -- The selector requires the items to be in the format
        -- {
        --   ( k = "foo", v = "bar" },
        --   ( k = "baz", v = "boz" },
        -- }
        local items = {}
        for k, v in pairs(M.Config.backends) do
          table.insert(items, { k = k, v = vim.inspect(v) })
        end
        Selector:make_selector(items, function(opts)
          M:M0backend(opts.ordinal)
        end)()
      end,
    },
    chat = {
      impl = M.chat,
    },
    info = {
      impl = function(_, _)
        local buf_id, err = require('m0.vimpopup'):popup(M:debug())
        if not buf_id then
          M.Logger:log_error(err or '')
        end
      end,
    },
    -- What prompt to use.
    prompt = {
      impl = function(_, _)
        -- The selector requires the items to be in the format
        -- {
        --   ( k = "foo", v = "bar" },
        --   ( k = "baz", v = "boz" },
        -- }
        local items = {}
        for k, v in pairs(M.Config.prompts) do
          table.insert(items, { k = k, v = v })
        end
        Selector:make_selector(items, function(opts)
          M:M0prompt(opts.ordinal)
        end)()
      end,
    },
    rewrite = {
      impl = M.rewrite,
    },
    -- Whether to scan the project for added context or not.
    scan_project = {
      impl = function(_, _)
        vim.ui.select(
          { 'on', 'off' },
          { prompt = 'Current: ' .. (M.State.scan_project and 'on' or 'off') },
          function(choice)
            if choice == 'on' then
              M.State.scan_project = true
            elseif choice == 'off' then
              M.State.scan_project = false
              M.State.project_context = nil
            end
          end
        )
      end,
    },
  }

  ---@param opts table See ':h lua-guide-commands-create'
  local function M0(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]
    -- Get the subcommand's args, if any.
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[subcommand_key]
    if not subcommand then
      M.Logger:log_error('M0: unknown command: ' .. subcommand_key)
      return
    end
    -- Invoke the subcommand.
    subcommand.impl(args, opts)
  end

  vim.api.nvim_create_user_command('M0', M0, {
    nargs = '+',
    desc = 'M0 command and subcommands',
    complete = function(arg_lead, cmdline, _)
      -- Get the subcommand.
      local subcmd_key, subcmd_arg_lead =
        cmdline:match "^['<,'>]*M0[!]*%s(%S+)%s(.*)$"
      if
        subcmd_key
        and subcmd_arg_lead
        and subcommand_tbl[subcmd_key]
        and subcommand_tbl[subcmd_key].complete
      then
        -- The subcommand has completions. Return them.
        return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
      end
      -- Check if cmdline is a subcommand
      if cmdline:match "^['<,'>]*M0[!]*%s+%w*$" then
        -- Filter subcommands that match
        local subcommand_keys = vim.tbl_keys(subcommand_tbl)
        return vim
          .iter(subcommand_keys)
          :filter(function(key)
            return key:find(arg_lead) ~= nil
          end)
          :totable()
      end
    end,
    bang = true, -- If you want to support !-modifiers
  })
end

return M
