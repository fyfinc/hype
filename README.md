# Hype
A php linter, formatter, documenter, and unit tester program.

# Dependencies
* [phan](https://github.com/phan/phan) for static analysis.
* [prettier](https://github.com/prettier/plugin-php) for auto formatting.
* [phrocco](https://github.com/rossriley/phrocco) for documenting.
* **pest**: I will write a small unit testing library that just uses PHP 7 assertions. However, any php file can be run as a unit test.

# Synopsis
The hype.sh program has two modes: install (`-i` option) mode and run mode (`-npdtr` options). Run mode can be on a manual per php file basis or you can add a repo name and path map to `~/.hype/config.sh` and add `@docpath` and `@testpath` comment directives to given files and then stage them and then run `hype.sh -r my-repo` to run hype over your staged php files.

Right now config.sh is blank but soon it will be coded so that you just enter repo names and their paths in parallel bash arrays and that's all you have to do to use the `-r` option. The `-r` option is much easier than manual mode, so it will be welcomed when it's done soon.

Unit test result output is either saved, showed, or deleted to files in the hype project folder as hype.sh prompts you for each unit test. This is so that you can have time to read the results clearly rather than all your tests just spitting out text to the terminal.

I can't speak for prettier as of now, but phrocco and phan are great tools that I hope we all become acquainted and grow to love. `pest` might be a threaded library since unit tests can take time to setup and run, in which case we would need to install the pthreads extension.
