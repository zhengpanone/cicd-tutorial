package main

import (
	"flag"
	"os"

	"github.com/gin-gonic/gin"
)

var version = flag.String("v", "v1", "v1")

func main() {
	router := gin.Default()

	router.GET("", func(c *gin.Context) {
		flag.Parse()
		hostname, _ := os.Hostname()
		c.String(200, "Version: %s, Hostname: %s", *version, hostname)
	})

	router.Run(":8080")
}
