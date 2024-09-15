---@class Backend
---@field opts M0.BackendOptions
---@field run fun(): nil

---@class State
---@field backend Backend?
---@field prompt string?
---@field prompt_name string?
---@field scan_project boolean?
---@field project_context string?

---@type M0.APIFactory
local APIFactory = require 'm0.apifactory'

---@type M0.Utils
local Utils = require 'm0.utils'

---@type M0.ScanProject
local ScanProject = require 'm0.scanproject'

local M = {
  ---@type State
  State = {},
  ---@type M0.Config
  Config = require 'm0.config',
}
M.__index = M

---@type M0.VimBuffer
local VimBuffer = require 'm0.vimbuffer'

---Returns a table including the backend-specific implementation of the function run().
---
---@param API M0.LLMAPI The API handler.
---@param msg M0.VimBuffer
---@param opts M0.BackendOptions
---@param state State
---@return Backend
local function make_backend(API, msg, opts, state)
  return {
    opts = opts,
    -- name = opts.backend_name,
    run = function()
      local messages = msg:get_messages()

      -- If a scan of the project has been requested, it should make sense
      -- to refresh it on every run.
      if state.scan_project == true then
        M.State.project_context = ScanProject:get_context(vim.fn.getcwd())
        table.insert(messages, 1, M.State.project_context)
      end

      local body = API:make_body()
      body.messages = API:get_messages(messages)

      local curl_opts = {
        headers = API:make_headers(),
        body = vim.fn.json_encode(body),
      }

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if opts.stream == true then
        -- The streaming callback appends the reply to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(err, out, _)
          if err then
            Utils:log_error('Stream error (1): ' .. err)
            return
          end
          local event, d = API:get_delta_text(out)

          if event == 'delta' and d ~= '' then
            -- Add the delta to the current line.
            msg:set_last_line(msg:get_last_line() .. d)
          elseif event == 'other' and d ~= '' then
            -- Could be an error.
            Utils:log_info(d)
          elseif event == 'done' then
            msg:close_section()
          else
            -- Utils:log_info(
            --   'Other stream results (1): [' .. event .. '][' .. d .. ']'
            -- )
            -- Cruft or no data.
            return
          end
        end)
      else
        -- Not streaming.
        -- We append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
          -- Build the reply in the message handler.
          local res = API:get_response_text(out.body)
          if res then
            msg:set_last_line(res)
          end
          msg:close_section()
        end)
      end

      -- The closing section mark is printed by the curl callbacks.
      msg:open_section()
      local response = require('plenary.curl').post(opts.url, curl_opts)
      if response.status ~= nil and response.status ~= 200 then
        Utils:log_error('API error (1): ' .. vim.inspect(response))
        return
      end
    end,
  }
end

-- Exported functions
-- ------------------

---Select backend interactively.
---@param backend_name string The name of the backend, as found in the user configuration.
---@return nil
function M:M0backend(backend_name)
  local msg = VimBuffer:new(self.Config)
  -- Use deepcopy to avoid cluttering the configuration with backend-specific settings.
  local backend_opts = vim.deepcopy(self.Config.backends[backend_name])
  local provider_name = backend_opts.provider
  local provider_opts = vim.deepcopy(self.Config.providers[provider_name])
  local default_opts =
    vim.deepcopy(self.Config.defaults.providers[provider_name])

  if not backend_opts then
    error("Backend '" .. backend_name .. "' not in configuration.")
  end

  if not provider_opts then
    error(
      "Unable to find provider '"
        .. provider_name
        .. "' for backend '"
        .. backend_name
        .. "'."
    )
  end

  -- Merge the defaults, provider opts, and backend opts.
  -- The former are overridden by the latter.
  backend_opts =
    vim.tbl_extend('force', default_opts, provider_opts, backend_opts)

  ---@type M0.LLMAPI?
  local API = APIFactory.create(backend_opts.api_type, backend_opts, M.State)
  if not API then
    Utils:log_error('Unable create API for ' .. backend_opts.api_type)
    return
  end

  M.State.backend = make_backend(API, msg, backend_opts, M.State)
end

---Select prompt interactively.
---@param prompt_name string The name of the prompt, as found in the user configuration.
---@return nil
function M:M0prompt(prompt_name)
  if self.Config.prompts[prompt_name] == nil then
    error("Prompt '" .. prompt_name .. "' not in configuration.")
  end
  self.State.prompt_name = prompt_name
  self.State.prompt = self.Config.prompts[prompt_name]
end

--- Run a chat round.
---@return nil
function M:M0chat()
  M.State.backend.run()
end

--- Scan the project code.
--- @return nil
function M.M0scan_project()
  M.State.scan_project = true
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
  M.Config = vim.tbl_extend('force', M.Config, user_config or {})
  if M.Config.backends[M.Config.default_backend_name] == nil then
    error(
      'Default backend ('
        .. M.Config.default_backend_name
        .. ') not in configuration.'
    )
  end
  if M.Config.prompts[M.Config.default_prompt_name] == nil then
    error(
      'Default prompt ('
        .. M.Config.default_prompt_name
        .. ') not in configuration.'
    )
  end
  M:M0prompt(M.Config.default_prompt_name)
  M:M0backend(M.Config.default_backend_name)

  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 backend)',
    ':M0 backend<CR>',
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n', 'v' },
    '<Plug>(M0 chat)',
    M.M0chat,
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 prompt)',
    ':M0 prompt<CR>',
    { noremap = true, silent = true }
  )
  vim.keymap.set(
    { 'n' },
    '<Plug>(M0 scan_project)',
    ':M0 scan-project<CR>',
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
    backend = {
      impl = function(_, _)
        local items = {}
        for k, _ in pairs(M.Config.backends) do
          table.insert(items, k)
        end
        table.sort(items)
        vim.ui.select(items, {}, function(choice)
          if choice then
            M:M0backend(choice)
          end
        end)
      end,
    },
    chat = {
      impl = M.M0chat,
    },
    prompt = {
      impl = function(_, _)
        local items = {}
        for k, _ in pairs(M.Config.prompts) do
          table.insert(items, k)
        end
        table.sort(items)
        vim.ui.select(items, {}, function(choice)
          if choice then
            M:M0prompt(choice)
          end
        end)
      end,
    },
    scan_project = {
      impl = M.M0scan_project,
    },
  }

  ---@param opts table :h lua-guide-commands-create
  local function M0(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]
    -- Get the subcommand's args, if any.
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[subcommand_key]
    if not subcommand then
      vim.notify(
        'M0: unknown command: ' .. subcommand_key,
        vim.log.levels.ERROR
      )
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
    bang = true, -- If you want to support ! modifiers
  })
end

return M
