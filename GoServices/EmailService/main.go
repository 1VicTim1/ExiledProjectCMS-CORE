package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"gopkg.in/gomail.v2"
	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
)

type EmailService struct {
	DB          *gorm.DB
	RedisClient *redis.Client
	SMTPConfig  SMTPConfig
}

type SMTPConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
	UseTLS   bool
}

type EmailLog struct {
	ID        uint       `gorm:"primaryKey" json:"id"`
	MessageID string     `gorm:"uniqueIndex;size:100" json:"message_id"`
	To        string     `gorm:"size:255" json:"to"`
	Subject   string     `gorm:"size:500" json:"subject"`
	Body      string     `gorm:"type:text" json:"body"`
	Status    string     `gorm:"size:50" json:"status"` // sent, failed, pending
	Error     string     `gorm:"size:1000" json:"error"`
	Attempts  int        `gorm:"default:0" json:"attempts"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	SentAt    *time.Time `json:"sent_at"`
}

type EmailRequest struct {
	To       []string               `json:"to" binding:"required"`
	Subject  string                 `json:"subject" binding:"required"`
	Template string                 `json:"template"`
	Body     string                 `json:"body"`
	Data     map[string]interface{} `json:"data"`
	Priority string                 `json:"priority"` // high, normal, low
}

type BulkEmailRequest struct {
	Recipients []EmailRecipient       `json:"recipients" binding:"required"`
	Subject    string                 `json:"subject" binding:"required"`
	Template   string                 `json:"template"`
	Body       string                 `json:"body"`
	Data       map[string]interface{} `json:"data"`
}

type EmailRecipient struct {
	Email string                 `json:"email" binding:"required"`
	Data  map[string]interface{} `json:"data"`
}

type EmailTemplate struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Name      string    `gorm:"uniqueIndex;size:100" json:"name"`
	Subject   string    `gorm:"size:500" json:"subject"`
	HTMLBody  string    `gorm:"type:text" json:"html_body"`
	TextBody  string    `gorm:"type:text" json:"text_body"`
	Variables string    `gorm:"type:text" json:"variables"` // JSON array of variable names
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func main() {
	// Загружаем переменные окружения
	if err := godotenv.Load("../../.env"); err != nil {
		log.Println("Warning: .env file not found, using system environment variables")
	}

	service := &EmailService{}

	// Инициализация SMTP конфигурации
	service.initSMTPConfig()

	// Инициализация базы данных
	if err := service.InitDatabase(); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}

	// Инициализация Redis (опционально)
	service.InitRedis()

	// Создаем стандартные шаблоны
	service.createDefaultTemplates()

	// Запускаем фоновую обработку очереди
	go service.processEmailQueue()

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

	// API маршруты
	api := r.Group("/api/v1")
	{
		// Отправка писем
		api.POST("/email/send", service.SendEmail)
		api.POST("/email/send/bulk", service.SendBulkEmail)
		api.POST("/email/send/template", service.SendTemplateEmail)

		// Шаблоны
		templates := api.Group("/templates")
		{
			templates.GET("/", service.GetTemplates)
			templates.GET("/:name", service.GetTemplate)
			templates.POST("/", service.CreateTemplate)
			templates.PUT("/:name", service.UpdateTemplate)
			templates.DELETE("/:name", service.DeleteTemplate)
		}

		// Логи и статистика
		api.GET("/email/logs", service.GetEmailLogs)
		api.GET("/email/logs/:id", service.GetEmailLog)
		api.GET("/email/stats", service.GetEmailStats)
		api.POST("/email/retry/:id", service.RetryEmail)

		// Тестирование
		api.POST("/email/test", service.TestSMTPConnection)

		// Webhooks (для обработки уведомлений от почтовых провайдеров)
		api.POST("/webhooks/email/delivered", service.HandleEmailDelivered)
		api.POST("/webhooks/email/bounced", service.HandleEmailBounced)
		api.POST("/webhooks/email/complained", service.HandleEmailComplained)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "email"})
	})

	port := getEnv("EMAIL_SERVICE_PORT", "8082")
	log.Printf("Email Service started on port %s", port)
	log.Fatal(r.Run(":" + port))
}

func (s *EmailService) initSMTPConfig() {
	port, _ := strconv.Atoi(getEnv("SMTP_PORT", "587"))

	s.SMTPConfig = SMTPConfig{
		Host:     getEnv("SMTP_HOST", "localhost"),
		Port:     port,
		Username: getEnv("SMTP_USERNAME", ""),
		Password: getEnv("SMTP_PASSWORD", ""),
		From:     getEnv("SMTP_FROM", "noreply@example.com"),
		UseTLS:   getEnv("SMTP_USE_TLS", "true") == "true",
	}
}

func (s *EmailService) InitDatabase() error {
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
	return s.DB.AutoMigrate(&EmailLog{}, &EmailTemplate{})
}

func (s *EmailService) InitRedis() {
	redisAddr := getEnv("REDIS_HOST", "localhost") + ":" + getEnv("REDIS_PORT", "6379")
	redisPassword := getEnv("REDIS_PASSWORD", "")

	s.RedisClient = redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: redisPassword,
		DB:       2, // Используем отдельную БД для email
	})

	// Проверяем соединение
	ctx := context.Background()
	_, err := s.RedisClient.Ping(ctx).Result()
	if err != nil {
		log.Printf("Redis connection failed: %v", err)
		s.RedisClient = nil
	}
}

func (s *EmailService) SendEmail(c *gin.Context) {
	var request EmailRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(400, gin.H{"error": "Invalid request format"})
		return
	}

	// Валидация email адресов
	for _, email := range request.To {
		if !isValidEmail(email) {
			c.JSON(400, gin.H{"error": fmt.Sprintf("Invalid email address: %s", email)})
			return
		}
	}

	messageID := uuid.New().String()

	// Если указан шаблон, используем его
	var body string
	var subject string

	if request.Template != "" {
		var tmpl EmailTemplate
		if err := s.DB.Where("name = ? AND is_active = ?", request.Template, true).First(&tmpl).Error; err != nil {
			c.JSON(404, gin.H{"error": "Template not found"})
			return
		}

		// Рендерим шаблон
		renderedBody, renderedSubject, err := s.renderTemplate(tmpl, request.Data)
		if err != nil {
			c.JSON(500, gin.H{"error": "Failed to render template"})
			return
		}

		body = renderedBody
		subject = renderedSubject
	} else {
		body = request.Body
		subject = request.Subject
	}

	// Создаем лог записи для каждого получателя
	for _, recipient := range request.To {
		emailLog := EmailLog{
			MessageID: messageID + "_" + recipient,
			To:        recipient,
			Subject:   subject,
			Body:      body,
			Status:    "pending",
		}
		s.DB.Create(&emailLog)

		// Добавляем в очередь Redis (если доступен)
		if s.RedisClient != nil {
			emailData := map[string]interface{}{
				"id":       emailLog.ID,
				"to":       recipient,
				"subject":  subject,
				"body":     body,
				"priority": request.Priority,
			}
			emailJSON, _ := json.Marshal(emailData)

			queueName := "email_queue:normal"
			if request.Priority == "high" {
				queueName = "email_queue:high"
			} else if request.Priority == "low" {
				queueName = "email_queue:low"
			}

			s.RedisClient.LPush(context.Background(), queueName, emailJSON)
		} else {
			// Отправляем напрямую если нет Redis
			go s.sendEmailDirect(emailLog.ID, recipient, subject, body)
		}
	}

	c.JSON(200, gin.H{
		"message":    "Email queued for sending",
		"message_id": messageID,
		"recipients": len(request.To),
	})
}

func (s *EmailService) SendBulkEmail(c *gin.Context) {
	var request BulkEmailRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(400, gin.H{"error": "Invalid request format"})
		return
	}

	// Валидация
	if len(request.Recipients) > 1000 {
		c.JSON(400, gin.H{"error": "Too many recipients (max 1000)"})
		return
	}

	messageID := uuid.New().String()
	processedCount := 0

	for _, recipient := range request.Recipients {
		if !isValidEmail(recipient.Email) {
			log.Printf("Skipping invalid email: %s", recipient.Email)
			continue
		}

		// Объединяем глобальные данные с данными получателя
		mergedData := make(map[string]interface{})
		for k, v := range request.Data {
			mergedData[k] = v
		}
		for k, v := range recipient.Data {
			mergedData[k] = v
		}

		var body, subject string
		if request.Template != "" {
			var tmpl EmailTemplate
			if err := s.DB.Where("name = ? AND is_active = ?", request.Template, true).First(&tmpl).Error; err != nil {
				log.Printf("Template not found: %s", request.Template)
				continue
			}

			renderedBody, renderedSubject, err := s.renderTemplate(tmpl, mergedData)
			if err != nil {
				log.Printf("Failed to render template for %s: %v", recipient.Email, err)
				continue
			}

			body = renderedBody
			subject = renderedSubject
		} else {
			body = request.Body
			subject = request.Subject
		}

		// Создаем лог запись
		emailLog := EmailLog{
			MessageID: messageID + "_" + recipient.Email,
			To:        recipient.Email,
			Subject:   subject,
			Body:      body,
			Status:    "pending",
		}
		s.DB.Create(&emailLog)

		// Добавляем в очередь
		if s.RedisClient != nil {
			emailData := map[string]interface{}{
				"id":      emailLog.ID,
				"to":      recipient.Email,
				"subject": subject,
				"body":    body,
			}
			emailJSON, _ := json.Marshal(emailData)
			s.RedisClient.LPush(context.Background(), "email_queue:normal", emailJSON)
		} else {
			go s.sendEmailDirect(emailLog.ID, recipient.Email, subject, body)
		}

		processedCount++
	}

	c.JSON(200, gin.H{
		"message":          "Bulk email queued for sending",
		"message_id":       messageID,
		"processed_count":  processedCount,
		"total_recipients": len(request.Recipients),
	})
}

func (s *EmailService) sendEmailDirect(logID uint, to, subject, body string) {
	// Обновляем статус на "отправляется"
	s.DB.Model(&EmailLog{}).Where("id = ?", logID).Updates(map[string]interface{}{
		"status":   "sending",
		"attempts": gorm.Expr("attempts + 1"),
	})

	// Создаем сообщение
	m := gomail.NewMessage()
	m.SetHeader("From", s.SMTPConfig.From)
	m.SetHeader("To", to)
	m.SetHeader("Subject", subject)
	m.SetBody("text/html", body)

	// Настраиваем SMTP диалер
	d := gomail.NewDialer(s.SMTPConfig.Host, s.SMTPConfig.Port, s.SMTPConfig.Username, s.SMTPConfig.Password)

	if s.SMTPConfig.UseTLS {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: false}
	}

	// Отправляем email
	if err := d.DialAndSend(m); err != nil {
		// Обновляем статус на "ошибка"
		s.DB.Model(&EmailLog{}).Where("id = ?", logID).Updates(map[string]interface{}{
			"status": "failed",
			"error":  err.Error(),
		})
		log.Printf("Failed to send email to %s: %v", to, err)
	} else {
		// Обновляем статус на "отправлено"
		now := time.Now()
		s.DB.Model(&EmailLog{}).Where("id = ?", logID).Updates(map[string]interface{}{
			"status":  "sent",
			"sent_at": &now,
		})
		log.Printf("Email sent successfully to %s", to)
	}
}

func (s *EmailService) processEmailQueue() {
	if s.RedisClient == nil {
		log.Println("Redis not available, email queue processing disabled")
		return
	}

	log.Println("Starting email queue processor")

	for {
		ctx := context.Background()

		// Обрабатываем очереди по приоритету
		queues := []string{"email_queue:high", "email_queue:normal", "email_queue:low"}

		for _, queue := range queues {
			result, err := s.RedisClient.BRPop(ctx, time.Second*1, queue).Result()
			if err != nil || len(result) < 2 {
				continue
			}

			var emailData map[string]interface{}
			if err := json.Unmarshal([]byte(result[1]), &emailData); err != nil {
				log.Printf("Failed to unmarshal email data: %v", err)
				continue
			}

			logID := uint(emailData["id"].(float64))
			to := emailData["to"].(string)
			subject := emailData["subject"].(string)
			body := emailData["body"].(string)

			// Отправляем email
			s.sendEmailDirect(logID, to, subject, body)

			// Добавляем небольшую задержку для предотвращения спама
			time.Sleep(time.Millisecond * 100)
		}

		// Небольшая пауза между циклами
		time.Sleep(time.Millisecond * 500)
	}
}

func (s *EmailService) renderTemplate(tmpl EmailTemplate, data map[string]interface{}) (string, string, error) {
	// Рендерим HTML тело
	htmlTmpl, err := template.New("html").Parse(tmpl.HTMLBody)
	if err != nil {
		return "", "", err
	}

	var htmlBuffer strings.Builder
	if err := htmlTmpl.Execute(&htmlBuffer, data); err != nil {
		return "", "", err
	}

	// Рендерим тему
	subjectTmpl, err := template.New("subject").Parse(tmpl.Subject)
	if err != nil {
		return "", "", err
	}

	var subjectBuffer strings.Builder
	if err := subjectTmpl.Execute(&subjectBuffer, data); err != nil {
		return "", "", err
	}

	return htmlBuffer.String(), subjectBuffer.String(), nil
}

func (s *EmailService) createDefaultTemplates() {
	templates := []EmailTemplate{
		{
			Name:      "welcome",
			Subject:   "Добро пожаловать, {{.Name}}!",
			HTMLBody:  `<h1>Добро пожаловать на наш сервер, {{.Name}}!</h1><p>Спасибо за регистрацию. Ваш UUID: {{.UUID}}</p>`,
			TextBody:  "Добро пожаловать на наш сервер, {{.Name}}! Спасибо за регистрацию. Ваш UUID: {{.UUID}}",
			Variables: `["Name", "UUID"]`,
		},
		{
			Name:      "password_reset",
			Subject:   "Сброс пароля",
			HTMLBody:  `<h1>Сброс пароля</h1><p>Для сброса пароля перейдите по <a href="{{.ResetLink}}">этой ссылке</a></p>`,
			TextBody:  "Для сброса пароля перейдите по ссылке: {{.ResetLink}}",
			Variables: `["ResetLink"]`,
		},
		{
			Name:      "news_notification",
			Subject:   "Новость: {{.Title}}",
			HTMLBody:  `<h1>{{.Title}}</h1><p>{{.Description}}</p><p><a href="{{.NewsLink}}">Читать полностью</a></p>`,
			TextBody:  "{{.Title}}\n\n{{.Description}}\n\nЧитать полностью: {{.NewsLink}}",
			Variables: `["Title", "Description", "NewsLink"]`,
		},
	}

	for _, tmpl := range templates {
		var existing EmailTemplate
		if err := s.DB.Where("name = ?", tmpl.Name).First(&existing).Error; err != nil {
			s.DB.Create(&tmpl)
			log.Printf("Created default template: %s", tmpl.Name)
		}
	}
}

func (s *EmailService) TestSMTPConnection(c *gin.Context) {
	// Создаем тестовое сообщение
	m := gomail.NewMessage()
	m.SetHeader("From", s.SMTPConfig.From)
	m.SetHeader("To", s.SMTPConfig.From) // Отправляем себе
	m.SetHeader("Subject", "SMTP Test")
	m.SetBody("text/plain", "This is a test message from ExiledProjectCMS Email Service")

	// Настраиваем SMTP диалер
	d := gomail.NewDialer(s.SMTPConfig.Host, s.SMTPConfig.Port, s.SMTPConfig.Username, s.SMTPConfig.Password)

	if s.SMTPConfig.UseTLS {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: false}
	}

	// Тестируем соединение
	if err := d.DialAndSend(m); err != nil {
		c.JSON(500, gin.H{
			"error":   "SMTP connection failed",
			"details": err.Error(),
		})
		return
	}

	c.JSON(200, gin.H{
		"message": "SMTP connection successful",
		"config": gin.H{
			"host": s.SMTPConfig.Host,
			"port": s.SMTPConfig.Port,
			"from": s.SMTPConfig.From,
		},
	})
}

func (s *EmailService) GetEmailStats(c *gin.Context) {
	var totalEmails int64
	var sentEmails int64
	var failedEmails int64
	var pendingEmails int64

	s.DB.Model(&EmailLog{}).Count(&totalEmails)
	s.DB.Model(&EmailLog{}).Where("status = ?", "sent").Count(&sentEmails)
	s.DB.Model(&EmailLog{}).Where("status = ?", "failed").Count(&failedEmails)
	s.DB.Model(&EmailLog{}).Where("status = ?", "pending").Count(&pendingEmails)

	c.JSON(200, gin.H{
		"total_emails":   totalEmails,
		"sent_emails":    sentEmails,
		"failed_emails":  failedEmails,
		"pending_emails": pendingEmails,
		"service":        "email",
		"version":        "1.0.0",
	})
}

func isValidEmail(email string) bool {
	// Простая валидация email
	return strings.Contains(email, "@") && strings.Contains(email, ".")
}

func (s *EmailService) GetTemplates(c *gin.Context) {
	var templates []EmailTemplate
	if err := s.DB.Where("is_active = ?", true).Find(&templates).Error; err != nil {
		c.JSON(500, gin.H{"error": "Failed to fetch templates"})
		return
	}

	c.JSON(200, gin.H{"templates": templates})
}

func (s *EmailService) GetTemplate(c *gin.Context) {
	name := c.Param("name")

	var template EmailTemplate
	if err := s.DB.Where("name = ? AND is_active = ?", name, true).First(&template).Error; err != nil {
		c.JSON(404, gin.H{"error": "Template not found"})
		return
	}

	c.JSON(200, template)
}

func (s *EmailService) CreateTemplate(c *gin.Context) {
	var template EmailTemplate
	if err := c.ShouldBindJSON(&template); err != nil {
		c.JSON(400, gin.H{"error": "Invalid template format"})
		return
	}

	// Проверяем уникальность имени
	var existing EmailTemplate
	if err := s.DB.Where("name = ?", template.Name).First(&existing).Error; err == nil {
		c.JSON(409, gin.H{"error": "Template with this name already exists"})
		return
	}

	if err := s.DB.Create(&template).Error; err != nil {
		c.JSON(500, gin.H{"error": "Failed to create template"})
		return
	}

	c.JSON(201, template)
}

func (s *EmailService) UpdateTemplate(c *gin.Context) {
	name := c.Param("name")

	var template EmailTemplate
	if err := s.DB.Where("name = ?", name).First(&template).Error; err != nil {
		c.JSON(404, gin.H{"error": "Template not found"})
		return
	}

	var updateData EmailTemplate
	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(400, gin.H{"error": "Invalid template format"})
		return
	}

	// Обновляем поля
	template.Subject = updateData.Subject
	template.HTMLBody = updateData.HTMLBody
	template.TextBody = updateData.TextBody
	template.Variables = updateData.Variables
	template.IsActive = updateData.IsActive

	if err := s.DB.Save(&template).Error; err != nil {
		c.JSON(500, gin.H{"error": "Failed to update template"})
		return
	}

	c.JSON(200, template)
}

func (s *EmailService) DeleteTemplate(c *gin.Context) {
	name := c.Param("name")

	var template EmailTemplate
	if err := s.DB.Where("name = ?", name).First(&template).Error; err != nil {
		c.JSON(404, gin.H{"error": "Template not found"})
		return
	}

	// Мягкое удаление - деактивируем шаблон
	template.IsActive = false
	if err := s.DB.Save(&template).Error; err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete template"})
		return
	}

	c.JSON(200, gin.H{"message": "Template deleted successfully"})
}

func (s *EmailService) GetEmailLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	status := c.Query("status")

	offset := (page - 1) * limit

	query := s.DB.Model(&EmailLog{})
	if status != "" {
		query = query.Where("status = ?", status)
	}

	var logs []EmailLog
	var total int64

	query.Count(&total)
	if err := query.Order("created_at DESC").Offset(offset).Limit(limit).Find(&logs).Error; err != nil {
		c.JSON(500, gin.H{"error": "Failed to fetch email logs"})
		return
	}

	c.JSON(200, gin.H{
		"logs":        logs,
		"total":       total,
		"page":        page,
		"limit":       limit,
		"total_pages": (total + int64(limit) - 1) / int64(limit),
	})
}

func (s *EmailService) GetEmailLog(c *gin.Context) {
	id := c.Param("id")

	var log EmailLog
	if err := s.DB.Where("id = ?", id).First(&log).Error; err != nil {
		c.JSON(404, gin.H{"error": "Email log not found"})
		return
	}

	c.JSON(200, log)
}

func (s *EmailService) RetryEmail(c *gin.Context) {
	id := c.Param("id")

	var log EmailLog
	if err := s.DB.Where("id = ?", id).First(&log).Error; err != nil {
		c.JSON(404, gin.H{"error": "Email log not found"})
		return
	}

	if log.Status == "sent" {
		c.JSON(400, gin.H{"error": "Email already sent successfully"})
		return
	}

	// Сброс статуса для повторной отправки
	log.Status = "pending"
	log.Error = ""
	s.DB.Save(&log)

	// Добавляем в очередь
	if s.RedisClient != nil {
		emailData := map[string]interface{}{
			"id":      log.ID,
			"to":      log.To,
			"subject": log.Subject,
			"body":    log.Body,
		}
		emailJSON, _ := json.Marshal(emailData)
		s.RedisClient.LPush(context.Background(), "email_queue:high", emailJSON)
	} else {
		go s.sendEmailDirect(log.ID, log.To, log.Subject, log.Body)
	}

	c.JSON(200, gin.H{"message": "Email queued for retry"})
}

func (s *EmailService) SendTemplateEmail(c *gin.Context) {
	var request struct {
		To       []string               `json:"to" binding:"required"`
		Template string                 `json:"template" binding:"required"`
		Data     map[string]interface{} `json:"data"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(400, gin.H{"error": "Invalid request format"})
		return
	}

	// Конвертируем в стандартный EmailRequest
	emailRequest := EmailRequest{
		To:       request.To,
		Template: request.Template,
		Data:     request.Data,
		Priority: "normal",
	}

	// Используем существующий метод
	c.Set("email_request", emailRequest)
	s.SendEmail(c)
}

