# Campfire Tales

Something to say around the fire.

Campfire Tales is an addon for **World of Warcraft: Forever**. Sit down at a campfire and, as the Welcoming Campfire buff starts counting down, a window opens full of things to say while you wait: greetings, small talk, jokes (clean and crude), riddles, short stories, tales of glory, spooky tales, songs, toasts and farewells. Click a button and your character says it.

Stories and jokes are told in parts. After each part, the next waits until everyone around the fire has had time to read it, with a beat before every punchline and a long pause before the ghost appears. The window shows the whole tale as you tell it, and counts down to the next part.

| Category | For example |
| --- | --- |
| Greetings | Well met, Grukk! Pull up a log, the fire's warm. |
| Small Talk | What's the strangest place you've ever pitched camp? |
| Jokes | How many gnomes does it take to light a campfire? ... Five. ... One to strike the flint, and four to build a machine that does it for them. ... It explodes. |
| Crude Jokes | Never let the dwarves eat beans the night before a siege. ... Oh, we won. ... But only because the enemy were downwind, and they surrendered. |
| Riddles | I eat wood but drink nothing. Give me water and I die. What am I? ... A fire! |
| Short Stories | The Stubborn Kodo, The Last Ember, The Fish That Got Away, Hogger's Day Off, and more |
| Tales of Glory | Three on the Bridge, The Night at Light's Hope, The Dragon at Dawn, The Fireworks Cart, and boasts: "I once fought off ten kobolds with one hand." |
| Spooky Tales | The Empty Bedroll, The Lantern in Duskwood, Don't Count the Sitters, and more |
| Songs | Song of the Road, The Dry Mug, Embers Low, Mrgl the Brave |
| Toasts | To the fire that keeps us warm, and the friends who keep it lit! |
| Fireside | *Brenna pokes the fire with a stick, sending sparks dancing into the dark.* |
| Farewells | The road calls. Safe travels, friends! |
| Your Own | Buttons you make yourself |

