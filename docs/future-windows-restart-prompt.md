# Future work: offer a restart at the end of the Windows setup

`setup-obs-windows.ps1` tells people to restart when one is needed, but it does not offer to do it. It could
ask at the end, but only when a restart is needed.

## When to ask

- VB-Audio Virtual Cable needs a restart (`$CableNeedsReboot`). Setup also has to be run again afterwards.
- The NDI Runtime warning: "its folder is not registered yet; a restart may be needed".
- Otherwise, do not ask: print the normal `==> Done` message.

## How it should work

- Default to no: `Restart Windows now? [y/N]`, so pressing Enter restarts nothing.
- Do not ask when nobody can answer (over SSH, or in automation), or with a `-NoRestartPrompt` option. Print
  the current message instead, so a run cannot hang waiting for input.
- Wait about 10 seconds before restarting, with a message, so it can still be cancelled.
- If setup has to be run again after the restart, say so before restarting.

## Related idea

A Windows `RunOnce` entry could finish setup at the next sign-in, so nobody has to run it a second time.

Wait until the current setup changes are merged before starting this.
