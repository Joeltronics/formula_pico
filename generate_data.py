#!/usr/bin/env python3

from argparse import ArgumentParser
from collections import namedtuple
from dataclasses import dataclass, field
from enum import Enum, auto
from math import pi as PI, ceil, floor, cos, sin, sqrt
from pathlib import Path
from typing import Final, Iterable
from warnings import warn

import cairo
from PIL import Image, ImageDraw
import yaml

from common import Point

TWO_PI: Final = 2.0 * PI
EPS: Final = 1e-9

MINIMAP_MAX_WIDTH = 32
MINIMAP_MAX_HEIGHT = 48

DATA_FILENAME_IN: Final = Path('track_data.yaml')
DATA_FILENAME_OUT: Final = Path('generated_data.lua')
MAP_DIR_OUT: Final = Path('maps')

GENERATED_DATA_HEADER: Final = f"""
-- Generated data - do not edit this file directly!
-- To change, edit {DATA_FILENAME_IN} and run {Path(__file__).name}
""".strip()


class SectionDirection(Enum):
	straight = auto()
	left = auto()
	right = auto()


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


PALETTE: Final = [Color.from_hex(c) for c in [
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

BLACK: Final = PALETTE[0]
WHITE: Final = PALETTE[7]
RED: Final = PALETTE[8]


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
	# Basic stats
	length: int
	turn_num: int | None = None
	angle: float = 0.0
	# start_heading: float  # TODO
	pitch: float = 0.0
	tnl: bool = False

	# Racing line
	max_speed_kph: float | None = None
	has_apex: bool | None = None
	apex_idx: int | None = None
	# x: float | None = None

	# Ground & background info
	gndcol1: int | None = None
	gndcol2: int | None = None
	bgl: str = ''
	bgr: str = ''
	bgc: str = ''
	segments: list[Segment] = field(default_factory=list)

	def __post_init__(self):
		if self.length < 1:
			raise ValueError(f'Section length must be at least 1 ({self.length=})')

	def to_lua_dict(self) -> dict:
		ret = dict(length=self.length)
		for attr_name in ['angle', 'tnl', 'pitch', 'gndcol1', 'gndcol2', 'bgl', 'bgr', 'bgc']:
			if (val := getattr(self, attr_name, None)):
				ret[attr_name] = val
		return ret

	def to_lua_compressed(self) -> str:

		items = [to_lua_str(self.length)]

		# TODO: if angle but no pitch, could put key=value in 2nd slot

		if self.angle or self.pitch:
			items.append(to_lua_str(self.pitch))

		if self.angle:
			items.append(to_lua_str(self.angle))

		for attr_name in ['tnl', 'gndcol1', 'gndcol2', 'bgl', 'bgr', 'bgc']:
			if (val := getattr(self, attr_name, None)):
				items.append(f'{attr_name}={to_lua_str(val, quote_strings=False)}')

		return ','.join(items)


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
			shoulder_half_width: float,
			street: bool = False,
			tree_bg: bool = False,
			city_bg: bool = False,
			gndcol1: int | None = None,
			gndcol2: int | None = None,
			):

		self.name = name
		self.sections = sections

		self.start_heading: float = start_heading
		self.end_heading: float = None
		self.track_width: float = track_width
		self.shoulder_half_width: float = shoulder_half_width

		self.street = street
		self.tree_bg = tree_bg
		self.city_bg = city_bg
		self.gndcol1 = gndcol1
		self.gndcol2 = gndcol2

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

		self._calculate_apexes()

		self._make_segments()

		self.points = [segment.center_start for segment in self.segments] + [self.segments[-1].center_end]

		x_points = [p[0] for p in self.points]
		y_points = [p[1] for p in self.points]

		self.x_min, self.x_max = min(x_points), max(x_points)
		self.y_min, self.y_max = min(y_points), max(y_points)

		assert self.x_min <= 0 and self.x_max >= 0 and self.y_min <= 0 and self.y_max >= 0, \
			f'{self.x_min=}, {self.x_max=}, {self.y_min=}, {self.y_max=}'
		
		width = self.x_max - self.x_min
		height = self.y_max - self.y_min

		self.minimap_scale = min(
			1, 
			MINIMAP_MAX_WIDTH / width,
			MINIMAP_MAX_HEIGHT / height,
		)
		self.minimap_step = floor(1.0 / self.minimap_scale)

		# Start coordinate is (0, 0)
		# Offset from right side of screen so (x_max) just touches right side of screen
		self.minimap_offset_x = int(ceil(self.x_max * self.minimap_scale))
		# Offset from vertical center of screen to put bottom of minimap at center of screen
		self.minimap_offset_y = int(round(-self.y_min * self.minimap_scale))

	def _calculate_apexes(self):

		turn: list[Section] = []

		def _finish_turn():
			nonlocal turn
			if not turn:
				return
			
			# Find halfway point of curvature
			# TODO: apex isn't necessarily in center, especially for compound radius corners
			total_angle = abs(sum(s.angle for s in turn))
			half_angle = 0.5 * total_angle
			angle_sum = 0
			for section in turn:
				angle_sum_prev = angle_sum
				angle_sum += abs(section.angle)
				if angle_sum > (half_angle - EPS):
					t = (half_angle - angle_sum_prev) / abs(section.angle)
					section.apex_idx = round(t * section.length)
					assert 0 <= section.apex_idx <= section.length
					break

			# If apex ended up at end of a section, then put it on first segment of next section instead
			for idx in range(len(turn)):
				section = turn[idx]
				if section.apex_idx == section.length:
					assert idx < len(turn) - 1
					turn[idx + 1].apex_idx = 0
					section.apex_idx = None

			turn = []

		prev_direction = SectionDirection.straight
		for section in self.sections:

			if section.angle == 0 or (section.has_apex == False):
				direction = SectionDirection.straight
			elif section.angle > 0:
				direction = SectionDirection.right
			else:
				direction = SectionDirection.left

			if direction != prev_direction:
				_finish_turn()

			if direction != SectionDirection.straight:
				turn.append(section)

			prev_direction = direction

		_finish_turn()

	def _make_segments(self, segment_length_units=1):

		x = 0.0
		y = 0.0

		heading = self.start_heading

		self.segments = []

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
						idx=len(self.segments), angle=angle_per_seg, center_start=center_start, center_end=center_end)
					self.segments.append(seg)
					section.segments.append(seg)

			except Exception as ex:
				raise Exception(f'Failed to parse track "{self.name}" corner {idx}: {ex}') from ex

		self.end_heading = heading

		set_normals(self.segments)

	def lua_output_data(self, defaults: dict, compress: bool):

		ret = dict()

		ret['name'] = self.name

		ret['minimap_scale'] = self.minimap_scale
		ret['minimap_step'] = self.minimap_step
		ret['minimap_offset_x'] = self.minimap_offset_x
		ret['minimap_offset_y'] = self.minimap_offset_y

		if self.start_heading != defaults['start_heading']:
			ret['start_heading'] = self.start_heading
		if self.track_width != defaults['track_width']:
			ret['track_width'] = self.track_width
		if self.shoulder_half_width != defaults['shoulder_half_width']:
			ret['shoulder_half_width'] = self.shoulder_half_width

		if self.street:
			ret['street'] = self.street

		if self.gndcol1 is not None:
			ret['gndcol1'] = self.gndcol1
		if self.gndcol2 is not None:
			ret['gndcol2'] = self.gndcol2

		if self.city_bg:
			ret['city_bg'] = True

		if self.tree_bg:
			ret['tree_bg'] = True

		if compress:
			sections_compressed = ';'.join(s.to_lua_compressed() for s in self.sections)
			ret['sections_compressed'] = sections_compressed
			ret['sections'] = []
		else:
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
	shoulder_half_width = track.shoulder_half_width

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

		# Fill with ground color 1
		c.set_source_rgb(*PALETTE[track.gndcol1 if track.gndcol1 is not None else 3])
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

		def circle(center: Point, radius: float, color: tuple[float, float, float]):
			center = to_screen(center)
			c.set_source_rgb(color[0], color[1], color[2])
			c.arc(center.x * scale, center.y * scale, radius * scale, 0, TWO_PI + EPS)
			c.fill()

		def line(points, color: tuple[float, float, float], stroke=2):
			points = [to_screen(p) for p in points]
			c.set_source_rgb(color[0], color[1], color[2])
			c.move_to(points[0][0] * scale, points[0][1] * scale)
			for p in points[1:]:
				c.line_to(p[0] * scale, p[1] * scale)
			c.set_line_width(stroke)
			c.stroke()

		def text(
				t, /,
				coord: Point,
				color: tuple[float, float, float]=WHITE,
				size=1,
				font_family="sans_serif",
				bold=False,
				italic=False,
				center_h=True,
				center_v=True,
				):

			t = str(t)

			weight = cairo.FontWeight.BOLD if bold else cairo.FontWeight.NORMAL
			slant = cairo.FontSlant.ITALIC if italic else cairo.FontSlant.NORMAL
			c.select_font_face(font_family, slant, weight)
			c.set_font_size(size * scale)
			c.set_source_rgb(color[0], color[1], color[2])

			x, y = to_screen(coord) * scale
			if center_h or center_v:
				_, _, w, h, _, _ = c.text_extents(t)
				if center_h:
					x -= w/2
				if center_v:
					y += h/2

			c.move_to(x, y)
			c.show_text(t)

		# Ground

		for idx, (section, segment) in enumerate(iterate_segments(sections)):

			# TODO: track.gndcol1/track.gndcol2/section.gndcol1/section.gndcol2

			if section.gndcol1 is not None:
				gndcol1 = section.gndcol1
			elif track.gndcol1 is not None:
				gndcol1 = track.gndcol1
			else:
				gndcol1 = 3

			if section.gndcol2 is not None:
				gndcol2 = section.gndcol2
			elif track.gndcol2 is not None:
				gndcol2 = track.gndcol2
			else:
				gndcol2 = 11

			if section.tnl:
				gndcol = 1 if (idx % 4 < 2) else 0
			else:
				gndcol = gndcol2 if ((idx % 6) >= 3) else gndcol1

			polygon(segment.points(-2*track_width, 2*track_width), PALETTE[gndcol], stroke=2)

		# Track surface

		for idx, (section, segment) in enumerate(iterate_segments(sections)):
			# roadcol = 1 if section.tnl else 5
			roadcol = 5
			polygon(segment.points(-track_width, track_width), PALETTE[roadcol], stroke=2)

			if track.street and (idx % 4 == 0):
				polygon(segment.points(-3/32, 3/32), WHITE, stroke=0)

		# Line across start of each section

		for section in sections:
			points = section.segments[0].points(-track_width, track_width)
			line([points[0], points[1]], color=BLACK)

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
		], color=BLACK)

		# Curbs

		for idx, (section, segment) in enumerate(iterate_segments(sections)):
			curb_color = RED if (idx % 2 == 0) else WHITE
			polygon(segment.points(track_width - shoulder_half_width, track_width + shoulder_half_width), curb_color, stroke=0.5)
			polygon(segment.points(-track_width + shoulder_half_width, -track_width - shoulder_half_width), curb_color, stroke=0.5)

		# Apexes & turn numbers

		for section in (s for s in sections if s.apex_idx is not None):

			assert 0 <= section.apex_idx < len(section.segments)
			apex_seg = section.segments[section.apex_idx]
			seg_corners = apex_seg.points(-track_width, track_width)
			if section.angle > 0:
				apex_point = seg_corners[0]
			else:
				apex_point = seg_corners[1]

			circle(apex_point, radius=1, color=(0, 0, 1))

			if section.turn_num:
				text(section.turn_num, apex_point, bold=True)

		# TODO: draw rest of racing line

		# TODO: draw corner radius center?

		# TODO: any other details?

		surface.write_to_png(filename_png)
		surface.finish()


