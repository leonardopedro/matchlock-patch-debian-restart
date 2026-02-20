package main

import (
	"context"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/jingkaihe/matchlock/internal/errx"
	"github.com/jingkaihe/matchlock/pkg/api"
	"github.com/jingkaihe/matchlock/pkg/sandbox"
	"github.com/jingkaihe/matchlock/pkg/state"
)

var startCmd = &cobra.Command{
	Use:   "start [flags] <id>",
	Short: "Restart a stopped sandbox",
	Long:  `Restart a stopped sandbox using its existing filesystem and configuration.`,
	Args:  cobra.MinimumNArgs(1),
	RunE:  runStart,
}

func init() {
	startCmd.Flags().StringSlice("allow-host", nil, "Additional allowed hosts")
	startCmd.Flags().BoolP("tty", "t", false, "Allocate a pseudo-TTY")
	startCmd.Flags().BoolP("interactive", "i", false, "Keep STDIN open")

	rootCmd.AddCommand(startCmd)
}

func runStart(cmd *cobra.Command, args []string) error {
	id := args[0]
	execArgs := args[1:]
	allowHosts, _ := cmd.Flags().GetStringSlice("allow-host")
	tty, _ := cmd.Flags().GetBool("tty")
	interactive, _ := cmd.Flags().GetBool("interactive")
	interactiveMode := tty && interactive

	mgr := state.NewManager()
	vmState, err := mgr.Get(id)
	if err != nil {
		return errx.With(ErrVMNotFound, " %s: %w", id, err)
	}
	if vmState.Status == "running" {
		return errx.With(ErrVMRunning, " %s", id)
	}

	var configOverride *api.Config
	if len(allowHosts) > 0 {
		configOverride = &api.Config{
			Network: &api.NetworkConfig{
				AllowedHosts: allowHosts,
			},
		}
	}

	ctx, cancel := contextWithSignal(context.Background())
	defer cancel()

	sb, err := sandbox.Load(ctx, id, configOverride)
	if err != nil {
		return errx.Wrap(ErrStartSandbox, err)
	}

	if err := sb.Start(ctx); err != nil {
		return errx.Wrap(ErrStartSandbox, err)
	}

	// Start exec relay server so `matchlock exec` can connect
	execRelay := sandbox.NewExecRelay(sb)
	execSocketPath := mgr.ExecSocketPath(sb.ID())
	if err := execRelay.Start(execSocketPath); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to start exec relay: %v\n", err)
	}
	defer execRelay.Stop()

	command := execArgs

	if interactiveMode {
		exitCode := runInteractive(ctx, sb, command, "")
		return commandExit(exitCode)
	}

	if len(command) > 0 {
		opts := &api.ExecOptions{
			Stdout: os.Stdout,
			Stderr: os.Stderr,
		}
		if interactive {
			opts.Stdin = os.Stdin
		}
		result, err := sb.Exec(ctx, command, opts)
		if err != nil {
			return errx.Wrap(ErrExecCommand, err)
		}
		return commandExit(result.ExitCode)
	}

	fmt.Fprintf(os.Stderr, "Sandbox %s is running\n", sb.ID())
	fmt.Fprintf(os.Stderr, "  Connect: matchlock exec %s -it bash\n", sb.ID())
	fmt.Fprintf(os.Stderr, "  Stop:    matchlock kill %s\n", sb.ID())

	// Wait until signal or exit
	<-ctx.Done()

	return sb.Close(context.Background())
}
