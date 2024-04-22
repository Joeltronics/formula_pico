#!/usr/bin/env python3

from argparse import ArgumentParser
from copy import copy
from dataclasses import dataclass, field
from enum import Enum, auto
from math import pi as PI, ceil, floor, cos, sin, asin, isclose
from pathlib import Path
import shutil
from typing import ClassVar, Final
from warnings import warn

import yaml

from common import sgn, float_round_pico8_precision, float_to_lua_str, Point, load_consts
from draw_map import draw_line_map, draw_track
from p8scii import P8SCII

TWO_PI: Final = 2.0 * PI
EPS: Final = 1e-9

CONSTS: Final = load_consts()

WALL_SCALE: Final = CONSTS['wall_scale']
SPEED_KPH_SCALE: Final = CONSTS['speed_to_kph']
RACING_LINE_SINE_INTERP: Final = CONSTS['racing_line_sine_interp']
PIT_LANE_WIDTH: Final = CONSTS['pit_lane_width']

# TODO: figure this out - I don't think wall_scale is being applied properly in drawing
# PIT_LANE_WALL: Final = round(PIT_LANE_WIDTH / (2 * WALL_SCALE))
# PIT_LANE_WALL: Final = round(PIT_LANE_WIDTH / WALL_SCALE)
# PIT_LANE_WALL: Final = round(0.5 * PIT_LANE_WIDTH)
PIT_LANE_WALL: Final = round(PIT_LANE_WIDTH)  # This seems to work

WALL_THICKNESS: Final = 0.5

MINIMAP_MAX_WIDTH: Final = 32
MINIMAP_MAX_HEIGHT: Final = 48

BUILD_DIR: Final = Path('build')
DATA_FILENAME_IN: Final = Path('track_data.yaml')
DATA_FILENAME_OUT_P8: Final = BUILD_DIR / 'generated_data.p8.lua'
DATA_FILENAME_OUT_P64: Final = BUILD_DIR / 'generated_data.p64.lua'
MAP_DIR_OUT: Final = Path('maps')


class SectionDirection(Enum):
	straight = auto()
	left = auto()
	right = auto()


verbose = False


def set_verbose(v: bool):
	global verbose
	verbose = v


def vprint(*args, **kwargs):
	if verbose:
		print(*args, **kwargs)


@dataclass
class Segment:
	idx: int
	angle: float
	center_start: Point
	center_end: Point

	max_speed: float
	racing_line_start_x: float
	racing_line_end_x: float

	normal_start: Point | None = None
	normal_end: Point | None = None

	@property
	def radius_center(self) -> float:
		if not self.angle:
			return 0.0
		# Radius from arc length: r = s / theta
		# arc length: s = 1
		# angle is 0-1, so convert to radians
		return 1.0 / abs(self.angle * TWO_PI)

	def points(self, x1, x2, x1_far=None, x2_far=None, clip_radius=True):
		if self.normal_start is None or self.normal_end is None:
			raise ValueError('normal_start or normal_end is not yet set')

		if x1_far is None:
			x1_far = x1

		if x2_far is None:
			x2_far = x2

		p0 = self.center_start
		p1 = self.center_end
		n0 = self.normal_start
		n1 = self.normal_end

		r = self.radius_center
		if clip_radius and r:
			if self.angle > 0:
				x1 = min(x1, r)
				x2 = min(x2, r)
				x1_far = min(x1_far, r)
				x2_far = min(x2_far, r)
			else:
				x1 = max(x1, -r)
				x2 = max(x2, -r)
				x1_far = max(x1_far, -r)
				x2_far = max(x2_far, -r)

		return [
			p0 + n0 * x1,
			p0 + n0 * x2,
			p1 + n1 * x2_far,
			p1 + n1 * x1_far,
		]


