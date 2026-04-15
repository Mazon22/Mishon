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
	PublicBaseURL   string
	WebDistDir      string
	UploadsDir      string
	SMTPHost        string
	SMTPPort        int
	SMTPUsername    string
	SMTPPassword    string
	SMTPFrom        string
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
		AllowedOrigins:  splitCSV(getEnv("CORS_ORIGINS", defaultCORSOrigins())),
		PublicBaseURL:   strings.TrimRight(getEnv("PUBLIC_BASE_URL", "http://localhost:8081"), "/"),
		WebDistDir:      getEnv("WEB_DIST_DIR", "../mishon-web/dist"),
		UploadsDir:      getEnvOrDefaultWhenUnset("UPLOADS_DIR", ""),
		SMTPHost:        getEnv("SMTP_HOST", ""),
		SMTPPort:        getEnvInt("SMTP_PORT", 587),
		SMTPUsername:    getEnv("SMTP_USERNAME", ""),
		SMTPPassword:    getEnv("SMTP_PASSWORD", ""),
		SMTPFrom:        getEnv("SMTP_FROM", ""),
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

func getEnvOrDefaultWhenUnset(key, fallback string) string {
	value, ok := os.LookupEnv(key)
	if !ok {
		return fallback
	}
	return strings.TrimSpace(value)
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

func defaultCORSOrigins() string {
	return strings.Join([]string{
		"http://localhost:*",
		"http://127.0.0.1:*",
		"https://localhost:*",
		"https://127.0.0.1:*",
	}, ",")
}
