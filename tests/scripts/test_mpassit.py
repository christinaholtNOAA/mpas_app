from pathlib import Path
from unittest.mock import patch

import pytest

from scripts import mpassit


def test_main(args):
    with (
        patch.object(mpassit, "parse_args", return_value=args) as parse_args,
        patch.object(mpassit, "run_component", return_value=Path("/some/rundir")) as run_component,
    ):
        mpassit.main()
        parse_args.assert_called_once()
        run_component.assert_called_once_with(
            driver_class=mpassit.MPASSIT,
            config_file=args.config_file,
            cycle=args.cycle,
            leadtime=args.leadtime,
            key_path=args.key_path,
        )


def test_main_missing_leadtime(args):
    args.leadtime = None
    with (
        patch.object(mpassit, "parse_args", return_value=args),
        pytest.raises(TypeError),
    ):
        mpassit.main()
