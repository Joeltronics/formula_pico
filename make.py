#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
from typing import Final

import generate_data

TRACK_DATA_IN: Final = Path('track_data.yaml')
TRACK_DATA_OUT: Final = Path('generated_data.lua')


def needs_build(file_in, file_out) -> bool:
	file_in = Path(file_in)
	file_out = Path(file_out)

	if not file_out.exists():
		return True

	mtime_in = file_in.stat().st_mtime
	mtime_out = file_out.stat().st_mtime

	return mtime_in >= mtime_out


def main():
	parser = ArgumentParser()
	parser.add_argument('--force', action='store_true', help='Force regenerating data')
	parser.add_argument('--verbose', action='store_true')
	args = parser.parse_args()

	done_anything = False

	if args.force or needs_build(TRACK_DATA_IN, TRACK_DATA_OUT):
		done_anything = True
		print('Generating data...')
		generate_data.main([] if args.verbose else ['--quiet'])

	if done_anything:
		print('Done')
	else:
		print('Nothing to do')


if __name__ == "__main__":
	main()
