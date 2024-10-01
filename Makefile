test:
	nvim --clean --headless -u tests/minimal.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.lua', timeout = 2000, sequential = true}"
