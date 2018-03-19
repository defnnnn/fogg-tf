package main

import (
	"context"
	"github.com/aws/aws-lambda-go/lambdacontext"
	aegis "github.com/tmaiaroto/aegis/framework"
	"log"
	"net/url"
)

func main() {
	// Handle an APIGatewayProxyRequest event with a URL reqeust path Router
	router := aegis.NewRouter(fallThrough)
	router.Handle("POST", "/hello", root, helloMiddleware)
	router.Listen()
}

// fallThrough handles any path that couldn't be matched to another handler
func fallThrough(ctx context.Context, req *aegis.APIGatewayProxyRequest, res *aegis.APIGatewayProxyResponse, params url.Values) {
	lc, _ := lambdacontext.FromContext(ctx)
	res.JSON(404, map[string]interface{}{"event": req, "context": lc})
}

// root is handling GET "/" in this case
func root(ctx context.Context, req *aegis.APIGatewayProxyRequest, res *aegis.APIGatewayProxyResponse, params url.Values) {
	lc, _ := lambdacontext.FromContext(ctx)
	res.JSON(200, map[string]interface{}{"event": req, "context": lc})
}

// helloMiddleware is a simple example of middleware
func helloMiddleware(ctx context.Context, req *aegis.APIGatewayProxyRequest, res *aegis.APIGatewayProxyResponse, params url.Values) bool {
	log.Println("Hello CloudWatch!")
	return true
}
