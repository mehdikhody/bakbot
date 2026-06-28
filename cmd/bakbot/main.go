package main

import (
	"fmt"

	"github.com/mehdikhody/bakbot/internal/bot"
	"github.com/mehdikhody/bakbot/internal/version"
	"github.com/spf13/cobra"
)

var (
	ShowVersion bool
	Options     = &bot.Options{}
)

var cmd = &cobra.Command{
	Use:  "bakbot",
	Long: "backup your files via telegram bot",
	Run: func(cmd *cobra.Command, args []string) {
		if ShowVersion {
			printVersion()
			return
		}

		if Options.Filename != "" && Options.Token != "" && Options.ChatId != 0 {
			b, err := bot.New(Options)
			if err != nil {
				fmt.Println(err)
				return
			}

			err = b.Start()
			if err != nil {
				fmt.Println(err)
				return
			}

			return
		}

		fmt.Println()
		_ = cmd.Usage()
		printPredefinedSchedules()
	},
}

func main() {
	cmd.Flags().SortFlags = false
	cmd.Flags().StringVarP(&Options.Token, "token", "t", "", "(Required) telegram bot token")
	cmd.Flags().StringVarP(&Options.Filename, "file", "f", "", "(Required) file to backup")
	cmd.Flags().Int64VarP(&Options.ChatId, "chatId", "c", 0, "(Required) telegram target chatId")
	cmd.Flags().StringVarP(&Options.Proxy, "proxy", "p", "", "proxy url")
	cmd.Flags().StringVarP(&Options.Schedule, "schedule", "s", "", "cron schedule")
	cmd.Flags().BoolVarP(&Options.Send, "send", "s", false, "just send the backup file.")
	cmd.Flags().BoolVarP(&ShowVersion, "version", "v", false, "show version")

	cmd.SetHelpCommand(&cobra.Command{Hidden: true})
	cmd.CompletionOptions.DisableDefaultCmd = true
	_ = cmd.Execute()
}

func printVersion() {
	fmt.Println()
	fmt.Println("-------------- Bakbot --------------")
	fmt.Printf("%-10s %s\n", "Version:", version.Version)
	fmt.Printf("%-10s %s\n", "Commit:", version.Commit)
	fmt.Printf("%-10s %s\n", "Date:", version.Date)
	fmt.Println()
}

func printPredefinedSchedules() {
	fmt.Println()
	fmt.Println("|--------------------------------------------------------------------------------------------------|")
	fmt.Printf("| %-96s |\n", "Predefined schedules:")
	fmt.Printf("| %-96s |\n", "You may use one of several pre-defined schedules in place of a cron expression.")
	fmt.Println("|--------------------------------------------------------------------------------------------------|")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "Entry", "Description", "Equivalent To")
	fmt.Println("|---------------------------|----------------------------------------------------|-----------------|")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "@yearly (or @annually)", "Run once a year, midnight, Jan. 1st", "0 0 0 1 1 *")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "@monthly", "Run once a month, midnight, first of month", "0 0 0 1 * *")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "@weekly", "Run once a week, midnight between Sat/Sun", "0 0 0 * * 0")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "@daily (or @midnight)", "Run once a day, midnight", "0 0 0 * * *")
	fmt.Printf("| %-25s | %-50s | %-15s |\n", "@hourly", "Run once an hour, beginning of hour", "0 0 * * * *")
	fmt.Println("|--------------------------------------------------------------------------------------------------|")
	fmt.Println()
}
