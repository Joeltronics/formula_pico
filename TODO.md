## Gameplay

Improve steering/cornering logic
* See comments in the code

Improve racing line & max speed calculation
* Do it in the Python data generation script

Add walls

Race logic
* Count laps
* Time laps
* Start procedure

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

Add other cars
1. (Done) Just draw & keep track of them
	- Have them always follow center of track
	- No clipping yet
2. (Done) Draw them on minimap
3. (Done) Keep track of their rank and display it
4. Have them follow racing line
5. Add hitboxes/clipping
6. Add AI & overtaking logic
7. Pit stops & tire management for other cars as well

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
* Select mode (practice, race, season, etc)

More tracks

More sound improvements

Optimization
* Performance
* Token count
