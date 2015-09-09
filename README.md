Roombex
=======

Roombex is an attempt to write a library for controlling the roomba via their serial interface. I'm not aiming for a completle implementation of the interface but rather enough to navigate and get feed back from the bot. It should be fairly easy to add commands, so if someone is interested in completely implementing the sci spec send a pull request.

The app is primarily written in Elxir with a small c program for talking to the serial port, which elixir interacts with via a port. The inspiration for this port was [this post](http://spin.atomicobject.com/2015/03/16/elixir-native-interoperability-ports-vs-nifs/).

I have run this on both ubuntu and arch, I run arch primarily but used ubuntu a little with the cloud nine ide. It compiles in both and runs, but can't speak to other OSs. This primarily designed to to run on raspberry pi, but there is no reason at the moment why it can't be run from a laptop with a some serial device to communicate with the roomba. My goal was to have it self contained on the roomba in a small form factor and the raspberry pi 2 seems to be plenty for now to run it.

Building
========

Note: The rust port is cross compilled following the instructions [here](https://github.com/Ogeon/rust-on-raspberry-pi). The make file assume cross64 script is in the path. I cross compile using an ubuntu image. Also note that debug statements may look a bit different than listed below, but that's all that should be different.

If you are running locally I recommend using socat or some serial emulator if you want to test it so I run the following from the command line before running the app:

```shell
socat -d -d pty,raw,echo=0 pty,raw,echo=0 &                                                                             

[1] 14132
2015/05/28 21:13:05 socat[14132] N PTY is /dev/pts/1                                                                                                                      
2015/05/28 21:13:05 socat[14132] N PTY is /dev/pts/2
2015/05/28 21:13:05 socat[14132] N starting data transfer loop with FDs [5,5] and [7,7]
```

and you can see below the output of the command. it sets up a pair of virtual devices /dev/pts/1 and /dev/pts/2 and I typically issue the command to run in the back ground as it needs to stay running. Please look up socat for more information.

I typically will then launch a terminal and launch `minicom -D /dev/pts/2` where in this case (your ports may differ) /dev/pts/2 is the one I want to monitor to view the output of the Roombex program. Then in another terminal run Roombex. Minicom is a serial monitor commonly used on linux possibly mac too but please look it up.

The device name for Roombex to use can be configured in the mix file like so (please look at mix file for more detail)

```
def application do
  [applications: [:logger],
   # first item in list is the device name
   # second is the baudrate
   mod: {Roombex, ["/dev/pts/1", "115200"]}]
end
```

Roombex has mix tasks to compile the c port which runs a makefile, admittedly makefiles are not my strong point and while this should work in ubtuntu and arch please note the point of failure will most likely be the block below in the makefile

```
ERL_ROOT = /usr/lib/erlang/usr
```

it makes an assumption that the erl_interface headers used in the c port live are under that directory (see make file). 

Assuming all is good there, once you clone the repo and configure your device name all that one should need to do is run

```
iex -S mix
... (ommited compiler output)

20:47:02.113 [debug] created port
20:47:02.114 [debug] received - ok
```

an elixir shell is now running, and you should see two debug messages indicating the port was created and the port sent back an ok to indicate that it was able to open the device specified.

How to use
========
The main module to use is the Roombex.Pilot module which has a do_commands function. This function takes a list of commands which take the form of an `atom` for simple commands and `struct` for more complex ones. I'm currently working on sensor commands to get sensor data back from the roomba.

Currently the commands supported are (based on the SCI, the older commands):
```
:start -- must be issued to start talking to the roomba
:control_mode -- must be issued to take control of the roomba
:safe_mode -- puts roomba in safe mode, can be controlled but stops if safety sensors are triggered (i.e cliff sensor)
:full_mode -- puts roomba in full mode, completel control not safety sensors are checked
:power -- turns of roomba
%Drive{speed: [value], angle: [value]} -- drive roomba, speed can be between +/- 500, angle can be between +/- 2000
                                          or one of these three atoms: :straight, :clockwise, :counter_clockwise which
                                          are used to make it more readable than the raw values
%Sleep{val: [value]} -- used internally to provide a delay between commands in the list value is in ms
```

So lets say one wants move the roomba forward at max speed for 5 seconds, turn clockwise in place for one second and back up for a second and stop. You know, cause why not...

```elixir
iex -S mix 
20:47:02.113 [debug] created port
20:47:02.114 [debug] received - ok

iex(1)> Roombex.Pilot.do_commands [:start, :control_mode, :safe_mode] # only need to run once when you start the app
21:55:00.124 [debug] sending command :start
21:55:00.124 [debug] sending command :control_mode
21:55:00.125 [debug] sending command :safe_mode
21:55:00.128 [debug] received - ok
21:55:00.129 [debug] received - ok
21:55:00.132 [debug] received - ok

iex(2)> Roombex.Pilot.do_commands [%Drive{speed: 500, angle: :straight}, %Sleep{val: 5000}, %Drive{speed: 500, angle: :clockwise}, %Sleep{val: 1000}, %Drive{speed: -500, angle: :straight}, %Sleep{val: 1000}, %Drive{speed: 0, angle: :straight}]
21:55:44.398 [debug] sending command %Drive{angle: :straight, speed: 500}
21:55:44.398 [debug] sleeping for 5000
21:55:44.400 [debug] received - ok
21:55:49.445 [debug] sending command %Drive{angle: :clockwise, speed: 500}
21:55:49.445 [debug] sleeping for 1000
21:55:49.447 [debug] received - ok
21:55:50.469 [debug] sending command %Drive{angle: :straight, speed: -500}
21:55:50.469 [debug] sleeping for 1000
21:55:50.475 [debug] received - ok
21:55:51.498 [debug] sending command %Drive{angle: :straight, speed: 0}
21:55:51.500 [debug] received - ok
```

the debug statements show you what is being sent to the roomba, and the reply from the c port which is handling it, basically if no issues with writing occured you get an ok message back from the port saying it was able to send the command to the roomba.

Also not that when a sleep is encountered you can visually see the puase in how long it takes for the next debug message for the next command.

I have still got a lot to do, but it is at a point where basic commands can be issued. I'll continue to update this document as I make progress.
