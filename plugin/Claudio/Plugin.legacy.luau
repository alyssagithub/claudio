--!strict
const RunService = game:GetService("RunService")

const Playing = not RunService:IsEdit()

if not plugin then
	return
end

const Builder = require(script.Parent.Runtime.Builder)

if Playing and RunService:IsServer() then
	require(script.Parent.Settings).Load(plugin)
	require(script.Parent.Client.Relay).Serve()
	Builder.Serve()
	require(script.Parent.Runtime).Start(plugin)
	require(script.Parent.Picker).Start(plugin)

	return
end

const Settings = require(script.Parent.Settings)
const Watcher = require(script.Parent.Watcher)
const App = require(script.Parent.App.App)

Settings.Load(plugin)

if Playing then
	Builder.Serve()
	require(script.Parent.Runtime).Start(plugin)
end

if not Playing then
	pcall(require(script.Parent.Runtime).Remove)

	if Settings.Get("RelayToken")() == "" then
		Settings.Set("RelayToken", game:GetService("HttpService"):GenerateGUID(false))
	end

	Watcher.Start()
end

const Running = App.New(plugin)

if Playing then
	task.spawn(require(script.Parent.Picker).Start, plugin)
end

plugin.Unloading:Connect(function()
	Running.Destroy()
end)