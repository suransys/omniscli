# omniscli
OmnisCLI adds a command-line interface to [Omnis Studio](http://www.omnis.net).

## Use Cases
 * Integrating Omnis applications in a continuous integration project using Jenkins
 * Using Omnis database schema migration tools to deploy updates via SSH or an orchestration tool (RunDeck, SaltStack, Chef, Ansible, Puppet)
 * Automating testing upgrades of different database versions using Omnis database schema migraton tools 
 * Launching Omnis application servers and monitoring their output using Nagios

## Features
 * Access command-line arguments from Omnis code
 * Write to stdout and stderr using Omnis code, including ANSI color escapes
 * Exit Omnis and set the exit status to be returned to the shell

## Standard commands:

Command | Description
------- | -----------
help | Displays available commands
omnis_version | Returns the Omnis Runtime version

## Requirements
 * Omnis Studio 8.0.x
 * macOS 10.9+ (tested with bash shell)
 * Windows 7+ (requires Powershell)

## Sample Output
```bash
$ /Applications/CDM+.app/Contents/MacOS/bin/omniscli help
         build   Outputs the build number
      gettests   Returns a list of OmnisTAP tests. Usage: gettests [test regex (optional)]
          help   Output details about available commands and exits
 omnis_version   Returns the Omnis version
    reorganize   Reorganize a database [database] [hostname | defaults to localhost}
      runtests   Runs OmnisTAP. Usage: runtests [path to tap output directory] [database] [hostname] [test regex (optional)]
        update   Updates a database to the current program version [database] [hostname | defaults to 127.0.0.1]
update_cluster   Updates the cluster to the current version [database] [hostname | defaults to 127.0.0.1]
       version   Outputs the version
```

## Installation
Clone this repository to a working directory:
```
git clone https://github.com/suransys/omniscli.git
```
### macOS
Copy these files to your Omnis Studio runtime distribution:

Repository Root | Runtime Root
--------------- | ------------
bin/omniscli | /Applications/Your Omnis Runtime.app/Contents/MacOS/bin/omniscli
lib/[your omnis version]/omniscli.lbs | /Applications/Your Omnis Runtime.app/Contents/MacOS/startup/omniscli.lbs

Create this directory:
```
/Applications/Your Omnis Runtime.app/Contents/MacOS/run
```

The `omniscli` script needs execute permissions:
```bash
$ chmod +x "/Applications/Your Omnis Runtime.app/Contents/MacOS/bin/omniscli"
```

The `run` directory needs write access by the user running Omnis:
```bash
$ chmod +w "/Applications/Your Omnis Runtime.app/Contents/MacOS/run"
```

The `omniscli` script also assumes your Omnis executable is named `Omnis`. You will need to customize the script if you've renamed the internal Omnis executable. The top of `omniscli` has a variable for this purpose:
```bash
# Customize this variable
lcOmnisExecutableName="Omnis"
# End customization
```

### Windows
Copy these files to your Omnis Studio runtime distribution:

Repository Root | Runtime Root
--------------- | ------------
bin/omniscli.ps1 | %PROGRAMFILES%\Your Company\Your Omnis Runtime\bin\omniscli.ps1
startup/omniscli.ps1 | %PROGRAMFILES%\Your Company\Your Omnis Runtime\firstruninstall\startup\omniscli.lbs

Create this directory:
```
%PROGRAMFILES%\Your Company\Your Omnis Runtime\firstruninstall\run
```

You will need to customize the `omniscli.ps1` script to indicate the parent folder for your working files in `%LOCALAPPDATA%`. If you've customized String table 32, position 499 in your `[app]dat.dll` file, this will control the directory when Omnis copies `firstruninstall` to `%LOCALAPPDATA%`. The top of the `omniscli.ps1` script has a variable for this purpose:
```powershell
# Customize this variable
${localappdata_company_directory} = "Suran"
# End customization
```

## Usage
### macOS
```bash
$ "/Applications/Your Omnis Runtime.app/Contents/MacOS/bin/omniscli" [command] [arg1] [arg2]
```

### Windows
Windows requires an additional argument before the command, which is the path to the Omnis executable. This technically means you can place the `omniscli.ps1` script in another location, but using a `bin` directory in the application root keeps your deployment consistent with this project and any macOS deployments.

#### Powershell.exe
```powershell
PS > & "${env:PROGRAMFILES}\Your Company\Your Omnis Runtime\bin\omniscli.ps1" "${env:PROGRAMFILES}\Your Company\Your Omnis Runtime\Your Omnis App.exe" [command] [arg1] [arg2]
```

#### cmd.exe
```batch
C:\> powershell.exe -Command "& "${env:PROGRAMFILES}\Your Company\Your Omnis Runtime\bin\omniscli.ps1" "${env:PROGRAMFILES}\Your Company\Your Omnis Runtime\Your Omnis App.exe" [command] [arg1] [arg2]"
```

### Quoting arguments
Wrap arguments with spaces in them with single quotes.

## Integration
There are two steps to integrating OmnisCLI into your app. First, you need to sub-class `omniscli.oOmnisCLI` and add methods for your commands. Second, you need to instantiate your OmnisCLI object and process any command line input. This is usually performed during your default task's `$construct`.

### Adding methods
 1. Open `omniscli.lbs`
 1. Create an object class in your library. Its name doesn't matter
 1. Set the object to sub-class `omniscli.oOmnisCLI`
 1. Add method for each command you want to expose on the command-line. Use the name `$cli_[command]`
 1. Add a description for the method. This will appear in the output for the `help` command

You can subclass your own subclass of `omniscli.oOmnisCLI` if that helps your application design. OmnisCLI will recognize any command on the current instance's class or any of its superclasses.

### Coding command methods
In the command method you can perform any Omnis code you'd like and invoke any existing part of your application. Omnis still runs in a full windowed environment allowing you to instantiate windows, menus, report classes, and so on. Avoid using any commands like `Enter Data` that block the program execution until a user interacts with the GUI. Avoid calling `Clear Method Stack` or `Quit all methods`, which are poor coding practices in any event.

#### Accessing arguments
Use the inherited `$getCLIArgument(piArgument)` method to get the arguments from the command line. Please note the command will be argument 1, and the remaining arguments will be numbered starting at 2. 

For example, running this command:
```bash
omniscli say_hello 'first name' 'last name'
```
With this `$cli_say_hello` method:
```
Calculate lcName as con($cinst.$getCLIArgument(2)," ",$cinst.$getClIArgument(3)
```
Will set the `lcName` variable to "first name last name".

#### Writing to stdout and stderr
Use the inherited `$writeStdout(pcMessage)` and `$writeStderr(pcMessage)` methods to send output to stdout and stderr, respectively. You can send any text to stdout and stderr. OmnisCLI uses ANSI Latin character encoding to avoid sending a unicode BOM to the command line.

OmnisCLI includes a number of colors escapes. Once a color escape is inserted into a string, the string will remain that color until the reset escape is included. For example:
```
Do $cinst.$writeStdout(con("The current date is ",$cinst.$kGreen(),#D,$cinst.$kReset()," according to Omnis."))
```
Will produce a message with the current date in green. See the `omniscli.oOmnisCLI` class for a list of full colors.

#### Returning an exit status
Your method should return an exit status when it's finished. Use `Quit method 0` to indicate success, or return another value to indicate a non-successful result.

#### Quitting Omnis
By default, OmnisCLI will quit Omnis when your command-line method finishes. If you want to keep Omnis running, exit your method with:
```
Quit method $cinst.$kOmnisCLIKeepOmnisOpen()
```

OmnisCLI can also return two other special statuses.

Exit Status | Meaning | Default Value
----------- | ------- | -------------
`$kOmnisCLICommandNotFound` | OmnisCLI detected a command but couldn't find it any the current object's class or any of its superclasses | -998
`$kOmnisCLINoCommand` | OmnisCLI was asked to process a command, but it couldn't detect the command | -997

If any of these default value conflicts with an exit status you want to use in your own code, simply overwrite these methods and return a different value.

### Processing OmnisCLI commands during startup
Once you've created an object class with your commands, you need to instantiate that object and let it process the command passes to OmnisCLI from the command line, if there is one. A good place to process CLI commands is in your library's default task's $construct. Here is some sample code you can adapt:
```omnis
Do $objects.oCLI.$newref() Returns lorCLI
If lorCLI.$isRunningFromCLI()=kTrue
	Do lorCLI.$processCLICommand()
	Quit method 
End If
Do lorCLI.$deleteref()
```

## How it works
OmnisCLI uses a wrapper script to launch Omnis, passing in command-line arguments, then watches output files for stdout, stderr, and exit status values.

The wrapper script passes arguments to Omnis using the `OMNISCLI_ARGUMENTS` environment variable. The `oOmnisCLI` object the parses this variable into arguments. If the first argument is found, OmnisCLI searches for a corresponding `$cli_[command]` method and calls it. Assuming the command doesn't return `$kOmnisCLIKeepOmnisOpen` Omnis is then terminated.

When Omnis writes to stdout and stderr, the output is sent to the `stdout.txt` and `stderr.txt` files in the run directory. The wrapper script watches these files and streams their output to the regular stdout and stderr descriptors.

When Omnis quits, the wrapper script reads the `exitstatus.txt` file and returns its contents as the exit status. Killing the wrapper script will also terminate Omnis, which is handy for aborting stuck jobs during continuous integration.

On macOS Omnis likes to send some extra chatter to stdout. The wrapper script handles this. Omnis can also fail to launch on the first go, so the wrapper script will try to launch Omnis up to 3 times.

## Tests
Once our unit-testing framework, OmnisTAP, is open-sourced and available on GitHub we'll make the unit tests for OmnisCLI available as well.

## Contributing
Please see our [guide to contributing](https://github.com/suransys/contributing).

## TODO
 * Open-source OmnisTAP so we can add the unit tests
 * Add a command-line integration test suite, perhaps using [bats](https://github.com/sstephenson/bats) on macOS and [Pester](https://github.com/pester/Pester) on Windows