dist/dployment.zip: main
	zip dist/deployment.zip main

main:
	go fmt main.go
	GOOS=linux go build -o main
	chmod 755 main

clean:
	rm -f main dist/deployment.zip
