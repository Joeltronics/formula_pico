#!/usr/bin/env python3

from argparse import ArgumentParser
from collections import namedtuple
from dataclasses import dataclass
from enum import Enum, auto
from math import sqrt, isclose, atan2, cos, sin, radians, degrees, ceil, floor
from typing import Final

from matplotlib import pyplot as plt
from matplotlib.patches import Rectangle, Polygon
import numpy as np

from common import Point, calculate_racing_line_radius


SQRT_2: Final = sqrt(2)
COS_45: Final = 1 / SQRT_2

PI: Final = np.pi
TWO_PI: Final = 2*np.pi
HALF_PI: Final = np.pi/2

DEFAULT_TICK_SIZE: Final = 1e-3


@dataclass
class RacingLine:
	label: str | None = None

	grip: float | None = None

	time: np.ndarray | None = None

	distance: np.ndarray | None = None  # Distance along track, relative to center of corner
	x_position: np.ndarray | None = None  # Lateral position, relative to center of track
	angle_rel_degrees: np.ndarray | None = None  # Angle relative to track direction, in degrees

	position: np.ndarray | None = None  # Position, complex (X, Y)
	velocity: np.ndarray | None = None  # Velocity, complex (X, Y)
	acceleration: np.ndarray | None = None  # Total acceleration, complex (X, Y)
	acceleration_forward: np.ndarray | None = None  # Forward acceleration, complex (X, Y)
	acceleration_lateral: np.ndarray | None = None  # Lateral acceleration, complex (X, Y)


"""
Coordinates:
				  ________________  __
				/                 |
			/                     |     track width
		/               __________| __
	/                /
  /               /                    inner radius
/              /     _|_            __
|             |       |
|             |                       lead in
|             |                     __
| track width | inner | lead out |
				radius
"""


def draw_corner(ax, angle_degrees, *, track_width, entrance_len, exit_len, radius_center, color='grey'):
	track_half_width = track_width / 2
	radius_inner = radius_center - track_half_width
	radius_outer = radius_center + track_half_width

	# Entrance
	entrance_patch = Rectangle((-track_width - radius_inner, -entrance_len), track_width, entrance_len, color=color)

	if angle_degrees in [90, 180]:

		# Exit
		if angle_degrees == 180:
			exit_patch = Rectangle((radius_inner, -exit_len), track_width, exit_len, color=color)
		else:
			exit_patch = Rectangle((0, radius_inner), exit_len, track_width, color=color)

		# Curve

		if angle_degrees == 180:
			x = np.linspace(-radius_outer, radius_outer, num=256, endpoint=True)
			y_bot_mask = np.abs(x) < radius_inner
		else:
			x = np.linspace(-radius_outer, 0, num=128, endpoint=True)
			y_bot_mask = x > -radius_inner

		y_top = np.sqrt(radius_outer**2 - np.square(x))

		y_bot = np.zeros_like(x)
		y_bot[y_bot_mask] = np.sqrt(radius_inner**2 - np.square(x[y_bot_mask]))

	else:

		# Exit

		exit_angle_rad = radians(180 - angle_degrees)

		exit_heading_rad = radians(90 - angle_degrees)
		exit_heading_unit = Point(cos(exit_heading_rad), sin(exit_heading_rad))

		turn_end_bot = radius_inner * Point(cos(exit_angle_rad), sin(exit_angle_rad))
		turn_end_top = radius_outer * Point(cos(exit_angle_rad), sin(exit_angle_rad))

		exit_end_bot = turn_end_bot + exit_len*exit_heading_unit
		exit_end_top = turn_end_top + exit_len*exit_heading_unit

		exit_patch = Polygon(
			np.array([turn_end_bot, turn_end_top, exit_end_top, exit_end_bot]),
			closed=True,
			color=color,
		)

		# Curve

		x = np.linspace(
			-radius_outer,
			max(turn_end_bot.x, turn_end_top.x),
			num=(256 if angle_degrees > 90 else 128),
			endpoint=True,
		)

		y_top = np.sqrt(radius_outer**2 - np.square(x))

		y_bot = np.zeros_like(x)
		y_bot_mask = np.abs(x) < radius_inner
		y_bot[y_bot_mask] = np.sqrt(radius_inner**2 - np.square(x[y_bot_mask]))
		y_bot[x > turn_end_bot.x] = turn_end_bot.y

	ax.fill_between(x, y_bot, y_top, color=color)
	ax.add_patch(exit_patch)
	ax.add_patch(entrance_patch)


