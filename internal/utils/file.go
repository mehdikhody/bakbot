package utils

import (
	"os"
	"path/filepath"

	"github.com/bmatcuk/doublestar/v4"
	"github.com/mholt/archiver/v3"
)

func FileExists(filename string) bool {
	_, err := os.Stat(filename)
	if err == nil {
		return true
	}

	if os.IsNotExist(err) {
		return false
	}

	return false
}

func FileZip(filename, dest string) error {
	err := os.MkdirAll(filepath.Dir(dest), 0755)
	if err != nil {
		return err
	}

	z := archiver.NewZip()
	err = z.Archive([]string{filename}, dest)
	if err != nil {
		return err
	}

	return nil
}

func FileRemove(filename string) error {
	fs := os.DirFS(".")
	matches, err := doublestar.Glob(fs, filename)
	if err != nil {
		return err
	}

	for _, match := range matches {
		_ = os.RemoveAll(match)
	}

	return nil
}