def process_track(yaml_track: dict, yaml_defaults: dict) -> Track:

	name = yaml_track['name'].strip().lower()
	length_km = yaml_track.get('length_km', None)

	start_heading = yaml_track.get('start_heading', yaml_defaults['start_heading'])
	length_scale = yaml_track.get('length_scale', yaml_defaults.get('length_scale', 1))
	angle_scale = yaml_track.get('angle_scale', yaml_defaults.get('angle_scale', 1.0))
	track_width = yaml_track.get('track_width', yaml_defaults['track_width'])
	shoulder_half_width = yaml_track.get('shoulder_half_width', yaml_defaults['shoulder_half_width'])

	sections = [Section(**s) for s in yaml_track['sections']]
	for section in sections:
		section.length = int(round(section.length * length_scale))
		section.angle *= angle_scale

	# TODO: break sections into subsections, i.e. pre-apex/post-apex, braking zones, etc
	# TODO: calculate racing line
	# TODO: calcualate section max speed

	track = Track(
		name=name,
		sections=sections,
		start_heading=start_heading,
		track_width=track_width,
		shoulder_half_width=shoulder_half_width,
		street=yaml_track.get('street', False),
		city_bg=yaml_track.get('city_bg', False),
		tree_bg=yaml_track.get('tree_bg', False),
		gndcol1=yaml_track.get('gndcol1', None),
		gndcol2=yaml_track.get('gndcol2', None),
	)

	width = track.x_max - track.x_min
	height = track.y_max - track.y_min

	print(f'Length: {len(track.segments)} segments')
	if length_km is not None:
		m_per_segment = length_km / len(track.segments) * 100
		print(f'True length: {length_km} km, segment length: {m_per_segment:.3f} m')
	print(f'End coord: ({track.points[-1][0]:.3f}, {track.points[-1][1]:.3f})')
	# TODO: give a warning if these don't match up
	print(f'Start heading: {track.start_heading}, end heading: {track.end_heading}')
	print(f'X range: [{track.x_min:.3f}, {track.x_max:.3f}], Y range: [{track.y_min:.3f}, {track.y_max:.3f}]')
	print(f'minimap_scale: {track.minimap_scale:.3f}, resulting resolution: {ceil(width*track.minimap_scale)}x{ceil(height*track.minimap_scale)}')
	print(f'minimap_step: {track.minimap_step}')
	print(f'minimap_offset: ({track.minimap_offset_x}, {track.minimap_offset_y})')

	return track


