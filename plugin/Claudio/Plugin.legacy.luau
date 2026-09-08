--!strict
const RunService = game:GetService("RunService")

const Playing = RunService:IsRunning()

if not plugin then
	return
end

const Builder = require(script.Parent.Runtime.Builder)

if Playing and RunService:IsServer() then
	require(script.Parent.Settings).Load(plugin)
	require(script.Parent.Client.Relay).Serve()
	Builder.Serve()

	return
end

const Settings = require(script.Parent.Settings)
const Watcher = require(script.Parent.Watcher)
const App = require(script.Parent.App.App)

Settings.Load(plugin)

if Playing then
	Builder.Serve()
end

if not Playing then
	if Settings.Get("RelayToken")() == "" then
		Settings.Set("RelayToken", game:GetService("HttpService"):GenerateGUID(false))
	end

	Watcher.Start()
end

const Running = App.New(plugin)

plugin.Unloading:Connect(function()
	Running.Destroy()
end)