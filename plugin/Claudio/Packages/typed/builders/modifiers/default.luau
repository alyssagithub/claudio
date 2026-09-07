const schema = require("../../schema")
const optional = require("./optional")
const transform = require("./transform")

const function defaultSchemaBuilder<T, S, M>(sourceSchema: schema.Schema<T, S, M>, defaultValue: T)
	return transform(optional(sourceSchema))(function(value)
		if value == nil then
			return defaultValue
		end

		return value
	end)
end

return defaultSchemaBuilder
