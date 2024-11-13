local Config = require 'm0.config'
local LLMAPIFactory = require 'm0.API.llmapifactory'
local Logger = require 'm0.logger'
local Selector = require 'm0.selector'
local Utils = require 'm0.utils'

---@alias backend_mode 'chat' | 'rewrite'

---@class Backend
---@field opts M0.BackendOptions
---@field API? M0.API.LLMAPI
---@field mode? backend_mode

---@class State
---@field log_level? integer
---@field backend? Backend
---@field prompt? string
---@field prompt_name? string
---@field scan_project? boolean
---@field sidebar? table
---@field project_context? string

---@class M0
---@field state State
---@field config M0.Config
---@field setup fun(user_config:table)
---@field logger? M0.Logger
---@field private scan_project fun(self:M0):boolean,string?
---@field private make_curl_opts fun(self:M0):table
---@field private curl_callback fun(self:M0):fun(out:string)
---@field private curl_stream_callback fun(self:M0):fun(err:string,out:string,_job:table)
---@field private interact fun(self:M0)
---@field private chat fun(self:M0)
---@field private rewrite fun(self:M0)
---@field private init_logger fun(self:M0, log_level:integer)
---@field private setup_user_commands fun()
local M = {
  state = {},
}
M.__index = M

---@return boolean Success
---@return string? Error
local function scan_project(self)
  if self.state.scan_project ~= true then
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
  self.state.project_context = context
  return true
end

---@param self M0
---@return table
local function make_curl_opts(self)
  local messages = self.msg_buf:get_messages()
  local body = self.state.backend.API:make_body(messages)
  return {
    headers = self.state.backend.API:make_headers(),
    body = vim.json.encode(body),
  }
end

---Returns a non-streaming callback.
---@param self M0
---@return fun(out:string)
local function curl_callback(self)
  return vim.schedule_wrap(function(out)
    if out and out.status and (out.status < 200 or out.status > 299) then
      self.logger:log_error('Error in response: ' .. vim.inspect(out))
      return
    end

    local success, response, stats =
      self.state.backend.API:get_response_text(out.body)
    if not success then
      self.logger:log_error('Failed to parse response: ' .. vim.inspect(out))
      return
    end
    if response then
      self.msg_buf:put_response(response)
      self.msg_buf:close_buffer()
    end
    if stats then
      self.logger:log_info(stats)
    end
  end)
end

---Returns a streaming callback.
---@param self M0
---@return fun(err:string, data:string, _job:table)
local function curl_stream_callback(self)
  return vim.schedule_wrap(function(err, data, _job)
    self.logger:log_trace('Err: ' .. (err or '') .. '\nOut: ' .. (data or ''))
    if err then
      self.logger:log_error(
        'Stream error: [' .. err .. '] [' .. (data or '') .. ']'
      )
      return
    end
    -- When streaming, it seems the best chance to catch an API error
    -- is to parse stdout.
    if _job._stdout_results ~= {} then
      local json, _ = Utils:json_decode(_job._stdout_results)
      if json and json.error then
        self.logger:log_error('Stream error: [' .. vim.inspect(json) .. ']')
        return
      end
    end

    local success, msg = self.state.backend.API:stream(data, {
      on_delta = function(d)
        self.msg_buf:open_buffer(self.state.backend.mode)
        self.msg_buf:put_response(d)
      end,
      on_done = function()
        self.msg_buf:close_buffer()
      end,
      on_stats = function(d)
        self.logger:log_info(d)
      end,
      on_cruft = function(d)
        self.logger:log_trace('Unhandled stream results: ' .. d)
      end,
    })
    if not success then
      self.logger:log_error(msg)
      self.msg_buf:close_buffer()
    end
  end)
end

---Interacts with the current provider/model.
---
local function interact(self)
  local success, err = scan_project(self)
  if not success then
    self.logger:log_error(err)
  end

  local curl_opts = make_curl_opts(self)

  -- Set callbacks.
  if self.state.backend.opts.stream == true then
    curl_opts.stream = curl_stream_callback(self)
  else
    curl_opts.callback = curl_callback(self)
  end

  local response =
    require('plenary.curl').post(self.state.backend.opts.url, curl_opts)
  if not response then
    self.logger:log_error 'Failed to obtain CuRL response.'
  end
end

