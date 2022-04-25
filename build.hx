package;

import hxp.*;
import sys.io.File;
import sys.FileSystem;

class Build extends hxp.Script
{
	public function new()
	{
		super();

		var platform = "default";
		if (command == "rebuild") platform = commandArgs[0];
		else platform = command;

		if (platform == "default")
		{
			platform = System.hostPlatform;
		}

		if (platform != null)
		{
			rebuild(platform.toLowerCase());
		}
	}

	private function rebuild(platform:String):Void
	{
		var armv6 = flags.exists("armv5") || flags.exists("armv6");
		var armv7 = flags.exists("armv7");
		var armv7s = flags.exists("armv7s");
		var arm64 = flags.exists("arm64");
		var x86 = flags.exists("x86") || flags.exists("32");
		var x64 = flags.exists("x64") || flags.exists("64");
		var simulator = flags.exists("simulator");

		var defaults = !armv6 && !armv7 && !armv7s && !arm64 && !x86 && !x64;
		var commands = [];

		switch (platform)
		{
			case "android":
				if (armv6 || defaults) commands.push(["-Dandroid", "-DPLATFORM=android-21"]);
				if (armv7 || defaults) commands.push(["-Dandroid", "-DHXCPP_ARMV7", "-DHXCPP_ARM7", "-DPLATFORM=android-21"]);
				if (arm64 || defaults) commands.push(["-Dandroid", "-DHXCPP_ARM64", "-DPLATFORM=android-21"]);
				if (x86 || defaults) commands.push(["-Dandroid", "-DHXCPP_X86", "-DPLATFORM=android-21"]);
				if (x64 || defaults) commands.push(["-Dandroid", "-DHXCPP_X86_64", "-DPLATFORM=android-21"]);

			case "ios":
				if (armv6 && !simulator) commands.push(["-Dios", "-DHXCPP_CPP11"]);
				if (defaults || (armv7 && !simulator)) commands.push(["-Dios", "-DHXCPP_CPP11", "-DHXCPP_ARMV7"]);
				if (defaults || (armv7s && !simulator)) commands.push(["-Dios", "-DHXCPP_CPP11", "-DHXCPP_ARMV7S"]);
				if (defaults || (arm64 && !simulator)) commands.push(["-Dios", "-DHXCPP_CPP11", "-DHXCPP_ARM64"]);
				if (defaults || simulator || x86) commands.push(["-Dios", "-Dsimulator", "-DHXCPP_CPP11"]);
				if (defaults || simulator || x64) commands.push(["-Dios", "-Dsimulator", "-DHXCPP_M64", "-DHXCPP_CPP11"]);

				if (flags.exists("arc"))
				{
					for (command in commands)
					{
						command.push("-DOBJC_ARC");
					}
				}

				// IOSHelper.getIOSVersion(project);
				// var iphoneVer = project.environment.get("IPHONE_VER");

				// for (command in commands)
				// {
				// 	command.push("-DIPHONE_VER=" + iphoneVer);
				// }

			case "linux":
				if (flags.exists("rpi"))
				{
					commands.push([
						"-Dlinux",
						"-Drpi",
						"-Dtoolchain=linux",
						"-DBINDIR=RPi",
						"-DCXX=arm-linux-gnueabihf-g++",
						"-DHXCPP_M32",
						"-DHXCPP_STRIP=arm-linux-gnueabihf-strip",
						"-DHXCPP_AR=arm-linux-gnueabihf-ar",
						"-DHXCPP_RANLIB=arm-linux-gnueabihf-ranlib"
					]);
				}
				else if (flags.exists("hl") && System.hostArchitecture == X64)
				{
					// TODO: Support single binary
					commands.push(["-Dlinux", "-DHXCPP_M64", "-Dhashlink"]);
				}
				else
				{
					if (!flags.exists("32") && System.hostArchitecture == X64)
					{
						commands.push(["-Dlinux", "-DHXCPP_M64"]);
					}

					if (!flags.exists("64") && (command == "rebuild" || System.hostArchitecture == X86))
					{
						commands.push(["-Dlinux", "-DHXCPP_M32"]);
					}
				}

			case "mac", "macos":
				if (flags.exists("hl") && System.hostArchitecture == X64)
				{
					// TODO: Support single binary
					commands.push(["-Dmac", "-DHXCPP_CLANG", "-DHXCPP_M64", "-Dhashlink"]);
				}
				else
				{
					if (!flags.exists("32") && (command == "rebuild" || System.hostArchitecture == X64))
					{
						commands.push(["-Dmac", "-DHXCPP_CLANG", "-DHXCPP_M64"]);
					}

					if (!flags.exists("64") && (flags.exists("32") || System.hostArchitecture == X86))
					{
						commands.push(["-Dmac", "-DHXCPP_CLANG", "-DHXCPP_M32"]);
					}
				}

			case "tvos":
				if (defaults || (arm64 && !simulator)) commands.push([
					"-Dtvos",
					"-Dappletvos",
					"-DHXCPP_CPP11",
					"-DHXCPP_ARM64",
					"-DOBJC_ARC",
					"-DENABLE_BITCODE"
				]);
				if (defaults || x86 || simulator) commands.push([
					"-Dtvos",
					"-Dappletvsim",
					"-Dsimulator",
					"-DHXCPP_CPP11",
					"-DOBJC_ARC",
					"-DENABLE_BITCODE"
				]);
				if (defaults || x64 || simulator) commands.push([
					"-Dtvos",
					"-Dappletvsim",
					"-Dsimulator",
					"-DHXCPP_M64",
					"-DHXCPP_CPP11",
					"-DOBJC_ARC",
					"-DENABLE_BITCODE"
				]);

			case "windows":
				var winrt = flags.exists("winrt");
				var hl = flags.exists("hl");

				if (!x64 && (defaults || System.hostArchitecture == X86))
				{
					if (winrt)
					{
						commands.push(["-Dwinrt", "-DHXCPP_M32"]);
					}
					else if (hl)
					{
						// TODO: Support single binary
						commands.push(["-Dwindows", "-DHXCPP_M32", "-Dhashlink"]);
					}
					else
					{
						commands.push(["-Dwindows", "-DHXCPP_M32"]);
					}
				}

				// TODO: Compiling with -Dfulldebug overwrites the same "-debug.pdb"
				// as previous Windows builds. For now, force -64 to be done last
				// so that it can be debugged in a default "rebuild"

				if (!x86 && System.hostArchitecture == X64 && (!defaults || !hl) && !hl)
				{
					if (winrt)
					{
						commands.push(["-Dwinrt", "-DHXCPP_M64"]);
					}
					else
					{
						commands.push(["-Dwindows", "-DHXCPP_M64"]);
					}
				}

			default:
				Log.info("Unknown platform");
		}

		var path = "project";
		var buildFile = "Build.xml";

		var buildRelease = (!flags.exists("debug"));
		var buildDebug = (flags.exists("debug"));

		if (flags.exists("clean"))
		{
			if (buildRelease)
			{
				for (command in commands)
				{
					rebuildSingle(command.concat(["clean"]), path, buildFile);
				}
			}

			if (buildDebug)
			{
				for (command in commands)
				{
					rebuildSingle(command.concat(["-Ddebug", "-Dfulldebug", "clean"]), path, buildFile);
				}
			}
		}

		for (command in commands)
		{
			if (buildRelease)
			{
				rebuildSingle(command, path, buildFile);
			}

			if (buildDebug)
			{
				rebuildSingle(command.concat(["-Ddebug", "-Dfulldebug"]), path, buildFile);
			}
		}
	}

