const result = require("../../result")
const schema = require("../../schema")

const function transformSchemaBuilder<T, S, M>(sourceSchema: schema.Schema<T, S, M>)
	return function<R>(transformFn: (T) -> R)
		return schema.createSchema<<R, schema.InnerSchema<S, M>>>("transform", function(value)
			const sourceSchemaParseResult = sourceSchema.parse(value)

			if not sourceSchemaParseResult.ok then
				return sourceSchemaParseResult
			end

			return result.parse.ok(transformFn(sourceSchemaParseResult.value))
		end, schema.innerSchema(sourceSchema))
	end
end

return transformSchemaBuilder
