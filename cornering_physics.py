#!/usr/bin/env python3

from dataclasses import dataclass
from math import sqrt, isclose
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
	time: np.ndarray | None = None
	position: np.ndarray | None = None
	velocity: np.ndarray | None = None
	acceleration: np.ndarray | None = None


"""
Coordinates:
				  ________________  __
				/                 |
			/                     |     track width
		/                _________| __
	/                /
  /               /                    inner radius
/              /     _|_            __
|             |       |
|             |                       lead in
|             |                     __
| track width | inner | lead out |
				radius
"""


def plot_corner(ax, *, track_width, lead_in, lead_out, radius_center):
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
	ax.add_patch(Rectangle((-track_width - radius_inner, -lead_in), track_width, lead_in, color='grey'))
	# Lead-out
	ax.add_patch(Rectangle((0, radius_inner), lead_out, track_width, color='grey'))


def calculate_racing_line(
		radius: float,
		start: tuple[float, float] | None = None,
		*,
		tick_size: float = DEFAULT_TICK_SIZE,
		grip: float = 1.0,
		label: str | None = None,
		) -> RacingLine:

	if radius <= 0:
		raise ValueError(f'{radius=}')

	if start is None:
		start = (-radius, 0)

	# Calculate velocity so that acceleration is independent of radius
	# a = v^2 / r
	# v = sqrt(a * r)
	accel_mag = grip
	velocity_mag = sqrt(accel_mag * radius)

	x, y = start

	vx = 0
	vy = velocity_mag

	pos_x = []
	pos_y = []
	vel_x = []
	vel_y = []
	acc_x = []
	acc_y = []

	while True:

		ax = accel_mag / velocity_mag * vy
		ay = accel_mag / velocity_mag * -vx

		this_accel_mag = np.sqrt(ax*ax + ay*ay)
		assert isclose(this_accel_mag, accel_mag, rel_tol=1e-3), f"{this_accel_mag=}, {accel_mag=}"  # FIXME

		pos_x.append(x)
		pos_y.append(y)
		vel_x.append(vx)
		vel_y.append(vy)
		acc_x.append(ax)
		acc_y.append(ay)

		if vy < 0:
			break

		vx += ax * tick_size
		vy += ay * tick_size
		x += vx * tick_size
		y += vy * tick_size

		this_vel_mag = np.sqrt(vx*vx + vy*vy)
		assert isclose(this_vel_mag, velocity_mag, rel_tol=1e-6), f"{this_vel_mag=}, {velocity_mag=}"
		vx *= (velocity_mag / this_vel_mag)
		vy *= (velocity_mag / this_vel_mag)

	assert len(pos_x) == len(pos_y) == len(vel_x) == len(vel_y) == len(acc_x) == len(acc_y)

	position = np.array(pos_x) + 1j * np.array(pos_y)
	velocity = np.array(vel_x) + 1j * np.array(vel_y)
	acceleration = np.array(acc_x) + 1j * np.array(acc_y)

	time = tick_size * np.arange(len(pos_x), dtype=position.dtype)

	return RacingLine(time=time, position=position, velocity=velocity, acceleration=acceleration, label=label)


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


def main():

	track_width = 2
	track_half_width = track_width / 2

	lead_in = 6
	lead_out = 6

	radius_center = 3
	radius_inner = radius_center - track_half_width
	radius_outer = radius_center + track_half_width

	# Racing lines

	racing_lines_constant_grip = [
		calculate_racing_line(radius_inner, label='Inner'),
		calculate_racing_line(radius_outer, label='Outer'),
		calculate_racing_line(radius_center, label='Center'),
		calculate_geometric_racing_line(
			track_width=track_width, radius_center=radius_center, label='Geometric'),
		# TODO: calculate compound radius (late apex)
	]

	racing_lines_varying_grip = [
		calculate_geometric_racing_line(
			track_width=track_width, radius_center=radius_center, grip=grip, label=f'Grip={grip:g}')
		for grip in [0.5, 0.75, 1, 1.5, 2]
	]

	for racing_lines, title in [
			(racing_lines_constant_grip, 'Racing lines, constant grip'),
			(racing_lines_varying_grip, 'Geometric line, varying Grip'),
			]:

		fig, axes = plt.subplots(nrows=2, ncols=2)
		fig.suptitle(title)

		ax_pos = axes[0, 0]
		ax_radius = axes[1, 0]
		ax_vel = axes[0, 1]
		ax_acc = axes[1, 1]

		plot_corner(
			ax_pos,
			track_width=track_width, lead_in=lead_in, lead_out=lead_out, radius_center=radius_center)

		for racing_line in racing_lines:
			t = racing_line.time
			x = np.real(racing_line.position)
			y = np.imag(racing_line.position)
			vel = np.abs(racing_line.velocity)
			acc = np.abs(racing_line.acceleration)
			ax_pos.plot(x, y, label=racing_line.label)
			ax_vel.plot(t, vel, label=racing_line.label)
			ax_acc.plot(t, acc, label=racing_line.label)

			radius = np.square(vel) / acc
			ax_radius.plot(t, radius, label=racing_line.label)

		ax_pos.set_xticks(np.arange(-track_width - radius_inner, lead_out + 1, 1))
		ax_pos.set_yticks(np.arange(-lead_in, radius_inner + track_width + 1, 1))

		ax_pos.axis('equal')
		ax_pos.legend()

		for ax in [ax_pos, ax_vel, ax_acc, ax_radius]:
			ax.grid()

		ax_radius.set_title('Radius')
		ax_vel.set_title('Velocity')
		ax_acc.set_title('Lateral acceleration')

		ax_acc.set_xlabel('Time')

	plt.show()


if __name__ == "__main__":
	main()