Playing an Orc with [Krump](https://github.com/Azrolicious/Krump), or a Troll with [Juju](https://github.com/Azrolicious/Juju)? Everything comes out in their accent, and you get Ork Yarns or Troll Tales and a button for each of their emotes as well. See [Krump and Juju](#krump-and-juju).

## Install

1. Download this repository as a ZIP and unpack it.
2. Make sure the folder is called exactly `CampfireTales` and has `CampfireTales.toc` directly inside it. (GitHub names the unpacked folder `Campfire-Tales-main` or similar. Rename it.)
3. Move the folder to `World of Warcraft/_forever_/Interface/AddOns/`.
4. Start the game, or type `/reload` if it is already running.

## Using it

Find a campfire, `/sit` down beside it, and the window opens. Type `/tales` to open it any other time.

Pick a category on the left, then click a button:

- **Actions** (poking the fire, passing food round) happen straight away, like the game's own emotes.
- **Words** go into your chat line, exactly as if you had typed them. Press Enter to say them. The game does not let addons speak out loud by themselves, so that last Enter is always yours. It also means you can change a line before it goes, or press Escape to keep it to yourself.

Point at a button to see exactly what everyone will see.

### Stories, jokes and riddles

The categories of tales (Jokes, Crude Jokes, Riddles, Short Stories, Tales of Glory, Spooky Tales, Songs, and Ork Yarns or Troll Tales) have a block of text under their buttons. Click a button and the whole tale is there to read, line by line, with its pauses marked. Press **Tell it** when you are ready.

```
 Gnome fire   4 lines, about 15 seconds                [Tell it]
  1  How many gnomes does it take to light a campfire?
         - pause, 2 seconds -
  2  Five.
  3  One to strike the flint, and four to build a machine that does it for them.
         - pause, 3 seconds -
  4  It explodes.
```

Each line goes into your chat line in turn: press Enter to say it. The next line then waits until everyone has had time to read the one you said, plus any pause written into the tale, and goes into the chat line by itself. So you tell a whole story by pressing Enter when each part appears. While you wait, the bottom of the window counts down ("punchline in 4", "answer in 12"), and the block of text greys out what you have said and lights the line coming up.

- **Jokes** get a beat before the punchline. Some are told in three or four parts, with a pause before each turn.
- **Riddles** give everyone about ten seconds to guess before the answer is ready.
- **Stories** and **Tales of Glory** pause at the big moments. **Spooky Tales** pause longest of all.
- **Say it now**, at the bottom of the window, skips the wait.
- **Click any line** in the block of text to tell the tale from there: to skip ahead, or say a line again.
- How long a line waits for readers is up to you: **Time to read between lines** in the settings (Quick, Steady, Slow or No waiting).

| To do this | Do this |
| --- | --- |
| Greet someone by name | Target them first. Without a target, lines say "friends", "everyone" or similar instead |
| Read a tale before telling it | Click its button. It shows in the block of text underneath |
| Tell it | **Tell it**, on the block of text. **Start over** starts it again from the top |
| Get to the punchline sooner | **Say it now** at the bottom of the window, while it counts down |
| Tell it from a line part way through | Click that line in the block of text |
| Pause a story | Press Escape on the chat line |
| Carry on | **Next line** at the bottom of the window, `/tales next`, or a key under Key Bindings > AddOns |
| Stop a story | **Stop** at the bottom of the window, or `/tales stop` |
| Answer someone in the middle of a story | Just open the chat line and type. The next line waits until you have sent yours |
| Say something at random | **Surprise me**, at the top of each category, or `/tales random crude` (handy in a macro). It starts straight away |
| Open the window | `/tales`, `/tales jokes` to open on a category, or set a key under Key Bindings > AddOns |
| Make your own buttons | The **Your Own** category, at the bottom of the list |
| Open the settings | `/tales config`, or right-click Campfire Tales in the minimap addon menu |
| List the chat commands | `/tales help` |

Clicking an action in the middle of a story does the action and the story carries on. Telling something else starts that instead. You can click other tales to read them while one is being told: the one being told carries on.

## The fire

Sitting down by a campfire in Forever gives you **Welcoming Campfire**, a buff that counts down for a minute. When it runs out you get **Camp Benefits**: every buff from the things put in the fire.

While the window is open, the strip at the top keeps track:

| You are | The window says |
| --- | --- |
| Sitting down, waiting | Warming up by the fire: camp benefits in 0:42 |
| Done waiting | Camp benefits: 29:12 left |
| Away from a fire | Sit down by a campfire to warm up. |

The window opens once each time you sit down. If you close it, it stays closed until you stand up and sit down again, or type `/tales`. Logging in or reloading by a fire does not open it. To stop it opening by itself, untick **Open when I sit at a campfire** in the settings, or type `/tales auto off`.

## Krump and Juju

[Krump](https://github.com/Azrolicious/Krump) and [Juju](https://github.com/Azrolicious/Juju) turn what you type into Ork and troll speech before it is sent. Campfire Tales puts its lines in the chat line, so they come out in the accent with nothing more to do. Krump's or Juju's preview above the chat line shows you how before you press Enter.

| You click | An Orc with Krump says |
| --- | --- |
| Well met | Well met, matez! Pull up a log, da fire'z warm. |
| Hearthstone | Me an' me hearthstone 'ave a lot in common. |
| Nod off | *nods off, then jerks awake. "I'z awake! I'z awake."* |
| Orc table manners | Ork table mannaz, in free easy stepz. ... Wun: eat. ... Two: belch. ... Free: punch 'ooeva complained 'bout step two. |

While one of them is talking on the character, the window also has:

- **Ork Yarns** or **Troll Tales**: stories, jokes and toasts written for an Ork or a troll at the fire. Try "The Ogre Headbutt" or "The Dancing Raptor".
- **Krump Emotes** or **Juju Emotes**: a button for each of their emotes (`/waaagh`, `/headbutt`, `/voodoo`, `/hex` and the rest), and for any emotes you made yourself in Krump or Juju. They are worded for your character's voice and aimed at your target if you have one.
- A line at the top right saying who is talking. Click it to open the Krump or Juju box.

An action with spoken words in it (`nods off. "I'm awake!"`) normally happens as soon as you click it. While Krump or Juju is talking, it goes into the chat line instead, so they can say the words their way.

Nothing needs setting up. Campfire Tales asks the two of them who is talking on each character, using their own rule (the one made for the character's race wins), so `/krump on` and `/juju on` change it straight away. To hide the extra categories, untick **Krump and Juju categories** in the settings. Lines still come out in the accent either way.

## Your own buttons

The **Your Own** category, at the bottom of the list, makes buttons of your own. Give the button a name, type what to say, and press **Save button**:

| Button name | What to say | What happens |
| --- | --- | --- |
| Bad pun | Why did the gnome cross the road? // To get to the other side. Of the explosion. | Two lines, told one at a time |
| Bow | /e bows to {target:everyone}. | An action, done straight away |
| Grukk's tale | Did I ever tell you about Grukk? // ... | A story, up to 12 lines |

- Start a line with `/e` for an action, or `/y` to yell it.
- Put `//` between lines to make a story. Each line waits for everyone to read the one before, the same as Campfire Tales' own.
- A line of just `/wait 5` is a pause of 5 seconds, on top: `Knock knock. // /wait 5 // Who's there?`
- These are filled in when the line is said:

| Write | Becomes |
| --- | --- |
| `{target}` | Your target's name, or "friend" without one |
| `{target:everyone}` | Your target's name, or the word after the colon |
| `{me}` | Your character's name |
| `{zone}` | Where you are: the subzone, such as Razor Hill, or else the zone |
| `{time}` | Morning, afternoon or evening, by the game's clock |
| `{his}` `{him}` `{he}` | Her and she for a female character |

Right-click one of your buttons to change it, or type its name and press **Remove**. You can keep up to 30, and they work on every character.

## Settings

Under Options > AddOns > Campfire Tales:

- **Open when I sit at a campfire.** On to begin with.
- **Time to read between lines.** How long the next line of a tale waits after you say one: Quick, Steady (to begin with), Slow, or No waiting, for a second between lines and no pauses. Pauses written into a tale come on top of Quick, Steady and Slow.
- **Do actions straight away.** Switch it off to have actions go into the chat line too, so you can change them before pressing Enter.
- **Krump and Juju categories.** Ork Yarns, Troll Tales and the emote buttons, while Krump or Juju is talking.

## Key bindings

Under Key Bindings > AddOns > Campfire Tales:

- **Open or close Campfire Tales.**
- **Put the next line of a story in the chat line.** For carrying on after you pressed Escape, or saying the next line without waiting.

## Chat commands

| Command | What it does |
| --- | --- |
| `/tales` | Open or close the window (`/campfiretales` works too) |
| `/tales jokes` | Open it on a category: greetings, talk, jokes, crude, riddles, stories, glory, spooky, songs, toasts, fireside, farewells, mine |
| `/tales random jokes` | Say something from a category at random |
| `/tales next` | Put the next line of a story in the chat line, without waiting |
| `/tales stop` | Stop telling the story |
| `/tales auto on` or `off` | Open the window when you sit at a campfire |
| `/tales config` | Open the settings |
| `/tales help` | List the commands |

## Changing the words

Everything Campfire Tales says is in `Tales.lua`, as plain lists:

```lua
{ "Hearthstone", "Me and my hearthstone have a lot in common.",
	"Neither of us will go anywhere until we've had an hour to cool down." },
```

The first text is the button's label and each one after it is a line. A line of `"/wait 3"` between two lines is a 3-second pause, and a category can give every button a pause before its last line (`beat = 2`, which is how the jokes get theirs). Add a button, save, and `/reload`. The top of the file explains the rest. Keep lines under about 180 letters: Krump and Juju make lines longer when they put them in their accent, and a line that grows too long for chat is sent as you typed it.

The buff names Campfire Tales looks for are at the top of `Fire.lua`, in case Blizzard renames them.

## Tests

Campfire Tales can be tested with a plain Lua 5.1:

```
lua5.1 tests/run.lua
```

This loads the addon into a stand-in game client, sits down at a campfire, clicks buttons and presses Enter. If Krump or Juju is in the folder next to Campfire Tales (as it is in the AddOns folder), they are loaded too, to check that campfire lines come out in Ork and troll. Set `KRUMP_DIR` or `JUJU_DIR` to their folders if they are somewhere else.

## Notes

Campfire Tales puts lines in the chat line with `ChatFrameUtil.OpenChat`, the same as shift-clicking a name, and watches the `ChatFrame.OnEditBoxPreSendText` event to know when one has been said. It never changes what you send. Actions are sent with `C_ChatInfo.SendChatMessage` as emotes, like Krump's and Juju's. Nothing of the game's own is replaced.

Every story, joke and song is original to Campfire Tales. The riddles are old folk riddles, retold.

This is a fan-made addon. It is not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment.
