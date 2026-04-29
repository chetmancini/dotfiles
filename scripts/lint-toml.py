#!/usr/bin/env python3
import pathlib
import sys
import tomllib


def main() -> int:
    ok = True
    for path_arg in sys.argv[1:]:
        path = pathlib.Path(path_arg)
        try:
            tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as exc:
            print(f"{path}: {exc}", file=sys.stderr)
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
