--!strict
const RunService = game:GetService("RunService")

const Playing = not RunService:IsEdit()
const RunMode = Playing and RunService:IsRunMode()

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

	if not RunMode then
		return
	end
end

const Players = game:GetService("Players")

if Playing and not RunMode and not Players.LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

const Local = Players.LocalPlayer

if Playing and Local and Local.UserId <= 0 then
	require(script.Parent.Settings).Load(plugin)
	Builder.Serve()
	require(script.Parent.Runtime).Start(plugin)

	return
end

const Settings = require(script.Parent.Settings)
const Watcher = require(script.Parent.Watcher)
const App = require(script.Parent.App.App)

Settings.Load(plugin)

if Playing and not RunMode then
	Builder.Serve()
	require(script.Parent.Runtime).Start(plugin)
end

if not Playing then
	pcall(require(script.Parent.Runtime).Remove)

	if Settings.Get("RelayToken")() == "" then
		Settings.Set("RelayToken", game:GetService("HttpService"):GenerateGUID(false))
	end

	Watcher.Start()
	task.spawn(require(script.Parent.Fresh).Snapshot)
end

const Running = App.New(plugin)

if Playing and not RunMode then
	task.spawn(require(script.Parent.Picker).Start, plugin)
end

plugin.Unloading:Connect(function()
	Running.Destroy()
end)