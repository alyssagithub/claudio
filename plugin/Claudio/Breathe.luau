--!strict
local LastYield = os.clock()

return function()
	if os.clock() - LastYield < 0.008 then
		return
	end

	task.wait()
	LastYield = os.clock()
end