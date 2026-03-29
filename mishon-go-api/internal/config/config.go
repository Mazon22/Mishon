package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port            string
	DatabaseURL     string
	JWTSecret       string
	JWTIssuer       string
	JWTAudience     string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
	AllowedOrigins  []string
	WebDistDir      string
}

func Load() (Config, error) {
	cfg := Config{
		Port:            getEnv("PORT", "8081"),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		JWTSecret:       os.Getenv("JWT_KEY"),
		JWTIssuer:       getEnv("JWT_ISSUER", "Mishon"),
		JWTAudience:     getEnv("JWT_AUDIENCE", "MishonUsers"),
		AccessTokenTTL:  time.Duration(getEnvInt("JWT_EXPIRE_MINUTES", 120)) * time.Minute,
		RefreshTokenTTL: time.Duration(getEnvInt("JWT_REFRESH_DAYS", 30)) * 24 * time.Hour,
		AllowedOrigins:  splitCSV(getEnv("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000")),
		WebDistDir:      getEnv("WEB_DIST_DIR", "../mishon-web/dist"),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	if cfg.JWTSecret == "" {
		return Config{}, fmt.Errorf("JWT_KEY is required")
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func getEnvInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			items = append(items, trimmed)
		}
	}
	return items
}
