#!/usr/bin/env python3

from argparse import ArgumentParser
from dataclasses import dataclass
from math import sqrt, isclose, atan2, cos, sin
from typing import Final

from matplotlib import pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np


SQRT_2: Final = sqrt(2)
COS_45: Final = 1 / SQRT_2

DEFAULT_TICK_SIZE: Final = 1e-3


@dataclass
class RacingLine:
	label: str | None = None
	grip: float | None = None
	time: np.ndarray | None = None
	position: np.ndarray | None = None
	velocity: np.ndarray | None = None
	acceleration: np.ndarray | None = None
	acceleration_forward: np.ndarray | None = None
	acceleration_lateral: np.ndarray | None = None


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


def plot_corner(ax, *, track_width, entrance_len, exit_len, radius_center):
	track_half_width = track_width / 2
	radius_inner = radius_center - track_half_width
	radius_outer = radius_center + track_half_width

	x_curve = np.linspace(-track_width - radius_inner, 0, num=128, endpoint=True)
	y_curve_top = np.sqrt(radius_outer*radius_outer - np.square(x_curve))
	y_curve_bottom = np.zeros_like(x_curve)
	y_curve_bottom[x_curve > -radius_inner] = np.sqrt(radius_inner*radius_inner - np.square(x_curve[x_curve > -radius_inner]))

	# Curve
	ax.fill_between(x_curve, y_curve_bottom, y_curve_top, color='grey')
	# Lead-in
	ax.add_patch(Rectangle((-track_width - radius_inner, -entrance_len), track_width, entrance_len, color='grey'))
	# Lead-out
	ax.add_patch(Rectangle((0, radius_inner), exit_len, track_width, color='grey'))


