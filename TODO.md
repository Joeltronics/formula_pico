## Porting to Picotron

Port base logic

Improve graphics for larger screen

Pico-8 code was heavily optimized for tokens - there's a lot that could be done to improve the code for Picotron now that there's no token limit. Some code clean-ups, but also lots of potential logic changes, e.g. the use of globals & hard-coded numbers, as well as stuff like using 3D vectors instead of separate x/y/z vars

## Gameplay features

Race logic
* Race end procedure
* Time laps

Tires & pit stops:
* Add pit lane to remaining tracks
* Select starting tire compound
	- Possibly also preview strategy?
* Select tire compound at pit stop
* Have AI cars take pit stops
* Require 2 different tire compounds in race

AI:
* Add AI overtaking logic
	- Now that there are tire compounds & deg, this is especially important (since not all cars are same speed anymore)
* Add AI defending logic?

Game modes
* Time trial
* Season mode

## Gameplay improvements

Cornerning & physics improvements:

* Limit cornering grip based on acceleration
	- Essentially base it on GG diagram
	- Kind of already operates this way, but need to determine both together rather than one then other
* Improve "push outside of turn" logic
	- It was too strong before the new physics model
	- Now it's not strong enough

Hitbox collision logic improvements:

* Should deal with most parts at AI/assist time (auto steer/brake to prevent hitting other cars) - clipping should be last resort
* Still some issues from processing cars one by one:
	- Current logic does all processing for one car at a time - this means while a car is being processed, some cars have ticked forward and others haven't
	- We process cars in order of position on track to mitigate problems with this - this helps quite a bit, but doesn't solve everything (especially when two cars are very close in position)
	- Would be better to process all cars AI/assist logic, then tick all car positions, then clip all cars - potentially a lot more complicated, though
* Cars can still sometimes push other cars left/right
	- As a hack, we change hitbox sizes slightly to prioritize the car ahead, so that at least a car behind shouldn't be able to push a car ahead. This isn't ideal (e.g. a car cornering can push a car trying to pass on the inside), and it doesn't even seem to work quite 100%.
	- Possibly caused by one by one processing?

AI steering logic could stand to be improved:

* It only takes into account whether it's left/right of the racing line, it doesn't account for the direction of the racing line or otherwise look ahead
* The simple logic means it often undershoots the racing line, and/or weaves across it
* It would also overshoot it, but for now there's a hack to immediately reset the steering accumulator to prevent this
* "Push to outside of corners" logic does not currently apply to AI cars

Tire grip & wear
* Right now it only affects corner max speed
* Does not actually affect cornering physics
* Does not affect acceleration
* Does not affect braking distance

## Graphics

Better car sprites & animations
* More car angles
* Improve car sprite
* Extra effects when braking, off track, etc

Show arrows for cars that are just off-screen

Show warning of upcoming pit lane

Show warning of upcoming corners (when racing line disabled)

Fix pop-in issues with cars right behind (caused by rendering only starting at current segment)

Camera improvements
* Better X coordinate logic
* Look ahead, account for upcoming corners
* Improve behavior on steep downward hills

Backgrounds besides just blue sky

Better off-track sprites and other stuff

## Other

Tracks
* Add racing line data for remaining tracks
* Fine tune existing racing line data
* Better track data compression
* Store tracks across multiple cartridges
* Add a few more tracks
* Graphics details per track

Improve start screen
* Add some art
* Preview car palette & track layout
* Tidy it up

Sound improvements

Optimization
* Performance
* Token count
