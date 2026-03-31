package main

import (
	"fmt"
	"os"

	"github.com/mehdikhody/bakbot/internal/version"
	"github.com/spf13/cobra"
)

var cmd = &cobra.Command{
	Use:     "bakbot",
	Version: version.Version,
	Long:    "backup your files via telegram bot",
}

func main() {
	cmd.Flags().FuncP(
		"version",
		"v",
		"Print version",
		func(s string) error {
			fmt.Println("-------------- Bakbot --------------")
			fmt.Printf("Version: %10s\n", s)
			fmt.Printf("Commit: %10s\n", version.Commit)
			fmt.Printf("Date: %10s\n", version.Date)
			os.Exit(0)
			return nil
		},
	)

	cmd.SetHelpCommand(&cobra.Command{Hidden: true})
	cmd.CompletionOptions.DisableDefaultCmd = true
	if err := cmd.Execute(); err != nil {
		panic(err)
	}
}
