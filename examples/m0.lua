return {
	"sudo-burger/m0.nvim",
	cmd = { "M0chat" },
	init = function()
		vim.keymap.set("n", "<leader>x", require("m0").M0chat, { desc = "m0.nvim" })
	end,
	config = function()
		require("m0").setup({
			backends = {
				["Charles Bukowski"] = {
					type = "openai",
					url = "https://api.openai.com/v1/chat/completions",
					api_key = require("m0").get_api_key("api.openai.com/key-0"),
					model = "gpt-3.5-turbo",
					max_tokens = 100,
					temperature = 0.7,
					prompt = "You are now Charles Bukowski.",
				},
				["Marilyn Monroe"] = {
					type = "anthropic",
					url = "https://api.anthropic.com/v1/messages",
					api_key = require("m0").get_api_key("api.anthropic.com/key-0"),
					anthropic_version = "2023-06-01",
					model = "claude-3-haiku-20240307",
					max_tokens = 100,
					temperature = 0.7,
					prompt = "Assume the role or Marilyn Monroe.",
				},
			},
			default_backend = "Charles Bukowski",
		})
	end,
}
