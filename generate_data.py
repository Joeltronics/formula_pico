#!/usr/bin/env python3

from argparse import ArgumentParser
from collections import namedtuple
from dataclasses import dataclass, field
from math import pi as PI, ceil, floor, cos, sin, sqrt
from pathlib import Path
from typing import Final, Iterable
from warnings import warn

import cairo
from PIL import Image, ImageDraw
import yaml

TWO_PI: Final = 2.0 * PI

DATA_FILENAME_IN: Final = Path('track_data.yaml')
DATA_FILENAME_OUT: Final = Path('generated_data.lua')
MAP_DIR_OUT: Final = Path('maps')

GENERATED_DATA_HEADER: Final = f"""
-- Generated data - do not edit this file directly!
-- To change, edit {DATA_FILENAME_IN} and run {Path(__file__).name}
""".strip()


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


PALETTE = [Color.from_hex(c) for c in [
	'#000000',
	'#1D2B53',
	'#7E2553',
	'#008751',
	'#AB5236',
	'#5F574F',
	'#C2C3C7',
	'#FFF1E8',
	'#FF004D',
	'#FFA300',
	'#FFEC27',
	'#00E436',
	'#29ADFF',
	'#83769C',
	'#FF77A8',
	'#FFCCAA',
]]


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


def float_round_pico8_precision(val: float):
	""" Round float to Pico-8 fixed-point precision (q16) """
	return round(val * 65536) / 65536


@dataclass
class Segment:
	idx: int
	angle: float
	center_start: Point
	center_end: Point

	normal_start: Point | None = None
	normal_end: Point | None = None

	def points(self, x1, x2):
		if self.normal_start is None or self.normal_end is None:
			raise ValueError('normal_start or normal_end is not yet set')

		p0 = self.center_start
		p1 = self.center_end
		n0 = self.normal_start
		n1 = self.normal_end

		return [
			p0 + n0 * x1,
			p0 + n0 * x2,
			p1 + n1 * x2,
			p1 + n1 * x1,
		]


@dataclass
class Section:
	length: int
	angle: float = 0.0
	# start_heading: float  # TODO
	tnl: bool = False
	pitch: float = 0.0
	gndcol: int | None = None
	bgl: str = ''
	bgr: str = ''
	bgc: str = ''
	segments: list[Segment] = field(default_factory=list)

	def to_lua_dict(self) -> dict:
		ret = dict(length=self.length)
		for attr_name in ['angle', 'tnl', 'pitch', 'gndcol', 'bgl', 'bgr', 'bgc']:
			if (val := getattr(self, attr_name, None)):
				ret[attr_name] = val
		return ret


def iterate_segments(sections: Iterable[Section]):
	for section in sections:
		for segment in section.segments:
			yield section, segment


class Track:
	def __init__(
			self,
			name,
			sections: list[Section],
			start_heading: float,
			track_width: float,
			shoulder_width: float,
			):

		self.name = name
		self.sections = sections

		self.start_heading: float = start_heading
		self.track_width: float = track_width
		self.shoulder_width: float = shoulder_width

		self.segments: list[Segment] = None
		self.points: list[Point] = None

		self.x_min: float = None
		self.x_max: float = None
		self.y_min: float = None
		self.y_max: float = None

		self.minimap_scale: float = None
		self.minimap_step: int = None
		self.minimap_offset_x: int = None
		self.minimap_offset_y: int = None

		# TODO: auto adjust last section length so it matches up to start as close as possible

		self.segments = self._make_segments()

		self.points = [segment.center_start for segment in self.segments] + [self.segments[-1].center_end]

		x_points = [p[0] for p in self.points]
		y_points = [p[1] for p in self.points]

		self.x_min, self.x_max = min(x_points), max(x_points)
		self.y_min, self.y_max = min(y_points), max(y_points)

		assert self.x_min <= 0 and self.x_max >= 0 and self.y_min <= 0 and self.y_max >= 0, \
			f'{self.x_min=}, {self.x_max=}, {self.y_min=}, {self.y_max=}'
		
		width = self.x_max - self.x_min
		height = self.y_max - self.y_min

		minimap_max_width = 32
		minimap_max_height = 48
		self.minimap_scale = max(
			1, 
			width / minimap_max_width,
			height / minimap_max_height,
		)
		self.minimap_step = floor(self.minimap_scale)

		# Start coordinate is (0, 0)
		# Offset from right side of screen so (x_max) just touches right side of screen
		self.minimap_offset_x = int(ceil(self.x_max / self.minimap_scale))
		# Offset from vertical center of screen to put bottom of minimap at center of screen
		self.minimap_offset_y = int(round(-self.y_min / self.minimap_scale))

	def _make_segments(self, segment_length_units=1):

		x = 0.0
		y = 0.0

		heading = self.start_heading

		segments = []

		for idx, section in enumerate(self.sections):
			try:
				length = section.length
				angle = section.angle
				angle_per_seg = angle / length

				for _ in range(length):
					# Angle units:
					# The game uses are +right / -left, with 1 = full circle
					# Direction is backwards from Cartesian coordinates, so subtract instead of adding
					heading = (heading - angle_per_seg) % 1.0

					center_start = Point(x, y)
					x += segment_length_units * cos(TWO_PI * heading)
					y += segment_length_units * sin(TWO_PI * heading)
					center_end = Point(x, y)

					seg = Segment(
						idx=len(segments), angle=angle_per_seg, center_start=center_start, center_end=center_end)
					segments.append(seg)
					section.segments.append(seg)

			except Exception as ex:
				raise Exception(f'Failed to parse track "{self.name}" corner {idx}: {ex}') from ex

		set_normals(segments)

		return segments

	def lua_output_data(self, defaults: dict):

		ret = dict()

		ret['name'] = self.name

		ret['minimap_scale'] = 1 / self.minimap_scale  # TODO: take reciprical when setting this, not here
		ret['minimap_step'] = self.minimap_step
		ret['minimap_offset_x'] = self.minimap_offset_x
		ret['minimap_offset_y'] = self.minimap_offset_y

		if self.start_heading != defaults['start_heading']:
			ret['start_heading'] = self.start_heading
		if self.track_width != defaults['track_width']:
			ret['track_width'] = self.track_width
		if self.shoulder_width != defaults['shoulder_width']:
			ret['shoulder_width'] = self.shoulder_width

		ret['sections'] = [section.to_lua_dict() for section in self.sections]

		return ret


