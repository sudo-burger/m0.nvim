---@type M0.Logger
local Logger = require 'm0.logger'

---@type M0.APIFactory
local APIFactory = require 'm0.apifactory'

---@type M0.Selector
local Selector = require 'm0.selector'

---@type M0.Utils
local Utils = require 'm0.utils'

---@class Backend
---@field opts M0.BackendOptions
---@field run fun(): nil

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

---Returns a table including the backend-specific implementation of the function run().
---
---@param API M0.LLMAPI The API handler.
---@param msg_buf M0.VimBuffer
---@param opts M0.BackendOptions
---@param state State
---@return Backend
local function make_backend(API, msg_buf, opts, state)
  return {
    opts = opts,
    -- name = opts.backend_name,
    run = function()
      if state.scan_project == true then
        -- If a scan of the project has been requested, it should make sense
        -- to re-scan on every turn, to catch code changes.
        -- FIXME: don't assume that cwd is project's root.
        local success, context =
          require('m0.scanproject'):get_context(vim.fn.getcwd())
        if not success then
          M.Logger:log_error(context)
        else
          state.project_context = context
        end
      end

      local body = API:make_body()
      local messages = msg_buf:get_messages()
      body.messages = API:get_messages(messages)

      local curl_opts = {
        headers = API:make_headers(),
        body = vim.fn.json_encode(body),
      }

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if opts.stream == true then
        curl_opts.stream = vim.schedule_wrap(function(err, out, _job)
          M.Logger:log_trace(
            'Err: '
              .. (err or '')
              .. '\nOut: '
              .. (out or '')
              .. '\nJob: '
              .. vim.inspect(_job)
          )
          if err then
            M.Logger:log_error('Stream error: [' .. err .. '] [' .. out .. ']')
            return
          end
          -- When streaming, it seems the best chance to catch an API error
          -- is to parse stdout.
          if _job._stdout_results ~= {} then
            local success, json = Utils:json_decode(_job._stdout_results)
            if success and json and json.error then
              M.Logger:log_error('Stream error: [' .. vim.inspect(json) .. ']')
              return
            end
          end

          local event, d = API:get_delta_text(out)
          if event == 'delta' then
            msg_buf:put_response(d, { stream = true })
          elseif event == 'error' then
            M.Logger:log_error(d)
          elseif event == 'stats' then
            M.Logger:log_info(d)
          elseif event == 'done' then
            msg_buf:close_response()
          elseif d then
            M.Logger:log_trace('Unhandled stream results: ' .. d)
          end
        end)
      else
        -- Not streaming.
        -- We append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
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
          end
          if stats then
            M.Logger:log_info(stats)
          end
          msg_buf:close_response()
        end)
      end

      msg_buf:open_response()
      local response = require('plenary.curl').post(opts.url, curl_opts)
      if not response then
        M.Logger:log_error 'Failed to obtain CuRL response.'
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

  ---@type boolean,M0.LLMAPI?
  local success, API =
    APIFactory.create(backend_opts.api_type, backend_opts, M.State)
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

--- Run a chat round.
---@return nil
function M:M0chat()
  M.State.backend.run()
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

  -- Init the backend logger
  M.State.log_level = M.Config.log_level
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
      impl = M.M0chat,
    },
    info = {
      impl = function(_, _)
        local win_width = vim.api.nvim_win_get_width(0)
        local win_height = vim.api.nvim_win_get_height(0)
        if win_width < 20 or win_height < 20 then
          M.Logger:log_warn 'We are in a tight place.'
          return
        end
        local buf_id = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(
          buf_id,
          -2,
          -1,
          false,
          -- If the input contains multiple lines,
          -- split them as required by nvim_buf_get_lines()
          vim.fn.split(M:debug(), '\n', false)
        )
        local win_id = vim.api.nvim_open_win(buf_id, true, {
          relative = 'win',
          row = 5,
          col = 5,
          width = win_width - 10,
          height = win_height - 10,
          style = 'minimal',
          border = 'rounded',
        })
        if win_id == 0 then
          M.Logger:log_error 'Unable to create popup window.'
        end
        -- Bind q to quit popup.
        vim.keymap.set('n', 'q', function()
          vim.api.nvim_win_close(win_id, true)
        end, { buffer = buf_id })
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
    bang = true, -- If you want to support !-modifiers
  })
end

return M
