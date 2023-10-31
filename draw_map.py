#!/usr/bin/env python3

from collections import namedtuple
from math import pi as PI, ceil, floor, sqrt
from pathlib import Path
from typing import Final, Iterable

import cairo
from PIL import Image, ImageDraw

from common import lerp, sgn, Point, load_consts


TWO_PI: Final = 2.0 * PI
EPS: Final = 1e-9

WALL_SCALE: Final = 0.5

WALL_THICKNESS = 0.25

CONSTS: Final = load_consts()
PIT_LANE_WIDTH: Final = CONSTS['pit_lane_width']
LANE_LINE_WIDTH: Final = CONSTS['lane_line_width']


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


def iterate_segments(sections: Iterable['Section']):
	for section in sections:
		for segment in section.segments:
			yield section, segment


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


def draw_track(track, path_base, scale=16):

	# TODO: instead of multiplying everything by scale, use SVG units propertly
	# (Haven't figured out how to get this work with Cairo PNG export)

	sections = track.sections
	track_width = track.track_width
	shoulder_half_width = track.shoulder_half_width

	filename_svg = Path(f"{path_base}.svg")
	filename_png = Path(f"{path_base}.png")

	segments = []
	for section in sections:
		segments.extend(section.segments)

	max_wall = max(max(abs(s.wall_l or 0), abs(s.wall_r or 0)) for s in sections)
	max_wall = max(max_wall, track.wall or 0)

	# TODO: why does max_wall need to be doubled? there could be a bug somewhere in wall drawing
	padding = max(2*track_width, 2*max_wall)

	x_min = track.x_min - padding
	y_min = track.y_min - padding
	x_max = track.x_max + padding
	y_max = track.y_max + padding
	width = x_max - x_min
	height = y_max - y_min

	def to_screen(point):
		return Point(point.x - x_min, height - point.y + y_min)

	with cairo.SVGSurface(filename_svg, width*scale, height*scale) as surface:

		c = cairo.Context(surface)

		# Fill with ground color 1

		bgcol = track.gndcol1
		if (bgcol == 5) and (track.gndcol2 is not None):
			bgcol = track.gndcol2
		if bgcol is None:
			bgcol = 3

		c.set_source_rgb(*PALETTE[bgcol])
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

		idx = -1
		for section in sections:

			# roadcol = 1 if section.tnl else 5
			roadcol = 5

			for segment_idx, segment in enumerate(section.segments):
				idx += 1

				l1 = l2 = -track_width
				r1 = r2 = track_width

				pit1 = section.pit + segment_idx * section.dpit
				pit2 = section.pit + (segment_idx + 1) * section.dpit

				assert -1 <= pit1 <= 1 and -1 <= pit2 <= 1, f"{pit1=}, {pit2=}"

				pit_l = pit1 < 0 or pit2 < 0
				pit_r = pit1 > 0 or pit2 > 0

				if pit_r and pit_l:
					raise AssertionError(f"Start and end of segment have pit on different sides: {pit1=}, {pit2=}, {pit_l=}, {pit_r=}")
				elif pit_l:
					l1 += pit1 * PIT_LANE_WIDTH
					l2 += pit2 * PIT_LANE_WIDTH
				elif pit_r:
					r1 += pit1 * PIT_LANE_WIDTH
					r2 += pit2 * PIT_LANE_WIDTH

				polygon(segment.points(l1, r1, l2, r2), PALETTE[roadcol], stroke=2)

				lanes = section.lanes or track.lanes

				if lanes > 1 and (idx % 4 == 0):
					for idx in range(1, lanes):
						lane_rel = idx / lanes
						lane_x = (lane_rel * 2 - 1) * track_width
						polygon(segment.points(lane_x - LANE_LINE_WIDTH, lane_x + LANE_LINE_WIDTH), WHITE, stroke=0)

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

		# for idx, (section, segment) in enumerate(iterate_segments(sections)):
		# 	curb_color = RED if (idx % 2 == 0) else WHITE
		# 	polygon(segment.points(track_width - shoulder_half_width, track_width + shoulder_half_width), curb_color, stroke=0.5)
		# 	polygon(segment.points(-track_width + shoulder_half_width, -track_width - shoulder_half_width), curb_color, stroke=0.5)

		idx = -1
		for section in sections:

			pit_start_l = section.pit == 0  and section.dpit < 0
			pit_start_r = section.pit == 0  and section.dpit > 0
			pit_end_l   = section.pit == -1 and section.dpit > 0
			pit_end_r   = section.pit == 1  and section.dpit < 0

			if section.dpit:
				assert sum([pit_start_l, pit_end_l, pit_start_r, pit_end_r]) == 1
			else:
				assert not any([pit_start_l, pit_end_l, pit_start_r, pit_end_r])

			for segment_idx, segment in enumerate(section.segments):
				idx += 1

				curb_color = RED if (idx % 2 == 0) else WHITE

				pit1 = abs(section.pit + segment_idx * section.dpit)
				pit2 = abs(section.pit + (segment_idx + 1) * section.dpit)

				assert 0 <= pit1 <= 1 and 0 <= pit2 <= 1, f"{pit1=}, {pit2=}"

				start = segment_idx / len(section.segments)
				end = (segment_idx + 1) / len(section.segments)
				assert 0 <= start <= 1 and 0 <= end <= 1

				if pit_start_r or pit_end_r:
					# Right curb (pit entrance/exit)
					polygon(segment.points(
							track_width - shoulder_half_width + PIT_LANE_WIDTH * pit1,
							track_width + shoulder_half_width + PIT_LANE_WIDTH * pit1,
							track_width - shoulder_half_width + PIT_LANE_WIDTH * pit2,
							track_width + shoulder_half_width + PIT_LANE_WIDTH * pit2,
						), curb_color, stroke=0.5)
				else:
					# Right curb (normal)
					polygon(segment.points(
							track_width - shoulder_half_width,
							track_width + shoulder_half_width,
						), curb_color, stroke=0.5)

				if pit_start_l or pit_end_l:
					# Left curb (pit entrance/exit)
					polygon(segment.points(
							-track_width - shoulder_half_width - PIT_LANE_WIDTH * pit1,
							-track_width + shoulder_half_width - PIT_LANE_WIDTH * pit1,
							-track_width - shoulder_half_width - PIT_LANE_WIDTH * pit2,
							-track_width + shoulder_half_width - PIT_LANE_WIDTH * pit2,
						), curb_color, stroke=0.5)
				else:
					# Left curb (normal)
					polygon(segment.points(
							-track_width + shoulder_half_width,
							-track_width - shoulder_half_width,
						), curb_color, stroke=0.5)

		# Walls

		idx = -1
		for section in sections:

			wall_r = section.wall_r
			wall_l = section.wall_l

			for segment_idx, segment in enumerate(section.segments):
				idx += 1
				if section.tnl:
					continue

				# TODO: improve drawing walls around corners
				# Making wall not able to go further than corner radius is a start, but could do more

				# wall_color = PALETTE[7] if ((idx % 6) >= 3) else PALETTE[6]
				wall_color = PALETTE[14]

				if wall_r < 15:
					# TODO: why this 2x?
					wall_start_0 = track_width +  WALL_SCALE*2*(wall_r + section.dwall_r * segment_idx)
					wall_start_1 = track_width + WALL_SCALE*2*(wall_r + section.dwall_r * (segment_idx + 1))
					wall_end_0 = wall_start_0 + WALL_THICKNESS
					wall_end_1 = wall_start_1 + WALL_THICKNESS
					polygon(segment.points(wall_start_0, wall_end_0, wall_start_1, wall_end_1), wall_color, stroke=0.5)

				if wall_l < 15:
					wall_start_0 = track_width + WALL_SCALE*2*(wall_l + section.dwall_l * segment_idx)
					wall_start_1 = track_width + WALL_SCALE*2*(wall_l + section.dwall_l * (segment_idx + 1))
					wall_end_0 = wall_start_0 + WALL_THICKNESS
					wall_end_1 = wall_start_1 + WALL_THICKNESS
					polygon(segment.points(-wall_start_0, -wall_end_0, -wall_start_1, -wall_end_1), wall_color, stroke=0.5)

				# Pit wall
				# if abs(section.pit) == 2:
				# 	polygon(segment.points(track_width, track_width + WALL_THICKNESS), wall_color, stroke=0.5)
				if section.pit == 2:
					polygon(segment.points(track_width, track_width + WALL_THICKNESS), wall_color, stroke=0.5)
				elif section.pit == -2:
					polygon(segment.points(-track_width, -track_width - WALL_THICKNESS), wall_color, stroke=0.5)

		# Racing line

		for _, segment in iterate_segments(sections):

			if segment.max_speed == 1:
				color = (0, 1, 0)
			else:
				color = (
					sqrt(lerp(1, 0, segment.max_speed)),
					sqrt(lerp(0, 0.75, segment.max_speed)),
					0
				)

			if segment.racing_line_start_x is not None:
				line([
						segment.center_start + segment.normal_start * track_width * segment.racing_line_start_x,
						segment.center_end + segment.normal_end * track_width * segment.racing_line_end_x
					], color=color)

		# Apexes & turn numbers

		# for section in (s for s in sections if s.apex_idx is not None):
		for section in sections:

			if section.x is not None:
				seg = section.segments[0]
				entrance_point = seg.center_start + seg.normal_start * track_width * section.x
				circle(entrance_point, radius=0.5, color=(0, 0, 1))

				if section.turn_num:
					text(section.turn_num, entrance_point, bold=True)

			# if section.apex_idx is not None:

			# 	assert 0 <= section.apex_idx < len(section.segments)
			# 	apex_seg = section.segments[section.apex_idx]
			# 	# TODO: use apex_x
			# 	seg_corners = apex_seg.points(-track_width, track_width)

			# 	if section.apex_x is not None:
			# 		# TODO: why subraction?
			# 		apex_point = apex_seg.center_start - apex_seg.normal_start * track_width * section.x
			# 	elif section.angle > 0:
			# 		apex_point = seg_corners[0]
			# 	elif section.angle < 0:
			# 		apex_point = seg_corners[1]
			# 	else:
			# 		apex_point = apex_seg.center_start
				
			# 	radius = 1 if section.angle != 0 else 0.5

			# 	circle(apex_point, radius=radius, color=(0, 0, 1))

			# 	if section.turn_num:
			# 		text(section.turn_num, apex_point, bold=True)

		# TODO: draw corner radius center?

		# TODO: any other details?

		surface.write_to_png(filename_png)
		surface.finish()
