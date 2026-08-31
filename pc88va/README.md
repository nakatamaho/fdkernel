# PC-88VA compile-only kernel target

This directory is the independent PC-88VA machine boundary.  M06 deliberately
builds only a linked kernel scaffold: it establishes the target selector,
binary interface, deterministic link order, and fail-closed service boundary.
It does not implement boot, disk, console, keyboard, timer, interrupt, memory
discovery, or firmware behavior.

The build must run in the accepted Linux/amd64 Open Watcom 1.9 environment:

```sh
cd pc88va
wmake -ms -h -f makefile.wc clean all
python3 tools/collect_build.py --repo-root .. --output build/evidence
```

`bin/KERNEL.SYS` is a DOS MZ executable container used as a compile-only
artifact.  It is not the flat FreeDOS kernel format used by the existing boot
loaders, and M08 must decide and implement the required loader transformation
or container loading policy.  The entry point always reaches a local fatal
stop after probing the fail-closed interface object.  It performs no firmware
interrupt or I/O-port access.

The target defines `PC88VA`, `JAPAN`, and `DBCS`.  It rejects `NEC98` and
`IBMPC`; no source below `nec98/` or `ibmpc/` is a link input.

All temporary interfaces are listed in `config/stubs.json`.  Their return
value is the signed error `-1`, except the probe which returns `0xffff`; none
reports hardware success.
