package cmd;

import haxe.io.BytesOutput;
import haxe.io.Eof;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using Lambda;
using StringTools;
using haxe.io.Path;

class Cmd
{
	/*-------------------------------------*\
	 * CMD interface
	\*-------------------------------------*/ 
	
	public static var quiet = false;
	public static var dir = "";
	
	public static function cd(path:String)
	{
		if(path.isAbsolute())
			Sys.setCwd(dir = path);
		else
			Sys.setCwd(dir = '$dir/$path'.normalize());
		if(!quiet)
			Sys.println("> cd " + escapeArg(dir));
	}
	
	static function escapeArgs(?args:Array<String>, ?isNekoCmd:Bool = false):Null<Array<String>>
	{
		if(args == null)
			return args;
		
		var _escapeArg = escapeArg.bind(_, isNekoCmd);
		return args.map(_escapeArg);
	}
	
	static function escapeArg(arg:String, ?isNekoCmd:Bool):String
	{
		return (arg.indexOf(" ") != -1) ? (isNekoCmd ? '\'"$arg"\'' : '"$arg"') : arg;
	}
	
	public static function cmd(command:String, ?isNekoCmd:Bool = false, ?args:Array<String>):CmdOutput
	{
		args = escapeArgs(args, isNekoCmd);
		if(!quiet)
			Sys.println("> " + command + " " + (args != null ? args.join(" ") : ""));
		
		var process:Process = null;
		try
		{
			process = new Process(command, args);
		}
		catch(e:Dynamic)
		{
			trace(e);
			return null;
		}
		
		var exitCode = process.exitCode();
		var output = process.stdout.readAll().toString();
		process.close();
		
		if (exitCode != 0)
		{
			Sys.println(output);
			var error = process.stderr.readAll().toString();
			if (error == null || error == "")
				error = 'error running $command ${args.join(" ")} - exit code $exitCode';
			trace(error);
			
			return null;
		}
		
		if(!quiet)
			Sys.println(output);
		
		return {"exitCode": exitCode, "output": output};
	}
	
	public static function loopFolders():Array<String>
	{
		return
			FileSystem.readDirectory(dir)
			.filter
			(
				function(path)
				{ return FileSystem.isDirectory(path); }
			);
	}
	
	public static function exists(path:String):Bool
	{
		return FileSystem.exists('$dir/$path');
	}
	
	public static function bindCmd(command:String, ?isNekoCmd:Bool = false):Dynamic
	{
		var _command:Dynamic = cmd.bind(command, isNekoCmd, _);
		return Reflect.makeVarArgs(_command);
	}
	
	/*-------------------------------------*\
	 * Command Processing
	\*-------------------------------------*/ 
	
	public static function processSwitches(args:Array<String>, flags:Array<String>):Map<String,String>
	{
		var switches = new Map<String, String>();
		var key:String = null;
		
		for(arg in args)
		{
			if(key == null && arg.charAt(0) == "-")
			{
				key = arg.substring(1);
				
				if(flags.has(key))
				{
					switches.set(key, "1");
					key = null;
				}
			}
			else if(key != null)
			{
				switches.set(key, arg);
				key = null;
			}
		}
		
		return switches;
	}
	
	public static function getArgs():Array<String>
	{
		var argString = Sys.args().join(" ");
		var isString = false;
		var stringStart = -1;
		var args = [];
		
		for(i in 0...argString.length)
		{
			if(argString.charAt(i) == "\"")
			{
				if(!isString)
					stringStart = i;
				else
				{
					args.push(argString.substring(stringStart + 1, i));
					stringStart = i;
				}
				
				isString = !isString;	
			}
			if(isString)
				continue;
			
			if(argString.charAt(i) == " ")
			{
				if(stringStart != i - 1)
					args.push(argString.substring(stringStart + 1, i));
				stringStart = i;
			}
		}
		if(stringStart < argString.length - 1)
			args.push(argString.substring(stringStart + 1));
		
		
		return args;
	}
}

typedef CmdOutput =
{
	var exitCode:Int;
	var output:String;
}