def load_data(filename=DATA_FILENAME_IN):
	print(f'Loading {filename}')
	with open(filename, 'r') as f:
		return yaml.safe_load(f)


def draw_line_map(
		points,
		*,
		filename: Path | None = None,
		padding=2, 
		line_width=1,
		curve_joint=True,
		show=True,
		):

	x_points = [p[0] for p in points]
	y_points = [p[1] for p in points]

	x_min, x_max = floor(min(x_points)), ceil(max(x_points))
	y_min, y_max = floor(min(y_points)), ceil(max(y_points))

	assert x_min <= 0 and x_max >= 0 and y_min <= 0 and y_max >= 0, f'{x_min=}, {x_max=}, {y_min=}, {y_max=}'

	width = x_max - x_min + 2*padding
	height = y_max - y_min + 2*padding
	x_off = -x_min + padding
	y_off = -y_min + padding

	off = Point(x_off, y_off)

	# Convert Cartesian to screen - invert Y and add offset
	points = [Point(p.x + off.x, height - (p.y + off.y)) for p in points]

	assert all(
		0 < p.x < width and 0 < p.y < height
		for p in points
	), f'{x_min=}, {x_max=}, {y_min=}, {y_max=}, {width=}, {height=}, {x_off=}, {y_off=}'

	joint = "curve" if curve_joint else None

	im = Image.new("RGB", (width, height))
	draw = ImageDraw.Draw(im)

	dstart = (points[1][0] - points[0][0], points[1][1] - points[0][1])
	dend = (points[-1][0] - points[-2][0], points[-1][1] - points[-2][1])
	start_line = [
		Point(points[0][0] - dstart[1], points[1][1] + dstart[0]),
		Point(points[0][0] + dstart[1], points[1][1] - dstart[0]),
	]
	finish_line = [
		Point(points[-1][0] - dend[1], points[-1][1] + dend[0]),
		Point(points[-1][0] + dend[1], points[-1][1] - dend[0]),
	]
	# If start & end are perfectly aligned, blue should not be visible
	draw.line(start_line, fill="blue")
	draw.line(finish_line, fill="red")
	draw.line(points, fill="white", width=line_width, joint=joint)

	if filename:
		im.save(filename)

	if show:
		im.show()


def set_normals(segments: list[Segment]):

	# 2 different draw styles; non right angle is typically better
	right_angle_segment_start = False

	for idx, segment in enumerate(segments):

		segment_prev = segments[idx - 1] if idx > 0 else None
		segment = segments[idx]
		segment_next = segments[idx + 1] if idx + 1 < len(segments) else None

		pn1 = (segment_prev.center_start) if (segment_prev is not None) else None
		p0 = (segment.center_start)
		p1 = (segment.center_end)
		p2 = (segment_next.center_end) if (segment_next is not None) else None

		dp0 = p0 - pn1 if (pn1 is not None) else None
		dp1 = p1 - p0
		dp2 = p2 - p1 if (p2 is not None) else None

		if right_angle_segment_start:
			norm1 = dp1.normal()
			norm2 = dp2.normal() if (dp2 is not None) else norm1
		else:
			norm1 = (0.5*(dp0 + dp1)).normal() if (dp0 is not None) else dp1.normal()
			norm2 = (0.5*(dp1 + dp2)).normal() if (dp2 is not None) else dp1.normal()

		segment.normal_start = norm1
		segment.normal_end = norm2


