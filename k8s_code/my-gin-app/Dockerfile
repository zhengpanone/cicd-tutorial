FROM golang:1.25.4-alpine AS builder

WORKDIR /go/src/github.com/zhengpan/my-gin-app
COPY . /go/src/github.com/zhengpan/my-gin-app
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go env -w GO111MODULE=on
RUN CGO_ENABLED=0 go build -v -o my-gin-app .

FROM alpine AS runtime
RUN mkdir /app
COPY --from=builder /go/src/github.com/zhengpan/my-gin-app/my-gin-app /app/my-gin-app
WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["./my-gin-app", "-v", "1.3"]