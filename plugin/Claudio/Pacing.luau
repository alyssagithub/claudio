--!strict
const Pacing = {}

const Keywords = {
	["do"] = true,
	["repeat"] = true,
}

function Pacing.Insert(Code: string, Call: string): string
	const Pieces = {}
	local At = 1
	local Copied = 1

	const function LongEnd(From: number): number?
		const Equals = Code:match("^%[(=*)%[", From)

		if not Equals then
			return nil
		end

		const _, Stop = Code:find(`]{Equals}]`, From + #Equals + 2, true)

		return Stop or #Code
	end

	while At <= #Code do
		const Character = Code:sub(At, At)

		if Character == "-" and Code:sub(At + 1, At + 1) == "-" then
			At = (LongEnd(At + 2) or Code:find("\n", At, true) or #Code) + 1
		elseif Character == "[" and LongEnd(At) then
			At = (LongEnd(At) :: number) + 1
		elseif Character == "\"" or Character == "'" or Character == "`" then
			local Scan = At + 1

			while Scan <= #Code and Code:sub(Scan, Scan) ~= Character do
				Scan += if Code:sub(Scan, Scan) == "\\" then 2 else 1
			end

			At = Scan + 1
		elseif Character:match("[%a_]") then
			const Word = Code:match("^[%w_]+", At) :: string
			const Before = if At > 1 then Code:sub(At - 1, At - 1) else ""

			At += #Word

			if Keywords[Word] and Before ~= "." and Before ~= ":" then
				table.insert(Pieces, Code:sub(Copied, At - 1))
				table.insert(Pieces, ` {Call}();`)
				Copied = At
			end
		else
			At += 1
		end
	end

	table.insert(Pieces, Code:sub(Copied))

	return table.concat(Pieces)
end

return Pacing
