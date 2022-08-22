var { graphql, buildSchema } = require('graphql');

// Construct a schema, using GraphQL schema language
var schema = buildSchema(`
  type result {
    arg1: Float!
  }

  type Query {
    test(arg1: Float!): result
  }
`);

// The rootValue provides a resolver function for each API endpoint
var rootValue = {
  test: (args) => {
    return args;
  },
};

// Run the GraphQL query '{ hello }' and print out the response
graphql({
  schema,
  source: '{ test(arg1: 1.1111111)  { arg1 } }',
  rootValue
}).then((response) => {
  console.log(JSON.parse(JSON.stringify(response.data)));
});
