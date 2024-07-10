all:
	cp lua/m0/*.lua /Users/yk/.local/share/nvim/lazy/m0.nvim/lua/m0/
test:
	# nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim', sequential = true}"
	nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init='tests/minimal.vim', sequential=true, keep_going = true }"
