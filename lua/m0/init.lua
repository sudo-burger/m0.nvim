---@class Backend
---@field opts BackendOptions
---@field run fun(): nil

---@class State
---@field backend Backend?
---@field prompt string?
---@field prompt_name string?

---@type APIFactory
local APIFactory = require 'm0.apifactory'

---@type Utils
local Utils = require 'm0.utils'

local M = {
  ---@type State
  State = {},
  ---@type Config
  Config = require 'm0.config',
}
M.__index = M

---@type VimBuffer
local VimBuffer = require 'm0.vimbuffer'

---Returns a table including the backend-specific implementation of the function run().
---
---@param API LLMAPI The API handler.
---@param msg VimBuffer
---@param opts BackendOptions
---@return Backend
local function make_backend(API, msg, opts)
  return {
    opts = opts,
    -- name = opts.backend_name,
    run = function()
      local body = API:make_body()

      -- Message are specific to each run.
      body.messages = API:get_messages(msg:get_messages())

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

  ---@type LLMAPI?
  local API = APIFactory.create(backend_opts.api_type, backend_opts, M.State)
  if not API then
    Utils:log_error('Unable create API for ' .. backend_opts.api_type)
    return
  end

  M.State.backend = make_backend(API, msg, backend_opts)
end

---Select prompt interactively.
---@param prompt_name string
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

  -- User commands
  -- -------------

  vim.api.nvim_create_user_command('M0prompt', function(_)
    local items = {}
    for k, _ in pairs(M.Config.prompts) do
      table.insert(items, k)
    end
    table.sort(items)
    vim.ui.select(items, {}, function(choice)
      M:M0prompt(choice)
    end)
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('M0backend', function(_)
    local items = {}
    for k, _ in pairs(M.Config.backends) do
      table.insert(items, k)
    end
    table.sort(items)
    vim.ui.select(items, {}, function(choice)
      M:M0backend(choice)
    end)
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('M0chat', M.M0chat, {})
end

return M
