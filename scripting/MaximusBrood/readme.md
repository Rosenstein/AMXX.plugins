I maintained a CS server some time ago, and wrote custom plugins for it. Releasing those plugins into the public might be useful for others.

**I'm -not- offering support for these plugins**, I'm just dropping them here. If you want to maintain them yourself, please do so. Most plugins should work (they have worked for more than 1,5 years on my server), but be prepared to debug a little; they were never meant to be released.

playerHats - Like this plugin, but only allows certain users (specified in a sqlite/mysql database) to put on certain hats. Works great for rewarding donating players, etc. Tiny documentation here.

advancedMapchooser - Database-driven mapchooser. Holds a double mapvote: first, players choose out of four maps, then the two most chosen maps can be voted on again. Two other features: it gives maps a minimum and maximum player amount, to make the map fit to the amount of players in the server, and it records how many times a map has been played, making it more likely for less-played maps to appear in a vote.

crashRestoration - Can detect basic crashes, and will restore the crashed-upon map.

noRush - Prevents rushing in aim_ak-colt by disabling the rushing user's weapon ("You will fire blanks if you enter the other team's half of the map!"). After a certain amount of time (default: 120 seconds), the rush protection ends to prevent camping. Includes clear warning beforehand, nice visual effects and compatibility with War3:FT (moles).

trueChat - Allows dead people to see alive chat, cleanly, as if it was standard functionality. When I wrote this, all other plugins that offered the same functionality sucked; they didn't hook SayText, and added garbage to the chat messages. There might be a good version for this in the approved plugins section already, I don't know.

slashMe - /me functionality. Probably exists already, but I'll post it anyway. Probably conflicts with the CS1.6 stats plugin too, beware.
