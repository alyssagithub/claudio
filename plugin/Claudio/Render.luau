--!strict
const AssetService = game:GetService("AssetService")
const CaptureService = game:GetService("CaptureService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Lighting = game:GetService("Lighting")
const RunService = game:GetService("RunService")
const Selection = game:GetService("Selection")

const Base64 = require(script.Parent.Base64)
const Breathe = require(script.Parent.Breathe)

const Views: {[string]: {number}} = {
	front = {0, 0},
	back = {180, 0},
	left = {90, 0},
	right = {-90, 0},
	top = {0, 89.9},
	bottom = {0, -89.9},
	["three-quarter"] = {35, 25},
}

const Corners = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

type Change = {Object: Instance, Property: string, Value: any}

const function Settle()
	RunService.PreRender:Wait()
	RunService.Heartbeat:Wait()
	RunService.PreRender:Wait()
	RunService.Heartbeat:Wait()
end

const function Screenshot(): (EditableImage?, string?)
	local Taken: any
	local Done = false

	CaptureService:CaptureScreenshot(function(Content: any)
		Taken = Content
		Done = true
	end)

	const Deadline = os.clock() + 8

	while not Done and os.clock() < Deadline do
		task.wait(0.03)
	end

	if not Taken then
		return nil, "Studio did not return a screenshot."
	end

	const Made, Image = pcall(function(): any
		return AssetService:CreateEditableImageAsync(Content.fromUri(Taken))
	end)

	return if Made then Image else nil, if Made then nil else `Could not read the screenshot: {tostring(Image)}`
end

const function Parts(Object: Instance): {BasePart}
	const Found = {}

	if Object:IsA("BasePart") then
		table.insert(Found, Object)
	end

	for _, Descendant in Object:GetDescendants() do
		if Descendant:IsA("BasePart") then
			table.insert(Found, Descendant)
		end
	end

	return Found
end

return function(Input: any, Resolve: (string) -> Instance?): any
	const Object = if typeof(Input.path) == "string" then Resolve(Input.path) else nil

	if not Object then
		return {error = `Nothing at "{tostring(Input.path)}" to render.`}
	end

	const Own = Parts(Object)

	if #Own == 0 then
		return {error = `{Object:GetFullName()} has no parts to render.`}
	end

	const Camera = workspace.CurrentCamera
	const Viewport = Camera.ViewportSize
	const Background = tostring(Input.background or "transparent"):lower()
	const Transparent = Background == "transparent"
	const Scene = Background == "scene"
	const Backdrop = if Transparent or Scene then Color3.new() else (pcall(Color3.fromHex, Background) and Color3.fromHex(Background) or nil)

	if not Transparent and not Scene and not Backdrop then
		return {error = `background must be transparent, scene, or a hex colour such as #202020, not "{Background}".`}
	end

	const Preset = if typeof(Input.view) == "string" then Views[Input.view:lower()] else nil

	if Input.view and not Preset then
		return {error = `view must be one of front, back, left, right, top, bottom or three-quarter, not "{tostring(Input.view)}".`}
	end

	const Yaw = math.rad(tonumber(Input.yaw) or (if Preset then Preset[1] else 35))
	const Pitch = math.rad(math.clamp(tonumber(Input.pitch) or (if Preset then Preset[2] else 25), -89.9, 89.9))
	const Field = math.clamp(tonumber(Input.fov) or 30, 1, 120)
	const Side = math.floor(math.clamp(tonumber(Input.size) or 512, 64, math.min(Viewport.X, Viewport.Y)))

	const Pivot = if Object:IsA("Model") then (Object :: Model):GetPivot() elseif Object:IsA("BasePart") then (Object :: BasePart).CFrame else CFrame.new()
	const Turn = Pivot.Rotation
	local Low = Vector3.one * math.huge
	local High = -Vector3.one * math.huge

	for _, Part in Own do
		const Half = Part.Size / 2

		for _, Corner in Corners do
			const Local = Turn:PointToObjectSpace(Part.CFrame:PointToWorldSpace(Half * Corner))

			Low = Low:Min(Local)
			High = High:Max(Local)
		end
	end

	const Middle = Turn:PointToWorldSpace((Low + High) / 2)
	const Toward = Turn:VectorToWorldSpace(CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0).LookVector)
	const Up = if math.abs(Toward:Dot(Turn.UpVector)) > 0.999 then Turn.LookVector * -math.sign(Toward:Dot(Turn.UpVector)) else Turn.UpVector
	const Facing = CFrame.lookAt(Vector3.zero, -Toward, Up)
	const Slope = math.tan(math.rad(Field / 2)) * (Side / Viewport.Y)
	local Distance = 0

	for _, Part in Own do
		const Half = Part.Size / 2

		for _, Corner in Corners do
			const Offset = Facing:PointToObjectSpace(Part.CFrame:PointToWorldSpace(Half * Corner) - Middle)

			Distance = math.max(Distance, math.max(math.abs(Offset.X), math.abs(Offset.Y)) / Slope + Offset.Z)
		end
	end

	Distance *= 1.06 * math.clamp(tonumber(Input.distance) or 1, 0.1, 50)

	const Reach = (High - Low).Magnitude / 2
	const Changes: {Change} = {}
	const Recording = ChangeHistoryService:TryBeginRecording("Claudio render")
	const Chosen = Selection:Get()
	const Made: {Instance} = {}
	local Wall: Part?

	const function Set(Target: Instance, Property: string, Value: any)
		const Ok, Before = pcall(function(): any
			return (Target :: any)[Property]
		end)

		if Ok and pcall(function()
			(Target :: any)[Property] = Value
		end) then
			table.insert(Changes, {
				Object = Target,
				Property = Property,
				Value = Before,
			})
		end
	end

	const function Restore()
		for Index = #Changes, 1, -1 do
			const Change = Changes[Index]

			pcall(function()
				(Change.Object :: any)[Change.Property] = Change.Value
			end)
		end

		for _, Instance in Made do
			Instance:Destroy()
		end

		if Recording then
			ChangeHistoryService:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
		end

		Selection:Set(Chosen)
	end

	const Ok, Result = pcall(function(): any
		Selection:Set({})
		Set(Camera, "CameraType", Enum.CameraType.Scriptable)
		Set(Camera, "FieldOfView", Field)
		Set(Camera, "CFrame", CFrame.lookAt(Middle + Toward * Distance, Middle, Up))
		Set(game:GetService("StarterGui"), "ShowDevelopmentGui", false)

		if Input.isolate ~= false then
			const Keep: {[BasePart]: boolean} = {}

			for _, Part in Own do
				Keep[Part] = true
			end

			for _, Descendant in workspace:GetDescendants() do
				Breathe()

				if Keep[Descendant] or (Descendant.Parent and Keep[Descendant.Parent :: any]) then
					continue
				end

				if Descendant:IsA("BasePart") and Descendant.Transparency < 1 then
					Set(Descendant, "Transparency", 1)
				elseif (Descendant:IsA("Decal") or Descendant:IsA("Beam") or Descendant:IsA("Trail")) and not Descendant:IsDescendantOf(Object) then
					Set(Descendant, if Descendant:IsA("Decal") then "Transparency" else "Enabled", if Descendant:IsA("Decal") then 1 else false)
				elseif (Descendant:IsA("LayerCollector") or Descendant:IsA("ParticleEmitter") or Descendant:IsA("Light") or Descendant:IsA("Highlight") or Descendant:IsA("Fire") or Descendant:IsA("Smoke") or Descendant:IsA("Sparkles")) and not Descendant:IsDescendantOf(Object) then
					Set(Descendant, "Enabled", false)
				end
			end
		end

		if Input.lighting == "studio" then
			Set(Lighting, "ClockTime", 14)
			Set(Lighting, "Brightness", 2)
			Set(Lighting, "Ambient", Color3.fromRGB(130, 130, 130))
			Set(Lighting, "OutdoorAmbient", Color3.fromRGB(150, 150, 150))
			Set(Lighting, "EnvironmentDiffuseScale", 1)
			Set(Lighting, "EnvironmentSpecularScale", 1)
		end

		if not Scene then
			for _, Holder in {Lighting, Camera, workspace.Terrain} do
				for _, Effect in Holder:GetDescendants() do
					if Effect:IsA("PostEffect") then
						Set(Effect, "Enabled", false)
					elseif Effect:IsA("Atmosphere") or Effect:IsA("Clouds") then
						Set(Effect, "Parent", nil)
					end
				end
			end

			Set(Lighting, "ExposureCompensation", 0)

			const Grading = Instance.new("ColorGradingEffect")

			pcall(function()
				(Grading :: any).TonemapperPreset = Enum.TonemapperPreset.Retro
			end)
			Grading.Parent = Lighting
			table.insert(Made, Grading)

			const Plane = Instance.new("Part")
			const Stretch = Instance.new("SpecialMesh")

			Plane.Anchored = true
			Plane.CanCollide = false
			Plane.CastShadow = false
			Plane.Material = Enum.Material.SmoothPlastic
			Plane.Size = Vector3.one
			Plane.CFrame = CFrame.lookAt(Middle - Toward * (Reach * 4 + 20), Middle)
			Plane.Color = Backdrop or Color3.new()
			Stretch.MeshType = Enum.MeshType.Brick
			Stretch.Scale = Vector3.new(1e6, 1e6, 0)
			Stretch.Parent = Plane
			Plane.Parent = Camera
			Wall = Plane
			table.insert(Made, Plane)

			Set(Lighting, "FogStart", Distance + Reach + 0.5)
			Set(Lighting, "FogEnd", Distance + Reach + 1)
			Set(Lighting, "FogColor", Backdrop or Color3.new())
		end

		Settle()

		const First, Trouble = Screenshot()

		if not First then
			return {error = Trouble}
		end

		const Ratio = First.Size.X / Viewport.X
		const Span = math.floor(Side * Ratio)
		const Corner = Vector2.new(math.floor((First.Size.X - Span) / 2), math.floor((First.Size.Y - Span) / 2))
		const Dark = First:ReadPixelsBuffer(Corner, Vector2.new(Span, Span))

		if not Transparent then
			return {size = Span, pixels = Base64.Encode(buffer.tostring(Dark))}
		end

		Set(Lighting, "FogColor", Color3.new(1, 1, 1))
		;(Wall :: Part).Color = Color3.new(1, 1, 1)
		Settle()

		const Second, Failed = Screenshot()

		if not Second then
			return {error = Failed}
		end

		const Light = Second:ReadPixelsBuffer(Corner, Vector2.new(Span, Span))
		const Out = buffer.create(Span * Span * 4)

		for Index = 0, Span * Span - 1 do
			if Index % 4096 == 0 then
				Breathe()
			end

			const At = Index * 4
			const DarkRed, DarkGreen, DarkBlue = buffer.readu8(Dark, At), buffer.readu8(Dark, At + 1), buffer.readu8(Dark, At + 2)
			const Spread = math.max(buffer.readu8(Light, At) - DarkRed, buffer.readu8(Light, At + 1) - DarkGreen, buffer.readu8(Light, At + 2) - DarkBlue)
			const Alpha = math.clamp(1 - Spread / 255, 0, 1)

			if Alpha <= 0 then
				buffer.writeu32(Out, At, 0)

				continue
			end

			buffer.writeu8(Out, At, math.clamp(math.floor(DarkRed / Alpha + 0.5), 0, 255))
			buffer.writeu8(Out, At + 1, math.clamp(math.floor(DarkGreen / Alpha + 0.5), 0, 255))
			buffer.writeu8(Out, At + 2, math.clamp(math.floor(DarkBlue / Alpha + 0.5), 0, 255))
			buffer.writeu8(Out, At + 3, math.floor(Alpha * 255 + 0.5))
		end

		return {size = Span, pixels = Base64.Encode(buffer.tostring(Out))}
	end)

	Restore()

	if not Ok then
		return {error = `The render failed: {tostring(Result)}`}
	end

	if Result.error then
		return Result
	end

	return {
		width = Result.size,
		height = Result.size,
		pixels = Result.pixels,
		text = `{Result.size}x{Result.size} render of {Object:GetFullName()}, yaw {math.floor(math.deg(Yaw) + 0.5)}, pitch {math.floor(math.deg(Pitch) + 0.5)}, field of view {Field}, background {Background}{if Input.isolate == false then "" else ", others hidden"}`,
	}
end
