test:
	# nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim', sequential = true}"
	nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init='tests/minimal.vim', sequential=true, keep_going = true }"
