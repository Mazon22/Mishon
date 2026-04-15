package app

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
)

func (s *Server) registerStaticRoutes(router chi.Router) {
	uploadsDir := filepath.Clean(strings.TrimSpace(s.cfg.UploadsDir))
	if uploadsDir != "." && uploadsDir != "" {
		if info, err := os.Stat(uploadsDir); err == nil && info.IsDir() {
			fileServer := http.StripPrefix("/uploads/", http.FileServer(http.Dir(uploadsDir)))
			router.Handle("/uploads/*", fileServer)
		}
	}

	distDir := filepath.Clean(s.cfg.WebDistDir)
	indexPath := filepath.Join(distDir, "index.html")
	if info, err := os.Stat(indexPath); err != nil || info.IsDir() {
		return
	}

	fileServer := http.FileServer(http.Dir(distDir))
	router.Get("/*", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimSpace(r.URL.Path)
		if path == "" || path == "/" {
			http.ServeFile(w, r, indexPath)
			return
		}

		cleanPath := filepath.Clean(strings.TrimPrefix(path, "/"))
		if strings.HasPrefix(cleanPath, "api") || cleanPath == "health" || strings.HasPrefix(cleanPath, "uploads") {
			http.NotFound(w, r)
			return
		}

		targetPath := filepath.Join(distDir, cleanPath)
		if info, err := os.Stat(targetPath); err == nil && !info.IsDir() {
			fileServer.ServeHTTP(w, r)
			return
		}

		http.ServeFile(w, r, indexPath)
	})
}
