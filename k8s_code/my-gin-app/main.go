package main

import (
	"flag"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

var version = flag.String("v", "v1", "v1")

func main() {
	router := gin.Default()

	router.GET("/", func(c *gin.Context) {
		flag.Parse()
		hostname, _ := os.Hostname()
		c.String(200, "Version: %s, Hostname: %s", *version, hostname)
	})
	router.GET("/test", func(c *gin.Context) {
		flag.Parse()
		hostname, _ := os.Hostname()
		c.JSON(http.StatusOK, gin.H{
			"path":     c.Param("path"),
			"version":  *version,
			"hostname": hostname,
		})
	})

	router.Run(":8080")
}
