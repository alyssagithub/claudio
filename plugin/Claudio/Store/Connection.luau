--!strict
const Vide = require(script.Parent.Parent.Packages.vide)
const Types = require(script.Parent.Parent.Types)

const Connection = {
	Status = Vide.source("Disconnected" :: Types.ConnectionStatus),
	ErrorKind = Vide.source(nil :: string?),
	Health = Vide.source(nil :: Types.Health?),
}

function Connection.Fail(Kind: string)
	Connection.ErrorKind(Kind)
	Connection.Status("Error")
end

return Connection