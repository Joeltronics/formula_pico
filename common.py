#!/usr/bin/env python3

from collections import namedtuple
from math import sqrt, radians, sin, cos, isclose
from os import PathLike
from pathlib import Path
import re
from typing import Final, Iterable

import simpleeval
import yaml


CONSTS_FILE: Final = Path('consts.yaml')


def sgn(value: float) -> int:
	return 1 if value >= 0 else -1


def lerp(x0: float, x1: float, t: float) -> float:
	return (1 - t) * x0 + t * x1


def first_non_null(*vals):
	for val in vals:
		if val is not None:
			return val
	return None


def float_round_pico8_precision(val: float):
	""" Round float to Pico-8 fixed-point precision (q16) """
	return round(val * 65536) / 65536


def float_to_lua_str(val: float) -> str:

	if val.is_integer():
		return str(val)

	# If the number formats nicely to few decimal places, then assume any extra decimals at the end are the result
	# of float precision error and can be ignored (since Pico-8 cares about code size & compressibility)
	val_fmt = f'{val:.9g}'
	if len(val_fmt.lstrip('-')) <= 8 and ('e' not in val_fmt.lower()):
		return val_fmt
	else:
		return str(float_round_pico8_precision(val))


class Color(namedtuple('Color', ['r', 'g', 'b'])):
	@classmethod
	def from_hex(cls, hex_str: str):

		if hex_str.startswith('#'):
			hex_str = hex_str[1:]

		if len(hex_str) != 6:
			raise ValueError(f'Invalid color: "{hex_str}"')

		r = int(hex_str[:2], 16) / 255.
		g = int(hex_str[2:4], 16) / 255.
		b = int(hex_str[4:], 16) / 255.
		return cls(r=r, g=g, b=b)


class Point(namedtuple('Point', ['x', 'y'])):
	__slots__ = ()

	def __add__(self, other: 'Point') -> 'Point':
		return Point(self.x + other.x, self.y + other.y)

	def __sub__(self, other: 'Point') -> 'Point':
		return Point(self.x - other.x, self.y - other.y)

	def __mul__(self, val: float) -> 'Point':
		return Point(self.x * val, self.y * val)

	def __rmul__(self, val: float) -> 'Point':
		return Point(val * self.x, val * self.y)

	def __truediv__(self, val: float) -> 'Point':
		return Point(self.x / val, self.y / val)

	def __pos__(self) -> 'Point':
		return self

	def __neg__(self) -> 'Point':
		return Point(-self.x, -self.y)

	def magnitude(self) -> float:
		return sqrt(self.x ** 2 + self.y ** 2)

	def normalized(self) -> 'Point':
		mag = self.magnitude()
		return self / mag if mag else Point(0, 0)

	def normal(self) -> 'Point':
		return Point(-self.y, self.x).normalized()


def weighted_average(vals: Iterable[tuple[float, float]]) -> float | None:
	"""
	:param vals: iterable of tuples of (value, weight)
	"""
	sum_vals = 0
	sum_weight = 0
	for val, weight in vals:
		sum_vals += val * weight
		sum_weight += weight

	return (sum_vals / sum_weight) if sum_weight else None


def calculate_racing_line_radius(
		track_width: float,
		radius_track_center: float,
		apex_angle_degrees: float,
		) -> tuple[float, float, float, float, float, float]:

	if not 0 < apex_angle_degrees <= 90:
		raise ValueError(f'{apex_angle_degrees=}')

	radius_track_inner = radius_track_center - track_width / 2
	if radius_track_inner <= 0:
		raise ValueError(f'{radius_track_center=}, {track_width=}, {radius_track_inner=}')

	if apex_angle_degrees == 90:
		# 90-degree case:
		# Racing line radius is same as outer radius
		radius_track_outer = radius_track_center + track_width / 2
		entrance_x = -track_width - radius_track_inner
		entrance_y = -radius_track_inner
		return radius_track_outer, entrance_x, entrance_y

	r"""
	Math for radius pre-apex:

	Need to calculate circle which is tangent to x = entrance.x, and goes through apex

	Essentially we need to solve for triangle:

	                (apex)
	                  *
	                / |  \   R
	              /   |     \
	            /     |        \ -- theta
	(entrance) *------*----------*
	           |  a   |  (R-a)   |
	           |        R        |

	cos(theta) = (R - a) / R
	R * cos(theta) = R - a
	a = R - R * cos(theta)
	a = (1 - cos(theta)) * R
	R = a / (1 - cos(theta))

	entrance.x = -track_width - r_inner
	apex.x = -r_inner * cos(theta)

	a = apex.x - entrance.x
	a = -r_inner * cos(theta) + track_width + r_inner
	a = track_width + r_inner - r_inner * cos(theta)
	a = track_width + r_inner * (1 - cos(theta))

	To calculate post-apex radius & exit, can use the same logic but with theta=(turn_angle - apex_angle)
	"""

	theta = radians(apex_angle_degrees)
	cos_theta = cos(theta)
	sin_theta = sin(theta)

	a = track_width + radius_track_inner * (1 - cos_theta)

	radius = a / (1 - cos_theta)

	entrance_x = -track_width - radius_track_inner
	entrance_y = (radius_track_inner - radius) * sin_theta

	return radius, entrance_x, entrance_y


def load_consts(filename: PathLike = CONSTS_FILE) -> dict:

	with open(filename, 'r') as f:
		consts_raw = yaml.safe_load(f)

	# Now, perform any variable substitution & expression evaluation
	# TODO: there's got to be a way to do this in Jinja instead of this - might have to process template twice?

	consts_out = dict()

	for key, val in consts_raw.items():

		if isinstance(val, str):

			expr_split = re.split(r'(\W)', val)
			expr_sub = ''.join(str(consts_out.get(token, token)) for token in expr_split)

			try:
				val = simpleeval.simple_eval(expr_sub)
			except (simpleeval.InvalidExpression, UserWarning) as ex:
				raise ValueError(f'Failed to parse expression for const "{key}" in {filename}: {ex}') from ex  # TODO: this will fail for expressions actually meant to be strings!

		if isinstance(val, float):
			if isclose(val, round(val)):
				val = int(val)

		consts_out[key] = val

	return consts_out
