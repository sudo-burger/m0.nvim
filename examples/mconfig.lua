return {
  {
    'sudo-burger/m.nvim',

    config = function()
      vim.keymap.set('n', '<C-d>', require('m').chatgpt, { desc = 'm.nvim' })
      require('m').setup {
        default_model = require('m').make_openai {
          url = 'https://api.openai.com/v1/chat/completions',
          api_key = require('m').get_api_key 'api.openai.com/key-0',
          model = 'gpt-3.5-turbo',
          max_tokens = 100,
          temperature = 0.7,
          prompt = 'You are literally The Hulk.',
        },
      }
    end,
  },
}