def calculate_racing_line(
		radius: float,
		start: tuple[float, float] | None = None,
		apex_angle_degrees: float = 45,
		*,
		radius_post_apex: float | None = None,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	if radius <= 0:
		raise ValueError(f'{radius=}')

	if not 0 < apex_angle_degrees < 90:
		raise ValueError(f'{apex_angle_degrees=}')

	if start is None:
		start = (-radius, 0)

	apex_angle_rads = np.radians(90 - apex_angle_degrees)

	# Calculate velocity so that acceleration is independent of radius
	# a = v^2 / r
	# v = sqrt(a * r)
	accel_mag = grip
	velocity_mag_pre_apex = sqrt(accel_mag * radius)

	if radius_post_apex is None:
		velocity_mag_post_apex = velocity_mag_pre_apex
	else:
		velocity_mag_post_apex = sqrt(accel_mag * radius_post_apex)

	velocity_mag_curr = velocity_mag_pre_apex

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

	while True:

		# TODO: optional trail braking

		velocity_angle = atan2(vy, vx)
		velocity_mag = np.sqrt(vx*vx + vy*vy)
		velocity_norm = vx / velocity_mag, vy / velocity_mag

		after_apex = (velocity_angle < apex_angle_rads)

		target_radius = radius_post_apex if (after_apex and radius_post_apex is not None) else radius

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

		# if after_apex:
		# 	# TODO: don't just immediately jump velocity; increase forward acceleration instead
		# 	velocity_mag_curr = velocity_mag_post_apex

		if velocity_angle < 0:
			break

		vx += atot_x * tick_size
		vy += atot_y * tick_size
		x += vx * tick_size
		y += vy * tick_size

		velocity_mag = np.sqrt(vx*vx + vy*vy)

		if radius_post_apex is None or velocity_angle >= apex_angle_rads:
			# assert isclose(velocity_mag, velocity_mag_pre_apex, rel_tol=1e-6), f"{velocity_mag=}, {velocity_mag_pre_apex=}"
			assert isclose(velocity_mag, velocity_mag, rel_tol=1e-3), f"{velocity_mag=}, {velocity_mag=}"
		# FIXME: this shouldn't be necessary, but is due to immediate jump in velocity
		# vx *= (velocity_mag_curr / velocity_mag)
		# vy *= (velocity_mag_curr / velocity_mag)

	assert len(pos_x) == len(pos_y) == len(vel_x) == len(vel_y) == len(acc_x) == len(acc_y) == len(acc_f_x) == len(acc_f_y) == len(acc_l_x) == len(acc_l_y)

	position = np.array(pos_x) + 1j * np.array(pos_y)
	velocity = np.array(vel_x) + 1j * np.array(vel_y)
	acceleration = np.array(acc_x) + 1j * np.array(acc_y)
	acceleration_forward = np.array(acc_f_x) + 1j * np.array(acc_f_y)
	acceleration_lateral = np.array(acc_l_x) + 1j * np.array(acc_l_y)

	time = tick_size * np.arange(len(pos_x), dtype=np.float64)

	return RacingLine(
		time=time,
		grip=grip,
		position=position,
		velocity=velocity,
		acceleration=acceleration,
		acceleration_forward=acceleration_forward,
		acceleration_lateral=acceleration_lateral,
		label=label,
	)


def calculate_geometric_racing_line(
		track_width: float,
		radius_center: float,
		*,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	radius_inner = radius_center - track_width / 2

	start_x = -track_width - radius_inner

	# Apex X coordinate, relative to start
	a = track_width + radius_inner * (1 - COS_45)

	r"""
	Need to calculate circle which is tanget to x = start.x, and goes through apex

	Essentially we need to solve for triangle:

	             (apex)
	               *
	             / |  \   R
	           /   |     \
	         /     |        \   - 45 degrees
	(start) *------*----------*
	        |  a   |  (R-a)   |
	        |        R        |

	cos(45) = (R - a) / R
	R * cos45 = R - a
	a = R - R * cos45
	a = (1 - cos45) * R
	R = a / (1 - cos45)
	"""
	radius = a / (1 - COS_45)

	start = (start_x, -start_x - radius)

	return calculate_racing_line(radius, start, tick_size=tick_size, label=label, grip=grip)


def calculate_compound_racing_line(
		track_width: float,
		radius_center: float,
		apex_angle_degrees: float,
		*,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	if not 0 < apex_angle_degrees < 90:
		raise ValueError(f'{apex_angle_degrees=}')

	radius_inner = radius_center - track_width / 2

	start_x = -track_width - radius_inner

	# Same as above, but with different angles pre- and post-apex
	angle_pre_apex_rads = np.radians(apex_angle_degrees)
	angle_post_apex_rads = np.radians(90 - apex_angle_degrees)
	cos_pre_apex = cos(angle_pre_apex_rads)
	sin_pre_apex = sin(angle_pre_apex_rads)
	cos_post_apex = cos(angle_post_apex_rads)

	a_pre = track_width + radius_inner * (1 - cos_pre_apex)
	a_post = track_width + radius_inner * (1 - cos_post_apex)

	r_pre = a_pre / (1 - cos_pre_apex)
	r_post = a_post / (1 - cos_post_apex)

	start = (start_x, (radius_inner - r_pre)*sin_pre_apex)

	return calculate_racing_line(
		r_pre,
		start,
		radius_post_apex=r_post,
		apex_angle_degrees=apex_angle_degrees,
		tick_size=tick_size,
		label=label,
		grip=grip,
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

	racing_lines_constant_grip = [
		calculate_racing_line(radius_inner, label='Inside', tick_size=args.tick),
		calculate_racing_line(radius_outer, label='Outside', tick_size=args.tick),
		calculate_racing_line(radius_center, label='Center', tick_size=args.tick),
		calculate_geometric_racing_line(
			track_width=track_width, radius_center=radius_center, label='Geometric', tick_size=args.tick),
		calculate_compound_racing_line(
			track_width=track_width, radius_center=radius_center, apex_angle_degrees=50, label='Late apex (50$\degree$)', tick_size=args.tick),
		calculate_compound_racing_line(
			track_width=track_width, radius_center=radius_center, apex_angle_degrees=60, label='Late apex (60$\degree$)', tick_size=args.tick),
		calculate_compound_racing_line(
			track_width=track_width, radius_center=radius_center, apex_angle_degrees=75, label='Late apex (75$\degree$)', tick_size=args.tick),
	]

	racing_lines_geo_varying_grip = [
		calculate_geometric_racing_line(track_width=track_width, radius_center=radius_center, grip=grip, label=f'Grip={grip:g}')
		for grip in [0.5, 0.75, 1, 1.5, 2]
	] 
	
	racing_lines_late_apex_varying_grip = [
		calculate_compound_racing_line(track_width=track_width, radius_center=radius_center, apex_angle_degrees=60, grip=grip, label=f'Grip={grip:g}')
		for grip in [0.5, 0.75, 1, 1.5, 2]
	]

	# racing_lines_varying_grip = [
	# 	calculate_geometric_racing_line(track_width=track_width, radius_center=radius_center, grip=grip, label=f'Grip={grip:g}')
	# 	for grip in [0.5, 0.75, 1, 1.5, 2]
	# ]

	for racing_lines, title in [
			(racing_lines_constant_grip, 'Racing lines, constant grip'),
			(racing_lines_geo_varying_grip, 'Geometric line, varying Grip'),
			(racing_lines_late_apex_varying_grip, 'Late apex (60$\degree$), varying Grip'),
			]:

		fig, axes = plt.subplots(nrows=4, ncols=2)
		fig.suptitle(title)

		ax_pos = axes[0, 0]
		ax_radius = axes[1, 0]
		ax_gg = axes[2, 0]

		ax_vel = axes[0, 1]
		ax_acc_f = axes[1, 1]
		ax_acc_l = axes[2, 1]
		ax_acc_t = axes[3, 1]

		plot_corner(
			ax_pos,
			track_width=track_width, entrance_len=entrance_len, exit_len=exit_len, radius_center=radius_center)

		for racing_line in racing_lines:
			t = racing_line.time
			x = np.real(racing_line.position)
			y = np.imag(racing_line.position)
			vel = np.abs(racing_line.velocity)
			acc = np.abs(racing_line.acceleration)
			acc_l = np.abs(racing_line.acceleration_lateral)
			acc_f = np.abs(racing_line.acceleration_forward)
			ax_pos.plot(x, y, label=racing_line.label)
			ax_vel.plot(t, vel, label=racing_line.label)
			ax_acc_t.plot(t, acc, label=racing_line.label)
			ax_acc_l.plot(t, acc_l, label=racing_line.label)
			ax_acc_f.plot(t, acc_f, label=racing_line.label)

			# Also add points for what acceleration would be before & after corner
			gg_x = list(acc_l) + [0, 0]
			gg_y = list(acc_f) + [-racing_line.grip, racing_line.grip]
			ax_gg.scatter(gg_x, gg_y, label=racing_line.label)

			radius = np.square(vel) / acc_l
			ax_radius.plot(t, radius, label=racing_line.label)

		ax_pos.set_xticks(np.arange(-track_width - radius_inner, exit_len + 1, 1))
		ax_pos.set_yticks(np.arange(-entrance_len, radius_inner + track_width + 1, 1))
		ax_pos.legend()

		for ax in [ax_pos, ax_gg]:
			ax.axis('equal')

		for ax in [ax_pos, ax_vel, ax_acc_l, ax_acc_f, ax_acc_t, ax_radius, ax_gg]:
			ax.grid()

		ax_radius.set_ylabel('Radius $(v^2/a_L)$')
		ax_vel.set_ylabel('Velocity')
		ax_acc_l.set_ylabel('Lateral acceleration')
		ax_acc_f.set_ylabel('Forward acceleration')
		ax_acc_t.set_ylabel('Total acceleration')

		ax_radius.set_xlabel('Time')
		# ax_vel.set_xlabel('Time')
		# ax_acc_l.set_xlabel('Time')
		# ax_acc_f.set_xlabel('Time')
		ax_acc_t.set_xlabel('Time')

		ax_gg.set_xlabel('Lateral g')
		ax_gg.set_ylabel('Forward g')

	plt.show()


if __name__ == "__main__":
	main()
