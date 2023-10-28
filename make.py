#!/usr/bin/env python3

"""
Partially based on:
https://blog.giovanh.com/blog/2022/12/11/jinja2-as-a-pico-8-preprocessor/
https://gist.github.com/GiovanH/15e5ee2ebe8f4db5f19ebc585e488701
"""

from argparse import ArgumentParser
import os
from os import PathLike
from pathlib import Path
from typing import Final

import jinja2

import generate_data
from common import load_consts, CONSTS_FILE


FILES_DIR: Final = Path('.')
BUILD_DIR: Final = Path('build')
TRACK_DATA_IN: Final = generate_data.DATA_FILENAME_IN
TRACK_DATA_OUT: Final = generate_data.DATA_FILENAME_OUT

DEPENDENCIES_ALL: Final = [
	__file__,
	CONSTS_FILE,
	'common.py',
]

DEPENDENCIES_GENERATE: Final = [
	TRACK_DATA_IN,
	'generate_data.py',
]

VARIABLE_START_STRING: Final = r'"{{'
VARIABLE_END_STRING: Final = r'}}"'
LINE_STATEMENT_PREFIX: Final = r'--%'


def needs_build(file_out: PathLike, *dependencies: PathLike) -> bool:

	# Essentially recreating what a Makefile would do here

	file_out = Path(file_out)

	if not file_out.exists():
		return True

	mtime_out = file_out.stat().st_mtime

	mtime_dependency = max(Path(d).stat().st_mtime for d in dependencies)

	return mtime_dependency >= mtime_out


def parse_args():
	parser = ArgumentParser()
	parser.add_argument('--force', action='store_true', help='Force regenerating data')
	parser.add_argument('--draw', action='store_true', help='Draw maps')
	parser.add_argument('--verbose', action='store_true')
	return parser.parse_args()


def main():
	args = parse_args()

	jinja_files = [
		Path(f)
		for f in FILES_DIR.iterdir()
		if '.jinja' in [s.lower() for s in f.suffixes]
	]

	jinja_env = jinja2.Environment(
		loader=jinja2.FileSystemLoader(FILES_DIR),
		keep_trailing_newline=True,
		variable_start_string=VARIABLE_START_STRING,
		variable_end_string=VARIABLE_END_STRING,
		line_statement_prefix=LINE_STATEMENT_PREFIX,
	)

	consts = load_consts()

	done_anything = False

	if args.force or needs_build(TRACK_DATA_OUT, *DEPENDENCIES_GENERATE, *DEPENDENCIES_ALL):
		done_anything = True
		print(f'Generating {TRACK_DATA_IN} -> {TRACK_DATA_OUT}')
		generate_data.set_verbose(args.verbose)
		generate_data.generate(draw=args.draw)

	for file_in in jinja_files:
		file_out = BUILD_DIR / file_in.name.replace('.jinja', '')
		if args.force or needs_build(file_out, file_in, *DEPENDENCIES_ALL):
			done_anything = True
			print(f'Rendering {file_in} -> {file_out}')
			template_name = os.path.basename(file_in)
			text_out = jinja_env.get_template(template_name).render(**consts)
			BUILD_DIR.mkdir(parents=True, exist_ok=True)
			Path(file_out).write_text(text_out, encoding='utf-8')

	if done_anything:
		print('Done')
	else:
		print('Nothing to do')


if __name__ == "__main__":
	main()
