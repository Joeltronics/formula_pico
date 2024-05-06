# Formula Pico

A racing game for [PICO-8](https://www.lexaloffle.com/pico-8.php) & [Picotron](https://www.lexaloffle.com/picotron.php)

Licensed CC BY-NC-SA 4.0

Partially based on [Creating a pseudo 3D racer](https://www.lexaloffle.com/bbs/?tid=35868) by Mot, licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## Status

See [TODO](TODO.md) for an overview of the big-picture stuff

## How to run

The PICO-8 version uses Jinja templates as a preprocessor (inspired by [this](https://blog.giovanh.com/blog/2022/12/11/jinja2-as-a-pico-8-preprocessor/)).
Run make.py to build, then run formula_pico.p8 as usual.

## Design & Feel

The goal is to capture the spirit of racing, but still feel like a retro driving game.

A realistic sim racing game is very different from arcade-y driving games - you need to be extremely precise, and any slight mistake can be very punishing. Not to mention you need to use the brakes all the time. But then, many retro driving games end up essentially boiling down to just being about dodging traffic. So the goal is to have some sort of tradeoff.

One element of real racing that's rarely captured by retro racing games is strategy. Not that there isn't any strategy in these - but there's no tire degradation, and overtaking is nothing like real racing. So this is one of the main elements this game hopes to capture. (In fact, one of the early ideas was to make strategy be the _only_ element of gameplay - driving along the racing line would happen automatically, and the player's only controls would be to deviate from this. But this wouldn't really make for a proper racing game.) Also, just like real racing, tire degradation also means the cars aren't all exactly the same speed, which makes the game more interesting.

At the moment, not everything is implemented, and none of it is tuned very well, so it doesn't really feel like this yet. And we'll see what's possible within the limitations of PICO-8, since this game is already fighting the token limit. But this is the goal, at least.
