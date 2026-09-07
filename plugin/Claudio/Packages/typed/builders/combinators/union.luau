const issue = require("../../issue")
const result = require("../../result")
const schema = require("../../schema")
const shared = require("../../shared")

const function unionSchema<T0, T0S, T0M, T1, T1S, T1M>(sourceSchemaA: schema.Schema<T0, T0S, T0M>, sourceSchemaB: schema.Schema<T1, T1S, T1M>)
	return schema.createSchema<<T0 | T1, { left: schema.InnerSchema<T0S, T0M>, right: schema.InnerSchema<T1S, T1M> }>>(
		"union",
		function(value)
			const parseResult0 = sourceSchemaA.parse(value)

			if parseResult0.ok then
				return parseResult0
			end

			const parseResult1 = sourceSchemaB.parse(value)

			if parseResult1.ok then
				return parseResult1
			end

			return result.parse.err(shared.joinArrays(parseResult0.issues, parseResult1.issues))
		end,
		{
			-- luau being funny once again
			left = schema.innerSchema(sourceSchemaA) :: schema.InnerSchema<T0S, T0M>,
			right = schema.innerSchema(sourceSchemaB) :: schema.InnerSchema<T1S, T1M>,
		}
	)
end

return unionSchema