	private function rebuildSingle(command:Array<String> = null, path:String = null, buildFile:String = null):Void
		{
			if (path == null || !FileSystem.exists(path))
			{
				return;
			}

			if (buildFile == null) buildFile = "Build.xml";

			if (!FileSystem.exists(Path.combine(path, buildFile)))
			{
				return;
			}

			var args = ["run", "hxcpp", buildFile];

			if (command != null)
			{
				args = args.concat(command);
			}

			for (key in defines.keys())
			{
				var value = defines.get(key);

				if (value == null || value == "")
				{
					args.push("-D" + key);
				}
				else
				{
					args.push("-D" + key + "=" + value);
				}
			}

			if (flags.exists("static"))
			{
				args.push("-Dstatic_link");
			}

			if (Log.verbose)
			{
				args.push("-verbose");
			}

			if (!Log.enableColor)
			{
				// args.push ("-nocolor");
				Sys.putEnv("HXCPP_NO_COLOR", "");
			}

			if (System.hostPlatform == WINDOWS && !Sys.environment().exists("HXCPP_COMPILE_THREADS"))
			{
				var threads = 1;

				if (System.processorCores > 1)
				{
					threads = System.processorCores - 1;
				}

				Sys.putEnv("HXCPP_COMPILE_THREADS", Std.string(threads));
			}

			Sys.putEnv("HXCPP_EXIT_ON_ERROR", "");

			Haxelib.runCommand(path, args);
		}
}
