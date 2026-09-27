--!strict
const Client = require(script.Parent.Parent.Client.Client)

const Keys = {}

local Holders = 0
local Watching = false
local Syncing = false
local Feeding = 0
local Fed = false
local Latest: {shift: boolean, seenAt: number}? = nil

const function Sync()
	if Syncing then
		return
	end

	Syncing = true

	task.spawn(function()
		while Watching ~= (Holders > 0) do
			const Wanted = Holders > 0

			if not Client.WatchKeys(Wanted) then
				break
			end

			Watching = Wanted
		end

		Syncing = false
	end)
end

-- Keeps a request open that the bridge answers on the next Return press, so the Shift state is
-- usually already here when the newline reaches the text box and Enter can send without a round trip.
const function Feed()
	Feeding += 1

	const Mine = Feeding

	task.spawn(function()
		local After: number? = nil

		while Feeding == Mine do
			const Ok, Seen = Client.LastReturn(After)

			if Feeding ~= Mine then
				break
			end

			if not Ok or typeof(Seen) ~= "table" or typeof(Seen.at) ~= "number" then
				Fed = false
				task.wait(1)

				continue
			end

			Fed = Seen.watching == true

			if After ~= nil and Seen.at > After then
				Latest = {shift = Seen.shift == true, seenAt = os.clock()}
			end

			After = math.max(After or 0, Seen.at)
		end
	end)
end

function Keys.Hold()
	Holders += 1
	Sync()

	if Holders == 1 then
		Feed()
	end
end

function Keys.Release()
	Holders = math.max(0, Holders - 1)
	Sync()

	if Holders == 0 then
		Feeding += 1
		Fed = false
	end
end

const function Last(): any?
	const Ok, Seen = Client.LastReturn()

	return if Ok and typeof(Seen) == "table" and Seen.watching == true then Seen else nil
end

function Keys.ShiftedReturn(): boolean
	const Seen = Last()

	return Seen ~= nil and Seen.shift == true and typeof(Seen.now) == "number" and typeof(Seen.at) == "number" and Seen.now - Seen.at < 2000
end

-- Whether the Return that just typed a newline had Shift held, using the pushed press when it has arrived.
function Keys.Shifted(): boolean
	const Deadline = os.clock() + 0.25

	while Fed and not (Latest and os.clock() - Latest.seenAt < 0.5) and os.clock() < Deadline do
		task.wait()
	end

	const Press = Latest

	if Press and os.clock() - Press.seenAt < 0.5 then
		Latest = nil

		return Press.shift
	end

	return Keys.ShiftedReturn()
end

function Keys.Clean(Rich: string): string
	return (Rich:gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&"))
end

function Keys.CopySelection(Box: TextBox, Since: number, Spanning: string?): number
	const Seen = Last()

	if not Seen or typeof(Seen.copyAt) ~= "number" or Seen.copyAt <= Since then
		return Since
	end

	if Spanning then
		task.spawn(Client.WriteClipboard, Spanning)

		return Seen.copyAt
	end

	const From = math.min(Box.CursorPosition, Box.SelectionStart)
	const To = math.max(Box.CursorPosition, Box.SelectionStart)

	if Box.SelectionStart == -1 or From == To then
		return Seen.copyAt
	end

	task.spawn(Client.WriteClipboard, Box.Text:sub(From, To - 1))

	return Seen.copyAt
end

return Keys