@dataclass(kw_only=True)
class Section:
	# Basic stats
	length: int

	wall_l: int
	wall_r: int

	turn_num: int | None = None
	angle: float = 0.0
	# start_heading: float  # TODO
	dwall_l: float | None = None
	dwall_r: float | None = None
	pitch: float = 0.0
	tnl: bool = False
	pit: int = 0
	dpit: float | None = None

	# Racing line
	speed: float | None = None
	x: float = 0.0

	# Ground & background info
	lanes: int | None = None
	gndcol1: int | None = None
	gndcol2: int | None = None
	bgl: str = ''
	bgr: str = ''
	bgc: str = ''

	# List of segments, for use on Python side only
	segments: list[Segment] = field(default_factory=list)

	LUA_ORDERED_FIELDS: ClassVar[list[str]] = [
		'length',
		'x',
		'pitch',
		'angle',
		'max_speed',
		'wall',
	]

	LUA_KW_FIELDS: ClassVar[list[str]] = [
		'pit',
		'tnl',
		'lanes',
		'gndcol1',
		'gndcol2',
		'bgl',
		'bgr',
		'bgc',
	]

	@property
	def angle_per_seg(self):
		return self.angle / self.length

	@property
	def max_speed(self) -> float:
		if self.speed is None:
			return 1.0
		else:
			return self.speed / SPEED_KPH_SCALE

	def __post_init__(self):
		if self.length < 1:
			raise ValueError(f'Section length must be at least 1 ({self.length=})')

		if self.wall_l is None:
			self.wall_l = 15
		if self.wall_r is None:
			self.wall_r = 15

		if self.tnl:
			self.wall_l = self.wall_r = 0

		if self.pit:
			if self.pit < 0:
				# self.wall_l = max(self.wall_l, PIT_LANE_WALL)
				self.wall_l = PIT_LANE_WALL
			else:
				# self.wall_r = max(self.wall_r, PIT_LANE_WALL)
				self.wall_r = PIT_LANE_WALL

		if not (isinstance(self.wall_l, int) and isinstance(self.wall_r, int) and (0 <= self.wall_l < 16) and (0 <= self.wall_r < 16)):
			raise ValueError(f'Invalid wall value(s): {self.wall_l=}, {self.wall_r=}')

	def to_lua_dict(self) -> dict:

		ret = dict()

		# Always add all ordered fields
		for attr_name in self.LUA_ORDERED_FIELDS:
			if attr_name == 'wall':
				continue
			ret[attr_name] = getattr(self, attr_name)

		# Replace wall with encoded
		wall_l = self.wall_l
		wall_r = self.wall_r
		if not (isinstance(wall_l, int) and isinstance(wall_r, int) and (0 <= wall_l < 16) and (0 <= wall_r < 16)):
			raise ValueError(f'Invalid wall value(s): {wall_l=}, {wall_r=}')
		wall_8bit = wall_l * 16 + wall_r
		ret['wall'] = wall_8bit

		# Only add keyword fields if non-default
		default = Section(length=1, wall_l=15, wall_r=15)
		for attr_name in self.LUA_KW_FIELDS:
			val = getattr(self, attr_name)
			if val != getattr(default, attr_name):
				ret[attr_name] = val

		return ret

	def to_lua_compressed(self, section_types) -> str:

		vals_uncompressed = self.to_lua_dict()

		vals_uncompressed['length'] = vals_uncompressed['length'] - 1
		vals_uncompressed['x'] = round((vals_uncompressed['x'] or 0) * 64) + 128
		vals_uncompressed['pitch'] = round(vals_uncompressed['pitch'] * 64) + 127
		vals_uncompressed['max_speed'] = round(vals_uncompressed['max_speed'] * 255)

		angle_before = vals_uncompressed['angle']
		angle_compressed = round(angle_before * 128) + 128
		angle_after = (angle_compressed - 128) / 128

		if not isclose(angle_before, angle_after):
			# warn(f'Angle error: {angle_before} =/ {angle_before*360:.1f} -> {angle_compressed} -> {angle_after} = {angle_after*360:.1f}')
			raise ValueError(f'Angle error: {angle_before:.12f} = {angle_before*360:.1f} -> {angle_compressed} -> {angle_after} = {angle_after*360:.1f}')

		vals_uncompressed['angle'] = angle_compressed

		items = [vals_uncompressed.pop(field_name, None) for field_name in self.LUA_ORDERED_FIELDS]

		if vals_uncompressed:
			section_type = dict(vals_uncompressed)

			if section_type in section_types:
				section_type_idx = section_types.index(section_type) + 1
			else:
				if len(section_types) >= 254:
					raise ValueError('Too many section types')
				section_types.append(section_type)
				section_type_idx = len(section_types)
		else:
			section_type_idx = 0

		items.append(section_type_idx)

		for item, field_name in zip(items, self.LUA_ORDERED_FIELDS + ['section_type'], strict=True):
			assert isinstance(item, int), f"{item=} ({field_name})"
			if not 0 <= item <= 255:
				raise ValueError(f'field "{field_name}" out of range after compression: {item}')

		assert len(items) == 7, f'{items=}'

		items = [P8SCII[item] for item in items]
		return ''.join(items)


