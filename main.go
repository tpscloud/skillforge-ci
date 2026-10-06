// Copyright 2026 coversheets. SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"runtime/debug"
	"syscall"

	"github.com/spf13/cobra"
)

var errFindings = errors.New("checks found problems")

func buildRevision() string {
	if info, ok := debug.ReadBuildInfo(); ok {
		for _, setting := range info.Settings {
			if setting.Key == "vcs.revision" {
				return setting.Value
			}
		}
	}
	return "unrecorded"
}

func buildDirty() bool {
	if info, ok := debug.ReadBuildInfo(); ok {
		for _, setting := range info.Settings {
			if setting.Key == "vcs.modified" {
				return setting.Value != "false"
			}
		}
	}
	return true
}

func newRoot(out, diagnostic io.Writer) *cobra.Command {
	root := &cobra.Command{Use: "skillforge", Short: "Validate skill repositories and run local CI checks", Version: "0.1.0", SilenceUsage: true, SilenceErrors: true}
	root.SetOut(out)
	root.SetErr(diagnostic)
	repository := func(args []string) string {
		if len(args) == 0 {
			return "."
		}
		return args[0]
	}
	var reportPath string
	validate := &cobra.Command{Use: "validate [repository]", Short: "Inspect declared skills without running repository code", Args: cobra.MaximumNArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		report := validateRepository(cmd.Context(), repository(args))
		if reportPath != "" {
			if err := writeJSON(reportPath, report); err != nil {
				return err
			}
		}
		for _, f := range report.Findings {
			fmt.Fprintf(cmd.OutOrStdout(), "%s: %s: %s\n", f.Severity, f.Path, f.Message)
		}
		fmt.Fprintf(cmd.OutOrStdout(), "Skill validation: %s\n", report.Status)
		if report.Status != "pass" {
			return errFindings
		}
		return nil
	}}
	validate.Flags().StringVar(&reportPath, "output", "", "Write JSON evidence to this file")
	checks := &cobra.Command{Use: "check [repository]", Short: "Execute explicitly configured argument arrays (trusted repositories only)", Args: cobra.MaximumNArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		return runChecks(cmd.Context(), repository(args), cmd.OutOrStdout(), cmd.ErrOrStderr())
	}}
	var outputDirectory string
	scan := &cobra.Command{Use: "scan [repository]", Short: "Scan Git history and current files using checksum-pinned Gitleaks", Args: cobra.MaximumNArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		return scanRepository(cmd.Context(), repository(args), outputDirectory, cmd.OutOrStdout(), cmd.ErrOrStderr())
	}}
	scan.Flags().StringVar(&outputDirectory, "output-directory", "", "Directory outside the repository for redacted evidence (required)")
	if err := scan.MarkFlagRequired("output-directory"); err != nil {
		panic(err)
	}
	var update bool
	install := &cobra.Command{Use: "install repository", Short: "Copy the embedded Go CI bundle into a selected repository", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		if err := installBundle(cmd.Context(), args[0], update); err != nil {
			return err
		}
		fmt.Fprintln(cmd.OutOrStdout(), "Installed Skillforge CI bundle; inspect the diff before committing.")
		return nil
	}}
	install.Flags().BoolVar(&update, "update", false, "Replace recognized managed files; preserve repository configuration")
	root.AddCommand(validate, checks, scan, install)
	return root
}

func exitCode(err error) int {
	if err == nil {
		return 0
	}
	if errors.Is(err, errFindings) {
		return 1
	}
	return 2
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	err := newRoot(os.Stdout, os.Stderr).ExecuteContext(ctx)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
	os.Exit(exitCode(err))
}
