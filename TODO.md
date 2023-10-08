## Gameplay features

Race logic
* (Done) Count laps
* (Done) Start procedure
* Race end procedure
* Time laps

Pit stops
1. Add pit lane
2. Add capability to drive into pit lane
3. Change tires
4. Pit stop animation

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

Other cars:
* Add AI overtaking logic
* Pit stops & tire management for other cars as well
* Add AI defending logic?

## Gameplay improvements

Improve steering/cornering logic
* Figure out direction on-track in real units (currently represented by abstract turn accumulator)
	- Will also need to change "tu" variable to be calculated based on actual geometry instead of just choosing a value that looked right
* When being pushed toward outside of turn, also affect on-track direciton/turn accumulator
* Smarter dx/dz tradeoff logic
	- Essentially base it on GG diagram
	- Kind of already operates this way, but need to determine both together rather than one then other
	- Also needs on-track direction to be in real units to do this properly

AI steering logic could stand to be improved
* It only takes into account whether it's left/right of the racing line, it doesn't account for the direction of the racing line or otherwise look ahead
* The simple logic means it often undershoots the racing line
* It would also overshoot it, but for now there's a hack to immediately reset the accumulator to prevent this
* "Push to outside of corners" logic does not currently apply to AI cars

Hitbox collision logic improvemnets
* Should deal with this at steering time - clipping should be last resort
* Gap in front varies with speed - this is because it's all based on the cars' current position, not where they will be after moving

## Graphics

Better car sprites & animations
* More car angles
* Improve car sprite
* Extra effects when braking, off track, etc

Backgrounds besides just blue sky

Better off-track sprites and other stuff

## Other

Improve start screen
* Add some art
* Preview car palette & track layout
* Tidy it up

More tracks

More sound improvements

Optimization
* Performance
* Token count
* Better data compression