class Track:
	def __init__(
			self,
			name,
			sections: list[Section],
			start_heading: float,
			track_width: float,
			shoulder_half_width: float,
			wall: int | None = None,
			lanes: int = 1,
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

		self.wall = wall
		self.lanes = lanes
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

		self._set_deltas()

		# TODO: use the new logic
		# self._calculate_racing_line_original_logic()
		# self._calculate_racing_line()

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

	def _set_deltas(self):
		for idx in range(len(self.sections)):
			sec0 = self.sections[idx]
			sec1 = self.sections[(idx + 1) % len(self.sections)]

			wall0_l = sec0.wall_l
			wall0_r = sec0.wall_r

			wall1_l = sec1.wall_l
			wall1_r = sec1.wall_r

			# TODO: this logic is probably obsolete (handled in section post_init)
			if sec0.tnl:
				wall0_r = wall0_l = 0

			if sec1.tnl:
				wall1_r = wall1_l = 0

			sec0.dwall_l = (wall1_l - wall0_l) / sec0.length
			sec0.dwall_r = (wall1_r - wall0_r) / sec0.length

			sec0.dpit = (sec1.pit - sec0.pit) / sec0.length

	@staticmethod
	def _corner_exit_entrance_original_logic(section: Section) -> float:
		"""
		Bad original logic, ported from Lua
		"""
		direction = sgn(section.angle)
		if section.max_speed < 0.5:
			# Low speed
			return -0.75 * direction
		elif section.max_speed < 0.75:
			# Med speed
			return -0.25 * direction
		else:
			# High speed
			return 0.5 * direction

	def _calculate_racing_line_original_logic(self):
		"""
		Bad original logic, ported from Lua
		"""

		BRAKE_DECEL = 1/128

		# Max speed

		for section in self.sections:
			max_speed = min(1.25 - abs(32 * section.angle_per_seg), 1)
			max_speed = max(max_speed, 0.25)
			max_speed = max_speed ** 2
			section.max_speed = max_speed
		del section

		# Apex, entrance, exit

		for idx in range(len(self.sections)):
			section0 = self.sections[idx]
			section1 = self.sections[(idx + 1) % len(self.sections)]

			if section0.angle == 0:
				# Straight, apex indicates braking point
				# apex will be updated later once we know next section entrance & apex
				pass

			elif section1.angle != 0 and ((section0.angle > 0) == (section1.angle > 0)):
				# 2 corners of same direction in a row
				# Apex is at end of first
				# TODO: apex isn't necessarily in the middle of the two - could be double-apex, or just early or late
				# TODO: special logic for more than 2 section segments in a row
				section0.apex_idx = section0.length - 1
				section0.apex_x = 0.9 * sgn(section0.angle)
				section0.exit_x = section0.apex_x

				section1.apex_idx = 0
				section1.apex_x = section0.apex_x
				section1.x = section0.apex_x

				section0.x = self._corner_exit_entrance_original_logic(section0)
				section1.exit_x = self._corner_exit_entrance_original_logic(section1)

			elif section0.apex_idx is None:
				# Standalone section, or 2 corners changing direction (e.g. chicane)
				# Apex is in middle
				section0.apex_idx = section0.length // 2 - 1
				section0.apex_x = 0.9 * sgn(section0.angle)
				section0.x = self._corner_exit_entrance_original_logic(section0)
				section0.exit_x = section0.x
		del section0, section1

		# Consolidate entrances & exits

		for idx in range(len(self.sections)):
			section0 = self.sections[idx]
			section1 = self.sections[(idx + 1) % len(self.sections)]

			if (section0.exit_x is not None) and (section1.x is not None):
				section0.exit_x = 0.5 * (section0.exit_x + section1.x)
				section1.x = section0.exit_x
			elif section0.exit_x:
				section1.x = section0.exit_x
			elif section1.x:
				section0.exit_x = section1.x
			else:
				section0.exit_x = section1.x = 0

			if section0.apex_x is None:

				section0.apex_idx = section0.length - 1
				section0.apex_x = section0.exit_x

				if section1.max_speed < 0.99:

					assert section1.apex_idx is not None, f"{section1.max_speed=}"

					# Use apex to indicate braking point
					decel_needed = 1.0 - section1.max_speed
					# FIXME: this isn't right! brake_decel is per frame, not per segment;
					# frames per segment depends on speed!
					decel_segments = decel_needed / (8 * BRAKE_DECEL)
					decel_segments -= 0.5*(section1.apex_idx + 1)
					decel_segments = max(0, ceil(decel_segments))
					section0.apex_idx = max(1, section0.length - decel_segments - 1)
					section0.apex_x = section0.exit_x

			assert section0.apex_idx is not None
			assert section0.apex_x is not None

	def _calculate_racing_line(self):

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

		for section_idx, section in enumerate(self.sections):

			next_section = self.sections[(section_idx + 1) % len(self.sections)]

			try:
				length = section.length
				angle_per_seg = section.angle_per_seg

				if (section.x is not None) and (next_section.x is not None):
					x0 = section.x
					x1 = next_section.x
					if RACING_LINE_SINE_INTERP:
						x0 = asin(x0)
						x1 = asin(x1)
					dx = (x1 - x0) / section.length
				else:
					x0 = x1 = dx = None

				# Angle per section will be at p8 precision, but angle per segment may not be
				# HACK: just round it at start of each
				heading = float_round_pico8_precision(heading)
				for idx in range(length):
					# Angle units:
					# The game uses are +right / -left, with 1 = full circle
					# Direction is backwards from Cartesian coordinates, so subtract instead of adding
					heading = (heading - angle_per_seg) % 1.0

					center_start = Point(x, y)
					x += segment_length_units * cos(TWO_PI * heading)
					y += segment_length_units * sin(TWO_PI * heading)
					center_end = Point(x, y)

					if dx is not None:
						racing_line_start_x = x0 + idx * dx
						racing_line_end_x = x0 + (idx + 1) * dx
						if RACING_LINE_SINE_INTERP:
							racing_line_start_x = sin(racing_line_start_x)
							racing_line_end_x = sin(racing_line_end_x)
					else:
						racing_line_start_x = racing_line_end_x = None

					seg = Segment(
						idx=len(self.segments),
						angle=angle_per_seg,
						center_start=center_start,
						center_end=center_end,
						max_speed=section.max_speed,
						racing_line_start_x=racing_line_start_x,
						racing_line_end_x=racing_line_end_x,
					)
					self.segments.append(seg)
					section.segments.append(seg)

			except Exception as ex:
				raise Exception(f'Failed to parse track "{self.name}" corner {section_idx}: {ex}') from ex

		self.end_heading = float_round_pico8_precision(heading)

		_set_normals(self.segments)

	def lua_output_data(self, defaults: dict, section_types: list[dict], compress: bool, lowercase: bool):

		ret = dict()

		ret['name'] = self.name.casefold() if lowercase else self.name

		ret['minimap_scale'] = round(1/self.minimap_scale)
		ret['minimap_step'] = self.minimap_step
		ret['minimap_offset_x'] = self.minimap_offset_x
		ret['minimap_offset_y'] = self.minimap_offset_y

		if self.start_heading != defaults['start_heading']:
			ret['start_heading'] = self.start_heading
		if self.track_width != defaults['track_width']:
			ret['track_width'] = self.track_width
		if self.shoulder_half_width != defaults['shoulder_half_width']:
			ret['shoulder_half_width'] = self.shoulder_half_width

		if self.wall is not None:
			ret['wall'] = self.wall

		if self.lanes > 1:
			ret['lanes'] = self.lanes

		if self.gndcol1 is not None:
			ret['gndcol1'] = self.gndcol1
		if self.gndcol2 is not None:
			ret['gndcol2'] = self.gndcol2

		if self.city_bg:
			ret['city_bg'] = True

		if self.tree_bg:
			ret['tree_bg'] = True

		# This also get calculated in Lua; add it for data sanity check
		ret['total_segment_count'] = sum(s.length for s in self.sections)

		if compress:
			sections_compressed = ''.join(s.to_lua_compressed(section_types) for s in self.sections)
			ret['sections_compressed'] = sections_compressed
			ret['sections'] = []
		else:
			ret['sections'] = [section.to_lua_dict() for section in self.sections]

		return ret


def _load_data(filename=DATA_FILENAME_IN):
	vprint(f'Loading {filename}')
	with open(filename, 'r') as f:
		return yaml.safe_load(f)


def _set_normals(segments: list[Segment]):

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

		# FIXME HACK: normal signs are backwards
		# (Should change normal() logic instead)
		segment.normal_start = -norm1
		segment.normal_end = -norm2


def _process_track(yaml_track: dict, yaml_defaults: dict) -> Track:

	name = yaml_track['name'].strip()
	length_km = yaml_track.get('length_km', None)

	start_heading = yaml_track.get('start_heading', yaml_defaults['start_heading'])
	length_scale = yaml_track.get('length_scale', yaml_defaults.get('length_scale', 1))
	angle_scale = yaml_track.get('angle_scale', yaml_defaults.get('angle_scale', 1.0))
	track_width = yaml_track.get('track_width', yaml_defaults['track_width'])
	shoulder_half_width = yaml_track.get('shoulder_half_width', yaml_defaults['shoulder_half_width'])
	track_wall = yaml_track.get('wall', yaml_defaults.get('wall', 15))

	sections = copy(yaml_track['sections'])

	for section in sections:
		section_wall = section.pop('wall', track_wall)
		if 'wall_l' not in section:
			section['wall_l'] = section_wall
		if 'wall_r' not in section:
			section['wall_r'] = section_wall

	sections = [Section(**s) for s in sections]

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
		wall=track_wall,
		lanes=yaml_track.get('lanes', 1),
		city_bg=yaml_track.get('city_bg', False),
		tree_bg=yaml_track.get('tree_bg', False),
		gndcol1=yaml_track.get('gndcol1', None),
		gndcol2=yaml_track.get('gndcol2', None),
	)

	width = track.x_max - track.x_min
	height = track.y_max - track.y_min

	vprint(f'Length: {len(track.segments)} segments ({len(track.sections)} sections)')
	if length_km is not None:
		m_per_segment = length_km / len(track.segments) * 100
		vprint(f'True length: {length_km} km, segment length: {m_per_segment:.3f} m')
	vprint(f'End coord: ({track.points[-1][0]:.3f}, {track.points[-1][1]:.3f})')

	if not isclose(track.start_heading, track.end_heading):
		warn(f'Track "{name}" start heading {track.start_heading} != end heading {track.end_heading}')
		# raise ValueError(f'Track "{name}" start heading {track.start_heading} != end heading {track.end_heading}')

	vprint(f'Start heading: {track.start_heading}, end heading: {track.end_heading}')
	vprint(f'X range: [{track.x_min:.3f}, {track.x_max:.3f}], Y range: [{track.y_min:.3f}, {track.y_max:.3f}]')
	vprint(f'minimap_scale: {track.minimap_scale:.3f}, resulting resolution: {ceil(width*track.minimap_scale)}x{ceil(height*track.minimap_scale)}')
	vprint(f'minimap_step: {track.minimap_step}')
	vprint(f'minimap_offset: ({track.minimap_offset_x}, {track.minimap_offset_y})')

	return track


