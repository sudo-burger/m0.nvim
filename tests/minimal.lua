local cwd = vim.fn.getcwd()

-- Add the current directory to the runtimepath
vim.opt.rtp:prepend(cwd)

-- Add Plenary to the runtimepath
vim.opt.rtp:prepend(cwd .. '/../vendor/plenary.nvim')

-- Load Plenary
require 'plenary.busted'

-- Add to Telescope the runtimepath
vim.opt.rtp:prepend(cwd .. '/../vendor/telescope.nvim')

-- Load your plugin
require 'm0'
