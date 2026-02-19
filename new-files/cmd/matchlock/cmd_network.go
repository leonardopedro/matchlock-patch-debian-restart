package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/jingkaihe/matchlock/internal/errx"
	"github.com/jingkaihe/matchlock/pkg/api"
	"github.com/jingkaihe/matchlock/pkg/sandbox"
	"github.com/jingkaihe/matchlock/pkg/state"
)

var networkCmd = &cobra.Command{
	Use:   "network",
	Short: "Manage network configuration",
}

var allowHostCmd = &cobra.Command{
	Use:   "allow <id> <host>...",
	Short: "Add one or more hosts to the allow-list",
	Args:  cobra.MinimumNArgs(2),
	RunE:  runNetworkAllow,
}

func init() {
	networkCmd.AddCommand(allowHostCmd)
	rootCmd.AddCommand(networkCmd)
}

func runNetworkAllow(cmd *cobra.Command, args []string) error {
	id := args[0]
	newHosts := args[1:]

	mgr := state.NewManager()
	vmState, err := mgr.Get(id)
	if err != nil {
		return errx.With(ErrVMNotFound, " %s: %w", id, err)
	}

	config, err := api.ParseConfig(vmState.Config)
	if err != nil {
		return errx.Wrap(ErrParseConfig, err)
	}

	if config.Network == nil {
		config.Network = &api.NetworkConfig{}
	}

	// Filter and add only unique new hosts
	addedCount := 0
	for _, host := range newHosts {
		exists := false
		for _, h := range config.Network.AllowedHosts {
			if h == host {
				exists = true
				break
			}
		}
		if !exists {
			config.Network.AllowedHosts = append(config.Network.AllowedHosts, host)
			addedCount++
		}
	}

	if addedCount == 0 {
		fmt.Fprintf(os.Stderr, "All specified hosts are already allowed for VM %s\n", id)
		return nil
	}

	// If VM is running, update it via relay
	if vmState.Status == "running" {
		socketPath := mgr.ExecSocketPath(id)
		if err := sandbox.UpdateNetworkViaRelay(socketPath, config.Network.AllowedHosts); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to update running VM at %s: %v\n", socketPath, err)
		} else {
			fmt.Fprintf(os.Stderr, "Updated running VM %s successfully\n", id)
		}
	}


	// Always persist to DB
	if err := mgr.Register(id, config); err != nil {
		return errx.Wrap(ErrRegisterState, err)
	}

	fmt.Fprintf(os.Stderr, "Successfully updated allow-list for VM %s\n", id)
	return nil
}
