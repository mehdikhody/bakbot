package bot

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/mehdikhody/bakbot/internal/utils"
	"github.com/robfig/cron/v3"
)

type Options struct {
	Filename string
	Token    string
	ChatId   int64
	Schedule string
	Proxy    string
}

type Bot struct {
	options  *Options
	api      *tgbotapi.BotAPI
	stopChan chan struct{}
}

func New(options *Options) (*Bot, error) {
	if !utils.FileExists(options.Filename) {
		return nil, fmt.Errorf("file %s does not exist", options.Filename)
	}

	var api *tgbotapi.BotAPI
	var err error

	if len(options.Proxy) == 0 {
		api, err = tgbotapi.NewBotAPI(options.Token)
		if err != nil {
			return nil, err
		}
	} else {
		proxyUrl, err := url.Parse(options.Proxy)
		if err != nil {
			return nil, fmt.Errorf("invalid proxy url: %s", options.Proxy)
		}

		client := &http.Client{
			Transport: &http.Transport{
				Proxy: http.ProxyURL(proxyUrl),
			},
		}

		endpoint := tgbotapi.APIEndpoint
		api, err = tgbotapi.NewBotAPIWithClient(options.Token, endpoint, client)
		if err != nil {
			return nil, err
		}
	}

	bot := &Bot{
		options:  options,
		api:      api,
		stopChan: make(chan struct{}),
	}

	return bot, nil
}

func (b *Bot) SendBackup() error {
	basename := filepath.Base(b.options.Filename)
	log.Printf("Taking a snapshot of %s ...\n", basename)
	if !utils.FileExists(b.options.Filename) {
		return fmt.Errorf("file %s does not exist", b.options.Filename)
	}

	now := time.Now()
	timestamp := now.Format("2006-01-02-15-04-05")
	dest := fmt.Sprintf("%s.zip", timestamp)
	err := utils.FileZip(b.options.Filename, dest)

	log.Printf("Uploading backup to telegram chat %d ...\n", b.options.ChatId)
	msg := tgbotapi.NewDocument(b.options.ChatId, tgbotapi.FilePath(dest))
	msg.Caption = fmt.Sprintf("**File:** `%s`\n**Date:** `%s`\n", basename, now.Format("2006-01-02 15:04:05"))
	msg.ParseMode = tgbotapi.ModeMarkdown

	res, err := b.api.Send(msg)
	if err != nil {
		return err
	}

	_ = os.Remove(dest)
	log.Printf("Backup was sent via message %d", res.MessageID)
	return nil
}

func (b *Bot) Start() error {
	log.Println("Testing by sending the first backup...")
	err := b.SendBackup()
	if err != nil {
		return err
	}

	c := cron.New(cron.WithSeconds())
	_, err = c.AddFunc(b.options.Schedule, func() {
		log.Println("Schedule triggered")
		err := b.SendBackup()
		if err != nil {
			log.Println(err)
		}
	})

	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	c.Start()
	log.Println("Bot is now running.  Press CTRL-C to exit.")

	select {
	case <-ctx.Done():
	case <-b.stopChan:
	}

	c.Stop()
	if err := utils.FileRemove("*.zip"); err != nil {
		log.Println("Error cleaning zip files:", err)
	}

	log.Println("Bot shutdown complete.")
	return nil
}

func (b *Bot) Stop() {
	log.Println("Stopping bot...")
	select {
	case b.stopChan <- struct{}{}:
	default:
	}
}
