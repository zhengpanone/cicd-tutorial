package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
)

var (
	version = flag.String("v", "v1", "server version")
	port    = flag.Int("p", 8080, "server port")
)

func main() {
	flag.Parse()
	router := gin.Default()

	router.GET("/", func(c *gin.Context) {

		hostname, _ := os.Hostname()
		c.String(200, "Version: %s, Hostname: %s", *version, hostname)
	})
	router.GET("/test", func(c *gin.Context) {
		flag.Parse()
		hostname, _ := os.Hostname()
		c.JSON(http.StatusOK, gin.H{
			"version":  *version,
			"hostname": hostname,
		})
	})

	router.Run(fmt.Sprintf(":%d", getPort()))
}

func getPort() int {
	if p := os.Getenv("PORT"); p != "" {
		if port, err := strconv.Atoi(p); err == nil {
			return port
		}
	}
	return *port
}
