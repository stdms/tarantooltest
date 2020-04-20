# Тестовое задание mail.ru

Use following commands to build and run test app in docker

`docker build -t testapp -f Dockerfile .`
`docker run -p 8080:8080 testapp`

Use browser or any other program able to send http requests to access test application on
localhost:8080. Following URLs supported:

- POST /kv body: {key: "test", "value": {SOME ARBITRARY JSON}}
- PUT kv/{id} body: {"value": {SOME ARBITRARY JSON}}
- GET kv/{id}
- DELETE kv/{id}

Test suite has own dedicated Dockerfile. Use nex commands to build and run container with tests

`docker build -t testapp-test -f Dockerfile-test .`
`docker run testapp-test`

