# shutils
shell utils scripts

[![Build Status](https://travis-ci.org/wantee/shutils.svg)](https://travis-ci.org/wantee/shutils)
[![License](http://img.shields.io/:license-mit-blue.svg)](https://github.com/wantee/shutils/blob/master/LICENSE.txt)

## Usage
``` shell
$ git clone https://github.com/wantee/shutils.git
$ source shutils/shutils.sh
$ shu-help
```

## Common utils
``` shell
$ shu-in-range <n> [range]    # Check whether a number <n> is in the <range>
$ shu-valid-range <range>     # Check whether a string <range> is valid for a range
```

`<range>` could have multiple intervals separated by comma, intervals should be `x-y`, `x` and `y` is a number and at least one of them should have be given.

## Testing framework

This framework is inspired by [clash](https://github.com/imathis/clash). Options are:

``` shell
$ shu-testing [dir] [tests]         # Run tests
$ shu-testing new [dir]             # Create a new test site
$ shu-testing list [dir] [tests]    # List tests
$ shu-testing accept [dir] [tests]  # Accept build: overwrite expected files with build files 
```
Default `<dir>` is `./test`, `<tests>` is a range denotes tests you'd like to run, an empty `<tests>` denotes all tests.

Configs for all cases should be placed under `<dir>/conf.d` after name `case.x.cnf`, `x` is a number which is the code for the case.

Config for a case including:

```shell
name="First Case"                    # name of this test case
before="mkdir -p output"             # script run before testing script
script="echo \$name > output/1.txt"  # testing script
after="echo Finish"                  # script run after compare
compare=("expected/:output/")        # files to be compared, each pair separated by a colon
```
## Contributing

1. Fork it ( https://github.com/wantee/shutils/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

