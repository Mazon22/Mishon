package main

import (
	"log"
	"net/http"

	"mishon/mishon-go-api/internal/app"
	"mishon/mishon-go-api/internal/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	server, err := app.New(cfg)
	if err != nil {
		log.Fatalf("start app: %v", err)
	}
	defer server.Close()

	log.Printf("Mishon Go API listening on :%s", cfg.Port)
	if err := http.ListenAndServe(":"+cfg.Port, server.Router()); err != nil {
		log.Fatalf("http server failed: %v", err)
	}
}
