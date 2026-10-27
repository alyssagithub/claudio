--!strict
const CaptureService = game:GetService("CaptureService")

const Video = {}

local Current: {Done: boolean, Result: string?}? = nil

function Video.Start(): any
	const State = {Done = false, Result = nil :: string?}
	const Ok, Started = pcall(function(): any
		return CaptureService:StartVideoCaptureAsync(function(Result: any)
			State.Result = tostring(Result)
			State.Done = true
		end, {})
	end)

	if not Ok then
		return {error = `Studio would not start recording: {tostring(Started)}`}
	end

	if Started ~= Enum.VideoCaptureStartedResult.Success then
		return {error = `Studio would not start recording: {tostring(Started)}`}
	end

	Current = State

	return {text = "Recording."}
end

function Video.Stop(): any
	const State = Current

	if not State then
		return {error = "Nothing is being recorded."}
	end

	pcall(function()
		CaptureService:StopVideoCapture()
	end)

	const Deadline = os.clock() + 15

	while not State.Done and os.clock() < Deadline do
		task.wait(0.1)
	end

	Current = nil

	if not State.Done then
		return {error = "Studio stopped recording but never said the clip was saved."}
	end

	if State.Result ~= tostring(Enum.VideoCaptureResult.Success) then
		return {error = `Studio could not save the recording: {State.Result}`}
	end

	return {text = "Saved."}
end

return Video