---Select backend interactively.
---@param backend_name string The name of the backend, as found in the user configuration.
function M:M0backend(backend_name)
  self.msg_buf = require('m0.vimbuffer'):new(self.config)
  -- Use deepcopy to avoid cluttering the configuration with backend-specific settings.
  local backend_opts = vim.deepcopy(self.config.backends[backend_name])
  local provider_name = backend_opts.provider
  local provider_opts = vim.deepcopy(self.config.providers[provider_name])
  local default_opts =
    vim.deepcopy(self.config.defaults.providers[provider_name])

  if not backend_opts then
    self.logger:log_error(
      "Backend '" .. backend_name .. "' not in configuration."
    )
    return
  end

  if not provider_opts then
    self.logger:log_error(
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

  local success, API =
    LLMAPIFactory.create(backend_opts.api_type, backend_opts, M.state)
  if not success then
    self.logger:log_error(
      'Unable create API for '
        .. backend_opts.api_type
        .. ': '
        .. (API.error or '')
    )
    return
  end

  self.state.backend = {
    opts = backend_opts,
    API = API,
  }
end

--FIXME: harmonize method signature.
---Select prompt interactively.
---@param prompt_name string The name of the prompt, as found in the user configuration.
function M:M0prompt(prompt_name)
  if self.config.prompts[prompt_name] == nil then
    self.logger:log_error(
      "Prompt '" .. prompt_name .. "' not in configuration."
    )
    return
  end
  self.state.prompt_name = prompt_name
  self.state.prompt = self.config.prompts[prompt_name]
end

function M.chat()
  M.state.backend.mode = 'chat'
  interact(M)
end

function M.rewrite()
  M.state.backend.mode = 'rewrite'
  interact(M)
end

function M:toggle_sidebar()
  if not M.state.sidebar then
    M.state.sidebar = require 'm0.sidebar'
  end
  M.state.sidebar:toggle_sidebar()
end
---Returns printable debug information.
---@return string
function M:debug()
  return 'State:\n'
    .. vim.inspect(self.state)
    .. '\nConfiguration: '
    .. vim.inspect(self.config)
end

local function create_keymaps()
  local keymaps = {
    {
      mode = { 'n' },
      lhs = '<Plug>(M0 backend)',
      rhs = ':M0 backend<CR>',
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'n', 'v' },
      lhs = '<Plug>(M0 chat)',
      rhs = M.chat,
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'n' },
      lhs = '<Plug>(M0 info)',
      rhs = ':M0 info<CR>',
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'n' },
      lhs = '<Plug>(M0 prompt)',
      rhs = ':M0 prompt<CR>',
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'v' },
      lhs = '<Plug>(M0 rewrite)',
      rhs = M.rewrite,
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'n' },
      lhs = '<Plug>(M0 scan_project)',
      rhs = ':M0 scan_project<CR>',
      opts = { noremap = true, silent = true },
    },
    {
      mode = { 'n', 'v' },
      lhs = '<Plug>(M0 toggle_sidebar)',
      rhs = ':M0 toggle_sidebar<CR>',
      opts = { noremap = true, silent = true },
    },
  }

  for _, v in ipairs(keymaps) do
    vim.keymap.set(v.mode, v.lhs, v.rhs, v.opts or {})
  end
end

local function init_logger(self)
  -- Init the backend logger.
  self.state.log_level = self.config.log_level or vim.log.levels.WARN
  self.logger = Logger:new { log_level = self.state.log_level }
end

local function setup_user_commands()
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
        local items = {}
        for k, v in pairs(M.config.backends) do
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
          M.logger:log_error(err or '')
        end
      end,
    },
    -- What prompt to use.
    prompt = {
      impl = function(_, _)
        local items = {}
        for k, v in pairs(M.config.prompts) do
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
          { prompt = 'Current: ' .. (M.state.scan_project and 'on' or 'off') },
          function(choice)
            if choice == 'on' then
              M.state.scan_project = true
            elseif choice == 'off' then
              M.state.scan_project = false
              M.state.project_context = nil
            end
          end
        )
      end,
    },
    toggle_sidebar = {
      impl = M.toggle_sidebar,
    },
  }

  ---@param opts table See ':h lua-guide-commands-create'.
  local function M0(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]
    -- Get the subcommand's args, if any.
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[subcommand_key]
    if not subcommand then
      M.logger:log_error('M0: unknown command: ' .. subcommand_key)
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

-- Sets up the m0 plugin.
---@param user_config table The user configuration.
function M.setup(user_config)
  -- Merge user configuration, overriding defaults.
  M.config = vim.tbl_extend('force', Config, user_config or {})

  -- Init logger as early as possible, so we can get proper error logging if
  -- setup fails.
  init_logger(M)

  -- Sanity checks.
  local success, error = M.config:validate()
  if not success then
    M.logger:log_error(error)
    return
  end

  -- Activate defaults.
  M:M0prompt(M.config.default_prompt_name)
  M:M0backend(M.config.default_backend_name)

  create_keymaps()
  setup_user_commands()
end

return M