def to_lua_str(val, indent=0, quote_strings=True) -> str:

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
		return f'"{val}"' if quote_strings else val

	elif isinstance(val, (tuple, list)):
		if val and isinstance(val[0], dict):
			# Split lines
			return '{' + ','.join('\n\t' + indent_str + to_lua_str(v, indent=1+indent, quote_strings=quote_strings) for v in val) + '\n' + indent_str + '}'
		else:
			# All on 1 line
			return '{' + ','.join(to_lua_str(v, indent=indent, quote_strings=quote_strings) for v in val) + '}'

	else:
		if not isinstance(val, dict):
			warn(f'Unknown type, treating as dict: {type(val).__name__}')
			val = vars(val)
		# TODO: split lines
		return '{' + ','.join(f'{k}={to_lua_str(v, indent=indent, quote_strings=quote_strings)}' for k, v in val.items()) + '}'


def main():
	parser = ArgumentParser()
	parser.add_argument('--no-draw', dest='draw', action='store_false')
	parser.add_argument('--show', action='store_true')
	parser.add_argument('--uncompressed', dest='compress', action='store_false')
	args = parser.parse_args()
	data = load_data()

	tracks = data.pop('tracks')

	if not MAP_DIR_OUT.exists():
		MAP_DIR_OUT.mkdir()

	if DATA_FILENAME_OUT.exists():
		DATA_FILENAME_OUT.unlink()

	with open(DATA_FILENAME_OUT, 'w', newline='\n') as f:

		# Write common values

		f.write(GENERATED_DATA_HEADER + '\n')

		for k, v in data.items():
			# These are applied in this script; skip them
			if k in ['length_scale', 'angle_scale']:
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
				minimap_points = [p * track.minimap_scale for p in track.points[::track.minimap_step]]
				filename = MAP_DIR_OUT / f'{track.name}_minimap.png'
				draw_line_map(minimap_points, curve_joint=False, show=args.show, filename=filename)

				# print('Drawing track')
				draw_track(track)

			track_lua_data = track.lua_output_data(data, compress=args.compress)

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
