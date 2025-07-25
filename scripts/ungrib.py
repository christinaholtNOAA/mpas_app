#!/usr/bin/env python3
"""
The run script for ungrib.
"""

import glob
import sys
from iotaa import tasks
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent))

from uwtools.api.ungrib import Ungrib

from scripts.common import parse_args, run_component

class UngribHFIP(Ungrib):
    @tasks
    def gribfiles(self):
        yield self.taskname("GRIB files")
        gribfiles = Path(self.config["gribfiles"]["path"])
        chosen_text = (gribfiles.parent / "chosen_storm.txt").read_text()
        chosen_files = chosen_text.split()[-1].replace("VARNAME", "*")
        links = []
        #for n, gribfile in enumerate(glob.glob(str(gribfiles/chosen_files))):
        for n, gribfile in enumerate(glob.glob(str(gribfiles/"00x*"))):
            link_name = self.rundir / f"GRIBFILE.{_ext(n)}"
            links.append((gribfile, link_name))
        yield [self._gribfile(gribfile, link) for gribfile, link in links]

def _ext(n: int) -> str:
    """
    Return a 3-letter representation of the given integer.

    :param n: The integer to convert to a string representation.
    """
    b = 26  
    return "{:A>3}".format(("" if n < b else _ext(n // b)) + chr(65 + n % b))[-3:]

def main():
    args = parse_args()

    run_component(
        driver_class=Ungrib,
        config_file=args.config_file,
        cycle=args.cycle,
        key_path=args.key_path,
    )


if __name__ == "__main__":
    main()  # pragma: no cover
