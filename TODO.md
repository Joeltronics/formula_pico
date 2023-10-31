## Gameplay features

Race logic
* (Done) Count laps
* (Done) Start procedure
* Race end procedure
* Time laps

Tire management
1. Tires wear down
	- Wear varies with driving style - e.g. can save tires with lift & coast
	- Older tires slow down acceleration & corner top speed
	- Tire age probably won't affect braking distance - this would be much tricker to implement with current game logic
2. Soft/med/hard tires
	- Speed vs durability
	- Can select at pit stop
3. Select race tire strategy at start
	- Can override during pit stop

Pit stops
1. (Done) Add pit lane
2. (Done) Add capability to drive into pit lane
3. Change tires
4. Pit stop animation

Other cars:
* Add AI overtaking logic
* Pit stops & tire management for other cars as well
* Add AI defending logic?

Game modes
* Time trial
* Season mode

## Gameplay improvements

Improve steering/cornering logic

* Right now, logic does not line up with corner speeds, so there are some corners that you can't make
* Figure out direction on-track in real units (currently represented by abstract turn accumulator)
	- Will also need to change "tu" variable to be calculated based on actual geometry instead of just choosing a value that looked right
* When being pushed toward outside of turn, also affect on-track direction/turn accumulator
* Smarter dx/dz tradeoff logic
	- Essentially base it on GG diagram
	- Kind of already operates this way, but need to determine both together rather than one then other
	- Also needs on-track direction to be in real units to do this properly

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

## Graphics

Better car sprites & animations
* More car angles
* Improve car sprite
* Extra effects when braking, off track, etc

Show arrows for cars that are just off-screen

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