def draw_track(track, scale=16):

	# TODO: instead of multiplying everything by scale, use SVG units propertly
	# (Haven't figured out how to get this work with Cairo PNG export)

	name = track.name
	sections = track.sections
	track_width = track.track_width
	shoulder_width = track.shoulder_width

	filename_svg = MAP_DIR_OUT / f"{name}.svg"
	filename_png = MAP_DIR_OUT / f"{name}.png"

	segments = []
	for section in sections:
		segments.extend(section.segments)

	x_min = track.x_min - 2*track_width
	y_min = track.y_min - 2*track_width
	x_max = track.x_max + 2*track_width
	y_max = track.y_max + 2*track_width
	width = x_max - x_min
	height = y_max - y_min

	def to_screen(point):
		return Point(point.x - x_min, height - point.y + y_min)

	with cairo.SVGSurface(filename_svg, width*scale, height*scale) as surface:

		c = cairo.Context(surface)

		c.set_source_rgb(*PALETTE[3])

		c.paint()

		# Without stroke, there's a slight gap between each segment; stroke=2 is workaround for this
		# (Ideally, should just draw entire track as a single polygon, but that's more work)
		# Could solve with with SVG attribute shape-rendering geometricPrecision, but not sure how to set this in PyCairo

		def polygon(points, color: tuple[float, float, float], stroke=2):
			points = [to_screen(p) for p in points]
			c.set_source_rgb(color[0], color[1], color[2])
			c.move_to(points[0][0] * scale, points[0][1] * scale)
			for p in points[1:]:
				c.line_to(p[0] * scale, p[1] * scale)
			c.close_path()

			if stroke:
				c.set_line_width(stroke)
				c.fill_preserve()
				c.stroke()
			else:
				c.fill()

		def line(points, color: tuple[float, float, float], stroke=2):
			points = [to_screen(p) for p in points]
			c.set_source_rgb(color[0], color[1], color[2])
			c.move_to(points[0][0] * scale, points[0][1] * scale)
			for p in points[1:]:
				c.line_to(p[0] * scale, p[1] * scale)
			c.set_line_width(stroke)
			c.stroke()

		# Ground

		for idx, (section, segment) in enumerate(iterate_segments(sections)):

			if section.tnl:
				gndcol = 1 if (idx % 4 < 2) else 0
			elif section.gndcol:
				gndcol = section.gndcol
			else:
				gndcol = 11 if ((idx % 6) >= 3) else 3

			polygon(segment.points(-2*track_width, 2*track_width), PALETTE[gndcol], stroke=2)

		# Track surface

		for idx, (section, segment) in enumerate(iterate_segments(sections)):
			# roadcol = 1 if section.tnl else 5
			roadcol = 5
			polygon(segment.points(-track_width, track_width), PALETTE[roadcol], stroke=2)

		# Line across start of each section

		for section in sections:
			points = section.segments[0].points(-track_width, track_width)
			line([points[0], points[1]], color=PALETTE[0])

		# Start/Finish Line

		finish_line_segment = sections[1].segments[0]
		p0 = finish_line_segment.center_start
		p1 = 0.5*(p0 + finish_line_segment.center_end)
		n0 = finish_line_segment.normal_start
		n1 = (0.5*(n0 + finish_line_segment.normal_end)).normalized()
		polygon([
			p0 - n0*track_width,
			p0 + n0*track_width,
			p1 + n1*track_width,
			p1 - n1*track_width,
		], color=PALETTE[0])

		# Curbs

		for idx, (section, segment) in enumerate(iterate_segments(sections)):
			curb_color = PALETTE[8] if (idx % 2 == 0) else PALETTE[7]
			polygon(segment.points(track_width, track_width + shoulder_width), curb_color, stroke=0.5)
			polygon(segment.points(-track_width, -track_width - shoulder_width), curb_color, stroke=0.5)

		# TODO: draw racing line

		# TODO: draw corner radius center?

		# TODO: any other details?

		surface.write_to_png(filename_png)
		surface.finish()