func (s *EmailService) HandleEmailDelivered(c *gin.Context) {
	var webhook struct {
		MessageID string `json:"message_id"`
		Email     string `json:"email"`
		Timestamp int64  `json:"timestamp"`
	}

	if err := c.ShouldBindJSON(&webhook); err != nil {
		c.JSON(400, gin.H{"error": "Invalid webhook format"})
		return
	}

	// Обновляем статус в базе данных
	s.DB.Model(&EmailLog{}).Where("message_id = ?", webhook.MessageID).Updates(map[string]interface{}{
		"status": "delivered",
	})

	log.Printf("Email delivered: %s to %s", webhook.MessageID, webhook.Email)
	c.JSON(200, gin.H{"message": "Webhook processed"})
}

func (s *EmailService) HandleEmailBounced(c *gin.Context) {
	var webhook struct {
		MessageID string `json:"message_id"`
		Email     string `json:"email"`
		Reason    string `json:"reason"`
		Timestamp int64  `json:"timestamp"`
	}

	if err := c.ShouldBindJSON(&webhook); err != nil {
		c.JSON(400, gin.H{"error": "Invalid webhook format"})
		return
	}

	// Обновляем статус в базе данных
	s.DB.Model(&EmailLog{}).Where("message_id = ?", webhook.MessageID).Updates(map[string]interface{}{
		"status": "bounced",
		"error":  webhook.Reason,
	})

	log.Printf("Email bounced: %s to %s, reason: %s", webhook.MessageID, webhook.Email, webhook.Reason)
	c.JSON(200, gin.H{"message": "Webhook processed"})
}

func (s *EmailService) HandleEmailComplained(c *gin.Context) {
	var webhook struct {
		MessageID string `json:"message_id"`
		Email     string `json:"email"`
		Timestamp int64  `json:"timestamp"`
	}

	if err := c.ShouldBindJSON(&webhook); err != nil {
		c.JSON(400, gin.H{"error": "Invalid webhook format"})
		return
	}

	// Обновляем статус в базе данных
	s.DB.Model(&EmailLog{}).Where("message_id = ?", webhook.MessageID).Updates(map[string]interface{}{
		"status": "complained",
	})

	log.Printf("Email complaint: %s to %s", webhook.MessageID, webhook.Email)
	c.JSON(200, gin.H{"message": "Webhook processed"})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
