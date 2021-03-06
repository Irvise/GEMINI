#!/usr/bin/env python3
import numpy as np
from pathlib import Path
import argparse
import sys
import subprocess


def compare_interp(fn: Path, realbits: int, exe: Path, doplot: bool = False):
    fn = Path(fn).expanduser()
    exe = Path(exe).expanduser()
    if not exe.is_file():
        print(exe, "not found", file=sys.stderr)
        raise SystemExit(77)

    subprocess.check_call(str(exe))

    if realbits == 64:
        freal = np.float64
    elif realbits == 32:
        freal = np.float32
    else:
        raise ValueError(f"Unknown realbits {realbits}")

    with fn.open("r") as f:
        lx1 = np.fromfile(f, np.int32, 1)[0]
        lx2 = np.fromfile(f, np.int32, 1)[0]
        lx3 = np.fromfile(f, np.int32, 1)[0]
        x1 = np.fromfile(f, freal, lx1)
        x2 = np.fromfile(f, freal, lx2)
        x3 = np.fromfile(f, freal, lx3)

        fx1x2x3 = np.fromfile(f, freal, lx1 * lx2 * lx3).reshape((lx1, lx2, lx3))
        assert fx1x2x3.shape == (256, 256, 256), f"got shape {fx1x2x3.shape}"

    if not doplot:
        return None

    fg = figure()
    axs = fg.subplots(1, 3)

    ax = axs[0]
    hi = ax.pcolormesh(x2, x1, fx1x2x3[:, :, lx3 // 2])
    ax.set_xlabel("x_2")
    ax.set_ylabel("x_1")
    fg.colorbar(hi, ax=ax).set_label("fx1x2x3")
    ax.set_title("3-D interp: x2x1")

    ax = axs[1]
    hi = ax.pcolormesh(x3, x1, fx1x2x3[:, lx2 // 2 - 10, :])
    ax.set_xlabel("x_3")
    ax.set_ylabel("x_1")
    fg.colorbar(hi, ax=ax).set_label("fx1x2x3")
    ax.set_title("3-D interp: x3x1")

    ax = axs[2]
    hi = ax.pcolormesh(x2, x3, fx1x2x3[lx1 // 2 - 10, ::])
    ax.set_xlabel("x_2")
    ax.set_ylabel("x_3")
    fg.colorbar(hi, ax=ax).set_label("fx1x2x3")
    ax.set_title("3-D interp: x2x3")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("file", help="data file to load")
    p.add_argument("realbits", help="real precision (bits)", nargs="?", type=int, default=64)
    p.add_argument("exe", help="executable to run", nargs="?")
    p.add_argument("-p", "--plot", help="make plots", action="store_true")
    P = p.parse_args()

    if P.plot:
        from matplotlib.pyplot import figure, show

    compare_interp(P.file, P.realbits, P.exe, P.plot)

    if P.plot:
        show()

    print("OK: test interp 3d")