def process_track(yaml_track: dict, yaml_defaults: dict) -> Track:

	name = yaml_track['name'].strip().lower()
	length_km = yaml_track.get('length_km', None)

	start_heading = yaml_track.get('start_heading', yaml_defaults['start_heading'])
	length_scale = yaml_track.get('length_scale', yaml_defaults['length_scale'])
	track_width = yaml_track.get('track_width', yaml_defaults['track_width'])
	shoulder_width = yaml_track.get('shoulder_width', yaml_defaults['shoulder_width'])

	sections = [Section(**s) for s in yaml_track['sections']]
	for section in sections:
		section.length *= length_scale

	# TODO: break sections into subsections, i.e. pre-apex/post-apex, braking zones, etc
	# TODO: calculate racing line
	# TODO: calcualate section max speed

	track = Track(
		name=name,
		sections=sections,
		start_heading=start_heading,
		track_width=track_width,
		shoulder_width=shoulder_width,
	)

	width = track.x_max - track.x_min
	height = track.y_max - track.y_min

	print(f'Length: {len(track.segments)} segments')
	if length_km is not None:
		m_per_segment = length_km / len(track.segments) * 100
		print(f'True length: {length_km} km, segment length: {m_per_segment:.3f} m')
	print(f'End coord: ({track.points[-1][0]:.3f}, {track.points[-1][1]:.3f})')
	print(f'X range: [{track.x_min:.3f}, {track.x_max:.3f}], Y range: [{track.y_min:.3f}, {track.y_max:.3f}]')
	print(f'minimap_scale: {track.minimap_scale:.3f}, resulting resolution: {ceil(width/track.minimap_scale)}x{ceil(height/track.minimap_scale)}')
	print(f'minimap_step: {track.minimap_step}')
	print(f'minimap_offset: ({track.minimap_offset_x}, {track.minimap_offset_y})')

	return track


def to_lua_str(val, indent=0) -> str:

	indent_str = '\t' * indent

	if val is None:
		# Hopefully these values should be excluded in the first place, but in case they're not
		return 'nil'

	elif isinstance(val, bool):
		return str(val).lower()

	elif isinstance(val, int):
		return str(val)

	elif isinstance(val, float):
		# If the number formats nicely to few decimal places, then assume any extra decimals at the end are the result
		# of float precision error and can be ignored (since Pico-8 cares about code size & compressibility)
		ret = f'{val:.9g}'
		if len(ret.lstrip('-')) <= 8 and ('e' not in ret.lower()):
			return ret
		else:
			return str(float_round_pico8_precision(val))

	elif isinstance(val, str):
		return f'"{val}"'

	elif isinstance(val, (tuple, list)):
		if val and isinstance(val[0], dict):
			# Split lines
			return '{' + ','.join('\n\t' + indent_str + to_lua_str(v, indent=1+indent) for v in val) + '\n' + indent_str + '}'
		else:
			# All on 1 line
			return '{' + ','.join(to_lua_str(v, indent=indent) for v in val) + '}'

	else:
		if not isinstance(val, dict):
			warn(f'Unknown type, treating as dict: {type(val).__name__}')
			val = vars(val)
		# TODO: split lines
		return '{' + ','.join(f'{k}={to_lua_str(v, indent=indent)}' for k, v in val.items()) + '}'


def main():
	parser = ArgumentParser()
	parser.add_argument('--no-draw', dest='draw', action='store_false')
	parser.add_argument('--show', action='store_true')
	args = parser.parse_args()
	data = load_data()

	tracks = data.pop('tracks')

	if not MAP_DIR_OUT.exists():
		MAP_DIR_OUT.mkdir()

	if DATA_FILENAME_OUT.exists():
		DATA_FILENAME_OUT.unlink()

	with open(DATA_FILENAME_OUT, 'w') as f:

		# Write common values

		f.write(GENERATED_DATA_HEADER + '\n')

		for k, v in data.items():
			# length_scale is applied in this script; skip it
			if k == 'length_scale':
				continue
			f.write(f'{k}={to_lua_str(v)}\n')

		# Write tracks

		f.write('tracks={\n')

		for track_yaml in tracks:
			print(f'Processing track "{track_yaml["name"]}"')
			track = process_track(track_yaml, data)

			if args.draw:

				# print('Drawing full-res line map')
				filename = MAP_DIR_OUT / f'{track.name}_linemap.png'
				draw_line_map(track.points, show=args.show, filename=filename)

				# print('Drawing minimap')
				minimap_points = [p / track.minimap_scale for p in track.points[::track.minimap_step]]
				filename = MAP_DIR_OUT / f'{track.name}_minimap.png'
				draw_line_map(minimap_points, curve_joint=False, show=args.show, filename=filename)

				# print('Drawing track')
				draw_track(track)

			# TODO: compress output data

			track_lua_data = track.lua_output_data(data)

			sections = track_lua_data.pop('sections')

			f.write('{\n')
			for key, val in track_lua_data.items():
				f.write(f'\t{key}={to_lua_str(val, indent=1)},\n')

			for section in sections:
				f.write(f'\t{to_lua_str(section, indent=1)},\n')

			f.write('},\n')

			print()

		f.write('}\n')

	print(f'Data saved as {DATA_FILENAME_OUT}')


if __name__ == "__main__":
	main()
