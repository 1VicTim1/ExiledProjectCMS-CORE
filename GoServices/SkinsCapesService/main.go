package main

import (
	"context"
	"crypto/md5"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/joho/godotenv"
	"github.com/nfnt/resize"
	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
)

type SkinCapeService struct {
	DB          *gorm.DB
	RedisClient *redis.Client
	StoragePath string
}

type UserSkin struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserUUID  string    `gorm:"uniqueIndex;size:36" json:"user_uuid"`
	SkinURL   string    `gorm:"size:500" json:"skin_url"`
	CapeURL   string    `gorm:"size:500" json:"cape_url"`
	SkinHash  string    `gorm:"size:32" json:"skin_hash"`
	CapeHash  string    `gorm:"size:32" json:"cape_hash"`
	IsSlim    bool      `gorm:"default:false" json:"is_slim"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type SkinUploadRequest struct {
	UserUUID string `json:"user_uuid" binding:"required"`
	IsSlim   bool   `json:"is_slim"`
}

type ProfileResponse struct {
	ID         string            `json:"id"`
	Name       string            `json:"name"`
	Properties []ProfileProperty `json:"properties"`
}

type ProfileProperty struct {
	Name      string `json:"name"`
	Value     string `json:"value"`
	Signature string `json:"signature,omitempty"`
}

type TexturesValue struct {
	Timestamp   int64              `json:"timestamp"`
	ProfileID   string             `json:"profileId"`
	ProfileName string             `json:"profileName"`
	Textures    map[string]Texture `json:"textures"`
}

type Texture struct {
	URL      string            `json:"url"`
	Metadata map[string]string `json:"metadata,omitempty"`
}

func main() {
	// Загружаем переменные окружения
	if err := godotenv.Load("../../.env"); err != nil {
		log.Println("Warning: .env file not found, using system environment variables")
	}

	service := &SkinCapeService{
		StoragePath: getEnv("SKINS_STORAGE_PATH", "./storage/skins"),
	}

	// Инициализация базы данных
	if err := service.InitDatabase(); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}

	// Инициализация Redis (опционально)
	service.InitRedis()

	// Создаем директории для хранения
	os.MkdirAll(service.StoragePath+"/skins", 0755)
	os.MkdirAll(service.StoragePath+"/capes", 0755)
	os.MkdirAll(service.StoragePath+"/avatars", 0755)

	// Настройка Gin
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Статические файлы
	r.Static("/storage", service.StoragePath)

	// API маршруты
	api := r.Group("/api/v1")
	{
		// Minecraft профили
		api.GET("/profile/:uuid", service.GetProfile)
		api.POST("/profile/:uuid/skin", service.UploadSkin)
		api.POST("/profile/:uuid/cape", service.UploadCape)
		api.DELETE("/profile/:uuid/skin", service.DeleteSkin)
		api.DELETE("/profile/:uuid/cape", service.DeleteCape)

		// Совместимость с Mojang API
		api.GET("/textures/:uuid", service.GetTextures)

		// Генерация аватаров
		api.GET("/avatar/:uuid", service.GetAvatar)
		api.GET("/avatar/:uuid/:size", service.GetAvatarWithSize)

		// Head render
		api.GET("/head/:uuid", service.GetHead)
		api.GET("/head/:uuid/:size", service.GetHeadWithSize)

		// Администрирование
		admin := api.Group("/admin")
		{
			admin.GET("/stats", service.GetStats)
			admin.DELETE("/user/:uuid", service.DeleteUserData)
		}
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "skins-capes"})
	})

	port := getEnv("SKINS_CAPES_PORT", "8081")
	log.Printf("Skins & Capes Service started on port %s", port)
	log.Fatal(r.Run(":" + port))
}

func (s *SkinCapeService) InitDatabase() error {
	dbProvider := getEnv("DATABASE_PROVIDER", "SqlServer")
	connectionString := getEnv("DB_CONNECTION_STRING", "")

	if connectionString == "" {
		return fmt.Errorf("database connection string is required")
	}

	var db *gorm.DB
	var err error

	switch strings.ToLower(dbProvider) {
	case "mysql":
		db, err = gorm.Open(mysql.Open(connectionString), &gorm.Config{})
	case "postgresql", "postgres":
		db, err = gorm.Open(postgres.Open(connectionString), &gorm.Config{})
	case "sqlserver":
		db, err = gorm.Open(sqlserver.Open(connectionString), &gorm.Config{})
	default:
		return fmt.Errorf("unsupported database provider: %s", dbProvider)
	}

	if err != nil {
		return err
	}

	s.DB = db

	// Автомиграция
	return s.DB.AutoMigrate(&UserSkin{})
}

func (s *SkinCapeService) InitRedis() {
	redisAddr := getEnv("REDIS_HOST", "localhost") + ":" + getEnv("REDIS_PORT", "6379")
	redisPassword := getEnv("REDIS_PASSWORD", "")

	s.RedisClient = redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: redisPassword,
		DB:       1, // Используем другую БД для скинов
	})

	// Проверяем соединение
	ctx := context.Background()
	_, err := s.RedisClient.Ping(ctx).Result()
	if err != nil {
		log.Printf("Redis connection failed: %v", err)
		s.RedisClient = nil
	}
}

func (s *SkinCapeService) GetProfile(c *gin.Context) {
	uuid := c.Param("uuid")

	// Нормализуем UUID
	uuid = strings.ReplaceAll(uuid, "-", "")
	if len(uuid) != 32 {
		c.JSON(400, gin.H{"error": "Invalid UUID format"})
		return
	}

	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		// Если скин не найден, возвращаем пустой профиль
		c.JSON(200, ProfileResponse{
			ID:         uuid,
			Name:       "Player",
			Properties: []ProfileProperty{},
		})
		return
	}

	// Формируем текстуры
	textures := TexturesValue{
		Timestamp:   time.Now().Unix(),
		ProfileID:   uuid,
		ProfileName: "Player",
		Textures:    make(map[string]Texture),
	}

	baseURL := getEnv("BASE_URL", "http://localhost:8081")

	if userSkin.SkinURL != "" {
		texture := Texture{
			URL: baseURL + userSkin.SkinURL,
		}
		if userSkin.IsSlim {
			texture.Metadata = map[string]string{"model": "slim"}
		}
		textures.Textures["SKIN"] = texture
	}

	if userSkin.CapeURL != "" {
		textures.Textures["CAPE"] = Texture{
			URL: baseURL + userSkin.CapeURL,
		}
	}

	// Кодируем в base64
	texturesJSON, _ := json.Marshal(textures)
	texturesBase64 := base64.StdEncoding.EncodeToString(texturesJSON)

	response := ProfileResponse{
		ID:   uuid,
		Name: "Player",
		Properties: []ProfileProperty{
			{
				Name:  "textures",
				Value: texturesBase64,
			},
		},
	}

	c.JSON(200, response)
}

func (s *SkinCapeService) UploadSkin(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	file, header, err := c.Request.FormFile("skin")
	if err != nil {
		c.JSON(400, gin.H{"error": "No skin file provided"})
		return
	}
	defer file.Close()

	// Проверяем тип файла
	if !strings.HasPrefix(header.Header.Get("Content-Type"), "image/") {
		c.JSON(400, gin.H{"error": "File must be an image"})
		return
	}

	// Читаем и валидируем изображение
	img, err := png.Decode(file)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid PNG image"})
		return
	}

	// Проверяем размеры скина (64x64 или 64x32)
	bounds := img.Bounds()
	if bounds.Dx() != 64 || (bounds.Dy() != 64 && bounds.Dy() != 32) {
		c.JSON(400, gin.H{"error": "Skin must be 64x64 or 64x32 pixels"})
		return
	}

	// Определяем тип модели
	isSlim := c.PostForm("is_slim") == "true"

	// Генерируем хеш файла
	file.Seek(0, 0)
	hash := md5.New()
	io.Copy(hash, file)
	skinHash := fmt.Sprintf("%x", hash.Sum(nil))

	// Сохраняем файл
	filename := fmt.Sprintf("%s_skin.png", uuid)
	filepath := filepath.Join(s.StoragePath, "skins", filename)

	file.Seek(0, 0)
	dst, err := os.Create(filepath)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to save skin"})
		return
	}
	defer dst.Close()

	_, err = io.Copy(dst, file)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to save skin"})
		return
	}

	// Обновляем базу данных
	userSkin := UserSkin{
		UserUUID: uuid,
		IsSlim:   isSlim,
		SkinHash: skinHash,
	}

	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		// Создаем новую запись
		userSkin = UserSkin{
			UserUUID: uuid,
			SkinURL:  "/storage/skins/" + filename,
			IsSlim:   isSlim,
			SkinHash: skinHash,
		}
		s.DB.Create(&userSkin)
	} else {
		// Обновляем существующую
		userSkin.SkinURL = "/storage/skins/" + filename
		userSkin.IsSlim = isSlim
		userSkin.SkinHash = skinHash
		s.DB.Save(&userSkin)
	}

	// Очищаем кеш аватаров
	s.clearAvatarCache(uuid)

	c.JSON(200, gin.H{
		"message": "Skin uploaded successfully",
		"url":     "/storage/skins/" + filename,
	})
}

func (s *SkinCapeService) UploadCape(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	file, header, err := c.Request.FormFile("cape")
	if err != nil {
		c.JSON(400, gin.H{"error": "No cape file provided"})
		return
	}
	defer file.Close()

	// Проверяем тип файла
	if !strings.HasPrefix(header.Header.Get("Content-Type"), "image/") {
		c.JSON(400, gin.H{"error": "File must be an image"})
		return
	}

	// Читаем и валидируем изображение
	img, err := png.Decode(file)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid PNG image"})
		return
	}

	// Проверяем размеры плаща (64x32)
	bounds := img.Bounds()
	if bounds.Dx() != 64 || bounds.Dy() != 32 {
		c.JSON(400, gin.H{"error": "Cape must be 64x32 pixels"})
		return
	}

	// Генерируем хеш файла
	file.Seek(0, 0)
	hash := md5.New()
	io.Copy(hash, file)
	capeHash := fmt.Sprintf("%x", hash.Sum(nil))

	// Сохраняем файл
	filename := fmt.Sprintf("%s_cape.png", uuid)
	filepath := filepath.Join(s.StoragePath, "capes", filename)

	file.Seek(0, 0)
	dst, err := os.Create(filepath)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to save cape"})
		return
	}
	defer dst.Close()

	_, err = io.Copy(dst, file)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to save cape"})
		return
	}

	// Обновляем базу данных
	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		// Создаем новую запись
		userSkin = UserSkin{
			UserUUID: uuid,
			CapeURL:  "/storage/capes/" + filename,
			CapeHash: capeHash,
		}
		s.DB.Create(&userSkin)
	} else {
		// Обновляем существующую
		userSkin.CapeURL = "/storage/capes/" + filename
		userSkin.CapeHash = capeHash
		s.DB.Save(&userSkin)
	}

	c.JSON(200, gin.H{
		"message": "Cape uploaded successfully",
		"url":     "/storage/capes/" + filename,
	})
}

func (s *SkinCapeService) GetAvatar(c *gin.Context) {
	s.GetAvatarWithSize(c)
}

func (s *SkinCapeService) GetAvatarWithSize(c *gin.Context) {
	uuid := c.Param("uuid")
	sizeParam := c.Param("size")
	if sizeParam == "" {
		sizeParam = "64"
	}

	size, err := strconv.Atoi(sizeParam)
	if err != nil || size < 8 || size > 512 {
		c.JSON(400, gin.H{"error": "Invalid size parameter"})
		return
	}

	uuid = strings.ReplaceAll(uuid, "-", "")

	// Проверяем кеш
	cacheKey := fmt.Sprintf("avatar:%s:%d", uuid, size)
	if s.RedisClient != nil {
		cachedPath, err := s.RedisClient.Get(context.Background(), cacheKey).Result()
		if err == nil {
			c.File(cachedPath)
			return
		}
	}

	// Получаем скин пользователя
	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		// Используем дефолтный скин
		s.serveDefaultAvatar(c, size)
		return
	}

	if userSkin.SkinURL == "" {
		s.serveDefaultAvatar(c, size)
		return
	}

	// Генерируем аватар из скина
	avatarPath := s.generateAvatar(uuid, userSkin.SkinURL, size)
	if avatarPath == "" {
		s.serveDefaultAvatar(c, size)
		return
	}

	// Кешируем результат
	if s.RedisClient != nil {
		s.RedisClient.Set(context.Background(), cacheKey, avatarPath, time.Hour).Err()
	}

	c.File(avatarPath)
}

func (s *SkinCapeService) generateAvatar(uuid, skinURL string, size int) string {
	// Открываем файл скина
	skinPath := filepath.Join(".", skinURL)
	skinFile, err := os.Open(skinPath)
	if err != nil {
		return ""
	}
	defer skinFile.Close()

	// Декодируем скин
	skinImg, err := png.Decode(skinFile)
	if err != nil {
		return ""
	}

	// Извлекаем голову из скина (координаты 8,8 размер 8x8)
	headRect := image.Rect(8, 8, 16, 16)
	headImg := image.NewRGBA(image.Rect(0, 0, 8, 8))
	draw.Draw(headImg, headImg.Bounds(), skinImg, headRect.Min, draw.Src)

	// Масштабируем до нужного размера
	avatarImg := resize.Resize(uint(size), uint(size), headImg, resize.NearestNeighbor)

	// Сохраняем аватар
	avatarFilename := fmt.Sprintf("%s_avatar_%d.png", uuid, size)
	avatarPath := filepath.Join(s.StoragePath, "avatars", avatarFilename)

	avatarFile, err := os.Create(avatarPath)
	if err != nil {
		return ""
	}
	defer avatarFile.Close()

	err = png.Encode(avatarFile, avatarImg)
	if err != nil {
		return ""
	}

	return avatarPath
}

func (s *SkinCapeService) serveDefaultAvatar(c *gin.Context, size int) {
	// Создаем простой серый аватар по умолчанию
	img := image.NewRGBA(image.Rect(0, 0, size, size))
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			img.Set(x, y, color.RGBA{128, 128, 128, 255})
		}
	}

	c.Header("Content-Type", "image/png")
	png.Encode(c.Writer, img)
}

func (s *SkinCapeService) clearAvatarCache(uuid string) {
	if s.RedisClient == nil {
		return
	}

	// Очищаем все размеры аватаров для данного UUID
	pattern := fmt.Sprintf("avatar:%s:*", uuid)
	keys, err := s.RedisClient.Keys(context.Background(), pattern).Result()
	if err == nil {
		s.RedisClient.Del(context.Background(), keys...)
	}

	// Очищаем файлы аватаров
	avatarDir := filepath.Join(s.StoragePath, "avatars")
	files, _ := os.ReadDir(avatarDir)
	for _, file := range files {
		if strings.HasPrefix(file.Name(), uuid+"_avatar_") {
			os.Remove(filepath.Join(avatarDir, file.Name()))
		}
	}
}

func (s *SkinCapeService) GetStats(c *gin.Context) {
	var totalSkins int64
	var totalCapes int64

	s.DB.Model(&UserSkin{}).Where("skin_url != ''").Count(&totalSkins)
	s.DB.Model(&UserSkin{}).Where("cape_url != ''").Count(&totalCapes)

	c.JSON(200, gin.H{
		"total_skins": totalSkins,
		"total_capes": totalCapes,
		"service":     "skins-capes",
		"version":     "1.0.0",
	})
}

func (s *SkinCapeService) DeleteSkin(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		c.JSON(404, gin.H{"error": "Skin not found"})
		return
	}

	// Удаляем файл скина
	if userSkin.SkinURL != "" {
		skinPath := filepath.Join(".", userSkin.SkinURL)
		os.Remove(skinPath)
	}

	// Обновляем базу данных
	userSkin.SkinURL = ""
	userSkin.SkinHash = ""
	userSkin.IsSlim = false
	s.DB.Save(&userSkin)

	// Очищаем кеш аватаров
	s.clearAvatarCache(uuid)

	c.JSON(200, gin.H{"message": "Skin deleted successfully"})
}

func (s *SkinCapeService) DeleteCape(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		c.JSON(404, gin.H{"error": "Cape not found"})
		return
	}

	// Удаляем файл плаща
	if userSkin.CapeURL != "" {
		capePath := filepath.Join(".", userSkin.CapeURL)
		os.Remove(capePath)
	}

	// Обновляем базу данных
	userSkin.CapeURL = ""
	userSkin.CapeHash = ""
	s.DB.Save(&userSkin)

	c.JSON(200, gin.H{"message": "Cape deleted successfully"})
}

func (s *SkinCapeService) GetTextures(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		c.JSON(404, gin.H{"error": "Textures not found"})
		return
	}

	baseURL := getEnv("BASE_URL", "http://localhost:8081")
	textures := make(map[string]Texture)

	if userSkin.SkinURL != "" {
		texture := Texture{
			URL: baseURL + userSkin.SkinURL,
		}
		if userSkin.IsSlim {
			texture.Metadata = map[string]string{"model": "slim"}
		}
		textures["SKIN"] = texture
	}

	if userSkin.CapeURL != "" {
		textures["CAPE"] = Texture{
			URL: baseURL + userSkin.CapeURL,
		}
	}

	c.JSON(200, gin.H{"textures": textures})
}

func (s *SkinCapeService) GetHead(c *gin.Context) {
	s.GetHeadWithSize(c)
}

func (s *SkinCapeService) GetHeadWithSize(c *gin.Context) {
	uuid := c.Param("uuid")
	sizeParam := c.Param("size")
	if sizeParam == "" {
		sizeParam = "64"
	}

	size, err := strconv.Atoi(sizeParam)
	if err != nil || size < 8 || size > 512 {
		c.JSON(400, gin.H{"error": "Invalid size parameter"})
		return
	}

	uuid = strings.ReplaceAll(uuid, "-", "")

	// Проверяем кеш
	cacheKey := fmt.Sprintf("head:%s:%d", uuid, size)
	if s.RedisClient != nil {
		cachedPath, err := s.RedisClient.Get(context.Background(), cacheKey).Result()
		if err == nil {
			c.File(cachedPath)
			return
		}
	}

	// Получаем скин пользователя
	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		// Используем дефолтную голову
		s.serveDefaultHead(c, size)
		return
	}

	if userSkin.SkinURL == "" {
		s.serveDefaultHead(c, size)
		return
	}

	// Генерируем 3D голову из скина
	headPath := s.generateHead(uuid, userSkin.SkinURL, size)
	if headPath == "" {
		s.serveDefaultHead(c, size)
		return
	}

	// Кешируем результат
	if s.RedisClient != nil {
		s.RedisClient.Set(context.Background(), cacheKey, headPath, time.Hour).Err()
	}

	c.File(headPath)
}

func (s *SkinCapeService) generateHead(uuid, skinURL string, size int) string {
	// Открываем файл скина
	skinPath := filepath.Join(".", skinURL)
	skinFile, err := os.Open(skinPath)
	if err != nil {
		return ""
	}
	defer skinFile.Close()

	// Декодируем скин
	skinImg, err := png.Decode(skinFile)
	if err != nil {
		return ""
	}

	// Создаем 3D голову (извлекаем переднюю и боковые части)
	bounds := skinImg.Bounds()
	headImg := image.NewRGBA(image.Rect(0, 0, 8, 8))

	// Передняя часть головы (8,8 размер 8x8)
	frontRect := image.Rect(8, 8, 16, 16)
	draw.Draw(headImg, headImg.Bounds(), skinImg, frontRect.Min, draw.Src)

	// Если есть оверлей, накладываем его (40,8 размер 8x8)
	if bounds.Dx() >= 64 && bounds.Dy() >= 64 {
		overlayRect := image.Rect(40, 8, 48, 16)
		overlayImg := image.NewRGBA(image.Rect(0, 0, 8, 8))
		draw.Draw(overlayImg, overlayImg.Bounds(), skinImg, overlayRect.Min, draw.Src)

		// Накладываем оверлей с альфа-каналом
		draw.DrawMask(headImg, headImg.Bounds(), overlayImg, image.Point{}, overlayImg, image.Point{}, draw.Over)
	}

	// Масштабируем до нужного размера
	finalImg := resize.Resize(uint(size), uint(size), headImg, resize.NearestNeighbor)

	// Сохраняем голову
	headFilename := fmt.Sprintf("%s_head_%d.png", uuid, size)
	headPath := filepath.Join(s.StoragePath, "avatars", headFilename)

	headFile, err := os.Create(headPath)
	if err != nil {
		return ""
	}
	defer headFile.Close()

	err = png.Encode(headFile, finalImg)
	if err != nil {
		return ""
	}

	return headPath
}

func (s *SkinCapeService) serveDefaultHead(c *gin.Context, size int) {
	// Создаем простую голову по умолчанию
	img := image.NewRGBA(image.Rect(0, 0, size, size))
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			img.Set(x, y, color.RGBA{139, 69, 19, 255}) // Коричневый цвет
		}
	}

	c.Header("Content-Type", "image/png")
	png.Encode(c.Writer, img)
}

func (s *SkinCapeService) DeleteUserData(c *gin.Context) {
	uuid := c.Param("uuid")
	uuid = strings.ReplaceAll(uuid, "-", "")

	var userSkin UserSkin
	if err := s.DB.Where("user_uuid = ?", uuid).First(&userSkin).Error; err != nil {
		c.JSON(404, gin.H{"error": "User data not found"})
		return
	}

	// Удаляем файлы
	if userSkin.SkinURL != "" {
		skinPath := filepath.Join(".", userSkin.SkinURL)
		os.Remove(skinPath)
	}

	if userSkin.CapeURL != "" {
		capePath := filepath.Join(".", userSkin.CapeURL)
		os.Remove(capePath)
	}

	// Удаляем из базы данных
	s.DB.Delete(&userSkin)

	// Очищаем кеш
	s.clearAvatarCache(uuid)

	c.JSON(200, gin.H{"message": "User data deleted successfully"})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
