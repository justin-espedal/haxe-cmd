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
	
	public static var dir = "";
	
	public static function cd(path:String)
	{
		if(path.isAbsolute())
			Sys.setCwd(dir = path);
		else
			Sys.setCwd(dir = '$dir/$path'.normalize());
		Sys.println("> cd " + dir);
	}
	
	static function escapeArgs(?args:Array<String>):Null<Array<String>>
	{
		if(args == null)
			return args;
		
		return args.map
		(
			function(arg)
			{
				if(arg.indexOf(" ") != -1)
					return '"$arg"';
				else
					return arg;
			}
		);
	}
	
	public static function cmd(command:String, ?args:Array<String>):Int
	{
		args = escapeArgs(args);
		Sys.println("> " + command + " " + (args != null ? args.join(" ") : ""));
		return Sys.command(command, args);
	}
	
	public static function readCmd(command:String, ?args:Array<String>):String
	{
		args = escapeArgs(args);
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
		
		var buffer = new BytesOutput();
		
		var waiting = true;
		while(waiting)
		{
			try
			{
				var current = process.stdout.readAll(1024);
				buffer.write(current);
				if (current.length == 0)
				{  
					waiting = false;
				}
			}
			catch (e:Eof)
			{
				waiting = false;
			}
		}
		
		process.close();
		
		var output = buffer.getBytes().toString();
		if (output == "")
		{
			var error = process.stderr.readAll().toString();
			if (error==null || error=="")
				error = 'error running $command ${args.join(" ")}';
			trace(error);
			
			return null;
		}
		
		Sys.println(output);
		
		return output;
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
	
	public static function bindCmd(command:String):Dynamic
	{
		var _command:Dynamic = cmd.bind(command, _);
		return Reflect.makeVarArgs(_command);
	}
	
	public static function bindReadCmd(command:String):Dynamic
	{
		var _command:Dynamic = readCmd.bind(command, _);
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
