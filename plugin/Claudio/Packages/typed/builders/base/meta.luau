const schema = require("../../schema")

const function metaSchemaBuilder<T, S, M, NewM>(sourceSchema: schema.Schema<T, S, M>, metadata: NewM): schema.Schema<T, S, NewM>
	const copiedSchema = schema.createSchema(sourceSchema.type, sourceSchema.parse, sourceSchema.shape)
	copiedSchema.metadata = metadata
	return copiedSchema
end

return metaSchemaBuilder
