return {
	{
		"sudo-burger/m.nvim",
		cmd = { "Mchat" },
		config = function()
			vim.keymap.set("n", "<C-d>", require("m").Mchat, { desc = "m.nvim" })
			-- require("m").setup({ default_backend = "openai-0" })
			-- default_backend = require('m').make_openai {
			--   url = 'https://api.openai.com/v1/chat/completions',
			--   api_key = require('m').get_api_key 'api.openai.com/key-0',
			--   model = 'gpt-3.5-turbo',
			--   max_tokens = 100,
			--   temperature = 0.7,
			--   prompt = 'You are literally The Hulk.',
			-- },
			-- })
		end,
	},
}