def _to_lua_str(val, indent=0, quote_strings=True) -> str:

	indent_str = '\t' * indent

	if val is None:
		return 'nil'

	elif isinstance(val, bool):
		return str(val).lower()

	elif isinstance(val, int):
		return str(val)

	elif isinstance(val, float):
		return float_to_lua_str(val)

	elif isinstance(val, str):
		return f'"{val}"' if quote_strings else val

	elif isinstance(val, (tuple, list)):
		if val and isinstance(val[0], dict):
			# Split lines
			return '{' + ','.join('\n\t' + indent_str + _to_lua_str(v, indent=1+indent, quote_strings=quote_strings) for v in val) + '\n' + indent_str + '}'
		else:
			# All on 1 line
			return '{' + ','.join(_to_lua_str(v, indent=indent, quote_strings=quote_strings) for v in val) + '}'

	else:
		if not isinstance(val, dict):
			warn(f'Unknown type, treating as dict: {type(val).__name__}')
			val = vars(val)
		# TODO: split lines
		return '{' + ','.join(f'{k}={_to_lua_str(v, indent=indent, quote_strings=quote_strings)}' for k, v in val.items()) + '}'


def generate(
		compress_p8=True,
		compress_p64=False,
		draw=True,
		show=False,
		):
	data = _load_data()

	tracks = data.pop('tracks')

	BUILD_DIR.mkdir(parents=True, exist_ok=True)
	MAP_DIR_OUT.mkdir(parents=True, exist_ok=True)

	if DATA_FILENAME_OUT_P8.exists():
		DATA_FILENAME_OUT_P8.unlink()

	if DATA_FILENAME_OUT_P64.exists():
		DATA_FILENAME_OUT_P64.unlink()

	with (
			open(DATA_FILENAME_OUT_P8, 'w', newline='\n', encoding='utf-8') as f8,
			open(DATA_FILENAME_OUT_P64, 'w', newline='\n', encoding='utf-8') as f64):

		# Write common values

		for k, v in data.items():
			# These are applied in this script; skip them
			if k in ['length_scale', 'angle_scale']:
				continue
			f8.write(f'{k}={_to_lua_str(v)}\n')
			f64.write(f'{k}={_to_lua_str(v)}\n')

		# Write tracks

		section_types = []

		f8.write('tracks={\n')
		f64.write('tracks={\n')

		for track_yaml in tracks:
			vprint(f'Processing track "{track_yaml["name"]}"')
			track = _process_track(track_yaml, data)

			if draw:

				# vprint('Drawing full-res line map')
				filename = MAP_DIR_OUT / f'{track.name.casefold()}_linemap.png'
				draw_line_map(track.points, show=show, filename=filename)

				# vprint('Drawing minimap')
				minimap_points = [p * track.minimap_scale for p in track.points[::track.minimap_step]]
				filename = MAP_DIR_OUT / f'{track.name.casefold()}_minimap.png'
				draw_line_map(minimap_points, curve_joint=False, show=show, filename=filename)

				# vprint('Drawing track')
				draw_track(track, MAP_DIR_OUT / track.name.casefold())

			track_lua_data_p8 = track.lua_output_data(data, section_types, compress=compress_p8, lowercase=True)
			sections_p8 = track_lua_data_p8.pop('sections')				

			track_lua_data_p64 = track.lua_output_data(data, section_types, compress=compress_p64, lowercase=False)
			sections_p64 = track_lua_data_p64.pop('sections')

			f8.write('{\n')
			f64.write('{\n')

			for key, val in track_lua_data_p8.items():
				f8.write(f'\t{key}={_to_lua_str(val, indent=1)},\n')
			for key, val in track_lua_data_p64.items():
				f64.write(f'\t{key}={_to_lua_str(val, indent=1)},\n')

			for section in sections_p8:
				f8.write(f'\t{_to_lua_str(section, indent=1)},\n')
			for section in sections_p64:
				f64.write(f'\t{_to_lua_str(section, indent=1)},\n')

			f8.write('},\n')
			f64.write('},\n')

			vprint()

		f8.write('}\n')
		f64.write('}\n')

		f8.write('section_types={\n')
		f64.write('section_types={\n')
		for section_type in section_types:
			f8.write(f'\t{_to_lua_str(section_type, indent=1)},\n')
			f64.write(f'\t{_to_lua_str(section_type, indent=1)},\n')
		f8.write('}\n')
		f64.write('}\n')

	vprint(f'Data saved as {DATA_FILENAME_OUT_P8}')


def main():
	parser = ArgumentParser()

	parser.add_argument('--no-draw', dest='draw', action='store_false')
	parser.add_argument('--show', action='store_true')
	parser.add_argument('--uncompressed', dest='compress', action='store_false')
	parser.add_argument('--quiet', dest='verbose', action='store_false')

	args = parser.parse_args(args)

	set_verbose(args.verbose)

	generate(
		draw=args.draw,
		show=args.show,
		compress_p8=args.compress,
	)


if __name__ == "__main__":
	main()
