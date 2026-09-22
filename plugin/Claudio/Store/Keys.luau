--!strict
const Client = require(script.Parent.Parent.Client.Client)

const Keys = {}

local Holders = 0
local Watching = false
local Syncing = false

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

function Keys.Hold()
	Holders += 1
	Sync()
end

function Keys.Release()
	Holders = math.max(0, Holders - 1)
	Sync()
end

function Keys.Last(): any?
	const Ok, Seen = Client.LastReturn()

	return if Ok and typeof(Seen) == "table" and Seen.watching == true then Seen else nil
end

function Keys.ShiftedReturn(): boolean
	const Seen = Keys.Last()

	return Seen ~= nil and Seen.shift == true and typeof(Seen.now) == "number" and typeof(Seen.at) == "number" and Seen.now - Seen.at < 2000
end

function Keys.Clean(Rich: string): string
	return (Rich:gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&"))
end

function Keys.CopySelection(Box: TextBox, Since: number, Spanning: string?): number
	const Seen = Keys.Last()

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