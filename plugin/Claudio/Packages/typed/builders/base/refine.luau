const issue = require("../../issue")
const result = require("../../result")
const schema = require("../../schema")

type RefineResult<T> = {
	ok: () -> result.ParseResultOk<T>,
	err: (message: string) -> result.ParseResultErr,
}

const function refineSchemaBuilder<T, S, M>(sourceSchema: schema.Schema<T, S, M>)
	return function(refineFn: (value: T, result: RefineResult<T>) -> result.ParseResult<T>)
		return schema.createSchema<<T, schema.InnerSchema<S, M>>>("refine", function(value)
			const sourceSchemaParseResult = sourceSchema.parse(value)

			if not sourceSchemaParseResult.ok then
				return sourceSchemaParseResult
			end

			return refineFn(sourceSchemaParseResult.value, {
				ok = function()
					return result.parse.ok(sourceSchemaParseResult.value)
				end,
				err = function(message)
					return result.parse.err({
						issue.parse.refineError(message),
					})
				end,
			})
		end, schema.innerSchema(sourceSchema))
	end
end

return refineSchemaBuilder