def calculate_racing_line_with_radius(
		radius: float,
		*,
		track_width: float,
		radius_center: float,
		turn_angle_degrees: float = 90,
		start: tuple[float, float] | None = None,
		apex_angle_degrees: float | None = None,
		radius_post_apex: float | None = None,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	if radius <= 0:
		raise ValueError(f'{radius=}')

	if not 0 < turn_angle_degrees <= 180:
		raise ValueError(f'{turn_angle_degrees=}')

	if apex_angle_degrees is None:
		apex_angle_degrees = turn_angle_degrees / 2
	elif not 0 < apex_angle_degrees < turn_angle_degrees:
		raise ValueError(f'{apex_angle_degrees=}, {turn_angle_degrees=}')

	if start is None:
		start = (-radius, 0)

	track_half_width = track_width / 2
	radius_inner = radius_center - track_half_width

	apex_angle_rads = radians(90 - apex_angle_degrees)

	# Calculate velocity so that acceleration is independent of radius
	# a = v^2 / r
	# v = sqrt(a * r)
	accel_mag = grip
	velocity_mag_pre_apex = sqrt(accel_mag * radius)

	x, y = start

	vx = 0
	vy = velocity_mag_pre_apex

	pos_x = []
	pos_y = []
	vel_x = []
	vel_y = []
	acc_x = []
	acc_y = []
	acc_f_x = []
	acc_f_y = []
	acc_l_x = []
	acc_l_y = []

	distance = []
	x_position = []
	angle_rel_degrees = []

	turn_angle_radians = radians(turn_angle_degrees)

	center_arc_length = turn_angle_radians * radius_center

	end_velocity_angle = radians(90 - turn_angle_degrees)
	end_position_angle = radians(180 - turn_angle_degrees)

	class State(Enum):
		entrance = auto()
		corner_pre_apex = auto()
		corner_post_apex = auto()
		exit = auto()

	state = State.entrance

	while True:

		# TODO: optional trail braking

		position_radius = sqrt(x*x + y*y)
		position_angle = atan2(y, x)

		velocity_angle = atan2(vy, vx)
		velocity_mag = np.sqrt(vx*vx + vy*vy)
		velocity_norm = vx / velocity_mag, vy / velocity_mag

		if state == State.entrance and y >= 0:
			state = State.corner_pre_apex

		if state == State.corner_pre_apex and velocity_angle <= apex_angle_rads:
			state = State.corner_post_apex

		if state == State.corner_post_apex and position_angle < end_position_angle:
			state = State.exit

		target_radius = radius_post_apex if (radius_post_apex is not None and state in [State.corner_post_apex, State.exit]) else radius

		needed_centripital_acceleration = velocity_mag*velocity_mag / target_radius

		forward_accel_squ = accel_mag*accel_mag - needed_centripital_acceleration*needed_centripital_acceleration
		assert forward_accel_squ > -1e6, f"{forward_accel_squ=}"
		forward_acceleration = sqrt(max(0, forward_accel_squ))
		# TODO: option to limit max forward acceleration

		al_x = needed_centripital_acceleration * velocity_norm[1]
		al_y = needed_centripital_acceleration * -velocity_norm[0]

		af_x = forward_acceleration * velocity_norm[0]
		af_y = forward_acceleration * velocity_norm[1]

		atot_x = al_x + af_x
		atot_y = al_y + af_y

		this_accel_mag = sqrt(atot_x*atot_x + atot_y*atot_y)
		assert isclose(this_accel_mag, accel_mag, rel_tol=1e-2), f"{this_accel_mag=}, {accel_mag=}"  # TODO: This fails with rel_tol >= 1e-3, why?

		if state == State.entrance:
			# Before start of turn, center line is up
			center_angle = HALF_PI
			d = y - 0.5*center_arc_length
			x_pos = x + radius_inner + track_half_width

		elif state == State.exit:

			if turn_angle_degrees == 90:
				# After end of turn, center line is to the right
				assert x >= 0
				center_angle = 0
				d = 0.5*center_arc_length + x
				x_pos = (radius_inner + track_half_width) - y
			elif turn_angle_degrees == 180:
				# After end of turn, center line is downward
				assert y <= 0
				center_angle = -HALF_PI
				d = -y + 0.5*center_arc_length
				x_pos = radius_inner + track_half_width - x
			else:
				# TODO
				center_angle = np.nan
				d = np.nan
				x_pos = np.nan

		else:
			# Mid-turn
			assert state in [State.corner_pre_apex, State.corner_post_apex]
			center_angle = position_angle - HALF_PI
			d = (PI - 0.5*turn_angle_radians - position_angle) * radius_center
			x_pos = radius_center - position_radius

		angle_rel = center_angle - velocity_angle

		pos_x.append(x)
		pos_y.append(y)
		vel_x.append(vx)
		vel_y.append(vy)
		acc_x.append(atot_x)
		acc_y.append(atot_y)
		acc_f_x.append(af_x)
		acc_f_y.append(af_y)
		acc_l_x.append(al_x)
		acc_l_y.append(al_y)
		distance.append(d)
		x_position.append(x_pos)
		angle_rel_degrees.append(degrees(angle_rel))

		if velocity_angle < end_velocity_angle:
			break

		vx += atot_x * tick_size
		vy += atot_y * tick_size
		x += vx * tick_size
		y += vy * tick_size

		velocity_mag = np.sqrt(vx*vx + vy*vy)

		if radius_post_apex is None or velocity_angle >= apex_angle_rads:
			assert isclose(velocity_mag, velocity_mag, rel_tol=1e-3), f"{velocity_mag=}, {velocity_mag=}"

	assert len(pos_x) == len(pos_y) == len(vel_x) == len(vel_y) == len(acc_x) == len(acc_y) == len(acc_f_x) == \
		len(acc_f_y) == len(acc_l_x) == len(acc_l_y) == len(distance) == len(x_position) == len(angle_rel_degrees)

	position = np.array(pos_x) + 1j * np.array(pos_y)
	velocity = np.array(vel_x) + 1j * np.array(vel_y)
	acceleration = np.array(acc_x) + 1j * np.array(acc_y)
	acceleration_forward = np.array(acc_f_x) + 1j * np.array(acc_f_y)
	acceleration_lateral = np.array(acc_l_x) + 1j * np.array(acc_l_y)

	time = tick_size * np.arange(len(pos_x), dtype=np.float64)

	return RacingLine(
		time=time,
		grip=grip,
		distance=np.array(distance),
		x_position=np.array(x_position),
		angle_rel_degrees=np.array(angle_rel_degrees),
		position=position,
		velocity=velocity,
		acceleration=acceleration,
		acceleration_forward=acceleration_forward,
		acceleration_lateral=acceleration_lateral,
		label=label,
	)


def calculate_racing_line(
		track_width: float,
		radius_center: float,
		apex_angle_degrees: float | None = None,
		*,
		turn_angle_degrees: float = 90,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	if apex_angle_degrees is None:
		apex_angle_degrees = 0.5 * turn_angle_degrees

	if not (0 < apex_angle_degrees <= 90 and apex_angle_degrees < turn_angle_degrees):
		raise ValueError(f'{apex_angle_degrees=}, {turn_angle_degrees=}')

	angle_post_apex_degrees = turn_angle_degrees - apex_angle_degrees

	r_pre, start_x, start_y = calculate_racing_line_radius(
		track_width=track_width,
		radius_track_center=radius_center,
		apex_angle_degrees=apex_angle_degrees,
	)
	r_post, _, _ = calculate_racing_line_radius(
		track_width=track_width,
		radius_track_center=radius_center,
		apex_angle_degrees=angle_post_apex_degrees,
	)

	return calculate_racing_line_with_radius(
		r_pre,
		start=(start_x, start_y),
		radius_post_apex=r_post,
		turn_angle_degrees=turn_angle_degrees,
		apex_angle_degrees=apex_angle_degrees,
		tick_size=tick_size,
		label=label,
		grip=grip,
		track_width=track_width,
		radius_center=radius_center,
	)


def main():
	parser = ArgumentParser()
	parser.add_argument('--tick', type=float, default=DEFAULT_TICK_SIZE, help=f'Simulation tick size, default {DEFAULT_TICK_SIZE:e}')
	args = parser.parse_args()

	track_width = 2
	track_half_width = track_width / 2

	entrance_len = 6
	exit_len = 10

	radius_center = 3
	radius_inner = radius_center - track_half_width
	radius_outer = radius_center + track_half_width

	# Racing lines
	kwargs = dict(tick_size=args.tick, track_width=track_width, radius_center=radius_center)
	kwargs_wide = dict(tick_size=args.tick, track_width=2*track_width, radius_center=radius_center)

	racing_lines_constant_grip = [
		calculate_racing_line_with_radius(radius_inner, label='Inside', **kwargs),
		calculate_racing_line_with_radius(radius_outer, label='Outside', **kwargs),
		calculate_racing_line_with_radius(radius_center, label='Center', **kwargs),
		calculate_racing_line(label='Geometric', **kwargs),
		calculate_racing_line(apex_angle_degrees=50, label='Late apex (50$\degree$)', **kwargs),
		calculate_racing_line(apex_angle_degrees=60, label='Late apex (60$\degree$)', **kwargs),
		calculate_racing_line(apex_angle_degrees=75, label='Late apex (75$\degree$)', **kwargs),
	]

	racing_lines_wide_track = [
		calculate_racing_line_with_radius(radius_center - track_width, label='Inside', **kwargs_wide),
		calculate_racing_line_with_radius(radius_center + track_width, label='Outside', **kwargs_wide),
		calculate_racing_line_with_radius(radius_center, label='Center', **kwargs_wide),
		calculate_racing_line(label='Geometric', **kwargs_wide),
		calculate_racing_line(apex_angle_degrees=50, label='Late apex (50$\degree$)', **kwargs_wide),
		calculate_racing_line(apex_angle_degrees=60, label='Late apex (60$\degree$)', **kwargs_wide),
		calculate_racing_line(apex_angle_degrees=75, label='Late apex (75$\degree$)', **kwargs_wide),
	]

	racing_lines_geo_varying_grip = [
		calculate_racing_line(grip=grip, label=f'Grip={grip:g}', **kwargs)
		for grip in [0.5, 0.75, 1, 1.5, 2]
	] 
	
	racing_lines_late_apex_varying_grip = [
		calculate_racing_line(apex_angle_degrees=60, grip=grip, label=f'Grip={grip:g}', **kwargs)
		for grip in [0.5, 0.75, 1, 1.5, 2]
	]

	racing_lines_45 = [
		calculate_racing_line_with_radius(radius_inner, label='Inside', turn_angle_degrees=45, **kwargs),
		calculate_racing_line_with_radius(radius_outer, label='Outside', turn_angle_degrees=45, **kwargs),
		calculate_racing_line_with_radius(radius_center, label='Center', turn_angle_degrees=45, **kwargs),
		calculate_racing_line(turn_angle_degrees=45, label='Geometric', **kwargs),
		calculate_racing_line(turn_angle_degrees=45, apex_angle_degrees=30, label='Late apex (30$\degree$)', **kwargs),
	]
	racing_lines_60 = [
		calculate_racing_line_with_radius(radius_inner, label='Inside', turn_angle_degrees=60, **kwargs),
		calculate_racing_line_with_radius(radius_outer, label='Outside', turn_angle_degrees=60, **kwargs),
		calculate_racing_line_with_radius(radius_center, label='Center', turn_angle_degrees=60, **kwargs),
		calculate_racing_line(turn_angle_degrees=60, label='Geometric', **kwargs),
		calculate_racing_line(turn_angle_degrees=60, apex_angle_degrees=45, label='Late apex (45$\degree$)', **kwargs),
	]
	racing_lines_135 = [
		calculate_racing_line_with_radius(radius_inner, label='Inside', turn_angle_degrees=135, **kwargs),
		calculate_racing_line_with_radius(radius_outer, label='Outside', turn_angle_degrees=135, **kwargs),
		calculate_racing_line_with_radius(radius_center, label='Center', turn_angle_degrees=135, **kwargs),
		calculate_racing_line(turn_angle_degrees=135, label='Geometric', **kwargs),
		calculate_racing_line(turn_angle_degrees=135, apex_angle_degrees=90, label='Late apex (90$\degree$)', **kwargs),
	]
	racing_lines_180 = [
		calculate_racing_line_with_radius(radius_inner, label='Inside', turn_angle_degrees=180, **kwargs),
		calculate_racing_line_with_radius(radius_outer, label='Outside', turn_angle_degrees=180, **kwargs),
		calculate_racing_line_with_radius(radius_center, label='Center', turn_angle_degrees=180, **kwargs),
		calculate_racing_line(turn_angle_degrees=180, apex_angle_degrees=90, label='Geometric', **kwargs),
	]

	for turn_angle, this_track_width, racing_lines, title in [
			(90, track_width, racing_lines_constant_grip, 'Racing lines, constant grip'),
			(90, track_width, racing_lines_geo_varying_grip, 'Geometric line, varying Grip'),
			(90, track_width, racing_lines_late_apex_varying_grip, 'Late apex (60$\degree$), varying Grip'),
			(45, track_width, racing_lines_45, '45$\degree$ corner'),
			(60, track_width, racing_lines_60, '60$\degree$ corner'),
			(135, track_width, racing_lines_135, '135$\degree$ corner'),
			(180, track_width, racing_lines_180, '180$\degree$ hairpin'),
			(90, 2*track_width, racing_lines_wide_track, 'Racing lines, wider track'),
			]:

		fig = plt.figure()
		fig.suptitle(title)
		gs = fig.add_gridspec(5, 6)

		ax_pos = fig.add_subplot(gs[:3, 0:2])
		ax_gg = fig.add_subplot(gs[-2:, 0:2])

		ax_d = fig.add_subplot(gs[0, 2:4])
		ax_vel = fig.add_subplot(gs[1, 2:4], sharex=ax_d)
		ax_acc_f = fig.add_subplot(gs[2, 2:4], sharex=ax_d)
		ax_acc_l = fig.add_subplot(gs[3, 2:4], sharex=ax_d)
		ax_acc_t = fig.add_subplot(gs[4, 2:4], sharex=ax_d)

		ax_radius = fig.add_subplot(gs[0, 4:])
		ax_x = fig.add_subplot(gs[1:, 4])
		ax_angle = fig.add_subplot(gs[1:, 5], sharey=ax_x)

		ax_all = [
			ax_pos, ax_gg, ax_acc_t, ax_d, ax_vel, ax_acc_f, ax_acc_l, ax_radius, ax_x, ax_angle
		]

		draw_corner(
			ax_pos, turn_angle,
			track_width=this_track_width, entrance_len=entrance_len, exit_len=exit_len, radius_center=radius_center)

		x_min = 0
		x_max = 0
		y_min = 0
		y_max = 0

		for racing_line in racing_lines:
			label = racing_line.label
			t = racing_line.time
			d = racing_line.distance
			x = np.real(racing_line.position)
			y = np.imag(racing_line.position)
			vel = np.abs(racing_line.velocity)
			acc = np.abs(racing_line.acceleration)
			acc_l = np.abs(racing_line.acceleration_lateral)
			acc_f = np.abs(racing_line.acceleration_forward)

			x_min = min(x_min, np.amin(x))
			y_min = min(y_min, np.amin(y))
			x_max = max(x_max, np.amax(x))
			y_max = max(y_max, np.amax(y))

			ax_pos.plot(x, y, label=label)
			ax_vel.plot(t, vel, label=label)
			ax_acc_t.plot(t, acc, label=label)
			ax_acc_l.plot(t, acc_l, label=label)
			ax_acc_f.plot(t, acc_f, label=label)

			ax_d.plot(t, d, label=label)
			ax_x.plot(racing_line.x_position, d, label=label)
			ax_angle.plot(racing_line.angle_rel_degrees, d, label=label)

			# Also add points for what acceleration would be before & after corner
			gg_x = list(acc_l) + [0, 0]
			gg_y = list(acc_f) + [-racing_line.grip, racing_line.grip]
			ax_gg.scatter(gg_x, gg_y, label=label)

			radius = np.square(vel) / acc_l
			# ax_radius.plot(d, radius, label=label)
			ax_radius.plot(t, radius, label=label)

		ax_pos.set_xticks(np.arange(floor(x_min), ceil(x_max) + 1, 1))
		ax_pos.set_yticks(np.arange(floor(y_min), ceil(y_max) + 1, 1))
		ax_pos.legend()

		for ax in [ax_pos, ax_gg]:
			ax.axis('equal')

		for ax in ax_all:
			ax.grid()

		ax_radius.set_ylabel('Radius $(v^2/a_L)$')
		ax_vel.set_ylabel('Velocity')
		ax_acc_l.set_ylabel('Lateral acceleration')
		ax_acc_f.set_ylabel('Forward acceleration')
		ax_acc_t.set_ylabel('Total acceleration')

		ax_d.set_ylabel('Distance')

		ax_x.set_xlabel('X displacement')
		ax_x.set_ylabel('Distance')
		ax_angle.set_xlabel('Angle against track ($\degree$)')

		ax_gg.set_xlabel('Lateral g')
		ax_gg.set_ylabel('Forward g')

		ax_acc_t.set_xlabel('Time')
		ax_acc_l.set_xlabel('Time')
		

	plt.show()


if __name__ == "__main__":
	main()
