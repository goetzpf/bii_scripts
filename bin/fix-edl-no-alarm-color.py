#!/usr/bin/env python3

# simple script to properly set NO_ALARM-color in HZB-created edl files,
# since aarm-rule in edm-colors-file needs to be replaced by default rule soon.
#
# 1. reads all elements into a list of ordered dictionaries
# 2. sets xyzColor to index 64 in all objects where xyzAlarm is set
# 3. writes all objects to file/stdout

from collections import OrderedDict
import sys


class Failure:
    def __init__(self, message):
        print(message, file=sys.stderr)


class Edl:
    def __init__(self, fname=0, inplace=False):
        self.fail = None
        # set output file
        self.fname = fname if inplace else 1

        if type(fname) == 'str' and not fname.endswith('.edl'):
            self.fail = Failure("filename does not end with .edl: " + fname)
            return

        with open(fname, "r", encoding="latin-1") as fin:
            self.read_objects(fin)

        # currently hard-coded no-alarm-colors
        self.NO_ALARM_color_rgb = "rgb 0 49344 0"
        self.NO_ALARM_color = "index 67"

    def read_objects(self, fin):
        lines = fin.readlines()
        # a simple check first line, wheter it actually could be an edl file
        try:
            while len(lines[0].rstrip("\n")) == 0:
                lines = lines[1:]
            version = lines[0]
            (major, minor, sub) = [int(part) for part in version.split(" ")]
            if major != 4 or not "%d %d %s" % (major, minor,
                                               sub) == version.rstrip('\n'):
                raise Exception()
        except Exception:
            self.fail = Failure("file seems not to be an edl file: " +
                                str(self.fname))

        self.element_dict = None
        self.list_of_elements = []
        in_contd_block = False
        block = []

        for line in lines:
            line = line.rstrip('\n')
            if len(line) == 0:
                if self.element_dict is not None:
                    self.list_of_elements.append(self.element_dict)
                    self.element_dict = None
            else:
                if self.element_dict is None:
                    self.element_dict = OrderedDict()

                sline = line.split(" ", 1)
                if sline[0] == "#":
                    sline = [line]

                if in_contd_block:
                    # store a block of {}-enclosed data as a list of lines
                    block.append(line)
                    if line == "}":
                        self.element_dict[key] = "\n".join(block)
                        block = []
                        in_contd_block = False
                else:
                    key = sline[0]

                    if len(sline) > 1:
                        # yes...
                        # Color entries are not consistently named
                        # across widget types
                        if ( key.endswith("Color") or
                             key.endswith("Colour") ) and \
                           sline[1].startswith("rgb"):
                            self.NO_ALARM_color = self.NO_ALARM_color_rgb

                        if sline[1].endswith('{'):
                            # store a block of {}-enclosed data as a list of lines
                            block.append(sline[1])
                            in_contd_block = True
                        else:
                            self.element_dict[key] = sline[1]
                    else:
                        self.element_dict[key] = None
        return self

    def dump(self):
        if not self.fail:
            # just dash out the stored data
            outfile = open(self.fname, 'w', encoding='latin-1')
            for element_dict in self.list_of_elements:
                for key in element_dict:
                    if element_dict[key] is None:
                        print(key, file=outfile)
                    else:
                        print(key + " " + element_dict[key], file=outfile)
                if len(element_dict) > 0:
                    print(file=outfile)
            outfile.close()

    def fix_color(self):
        if not self.fail:
            for element_dict in self.list_of_elements:
                for pfx in ("fg", "bg", "line", "fill", "control", "case",
                            "indicator"):
                    if pfx + "Alarm" in element_dict:
                        for clr in ["Color", "Colour"]:
                            if pfx + clr in element_dict:
                                element_dict[pfx + clr] = self.NO_ALARM_color
        return self


def main(args):
    IN_PLACE = True
    PIPE = False

    if len(args) == 0:
        args.append(0)

    # args is now >= 1
    elif len(args) > 1 and args[0] != "-i":
        print(
            "editing multiple files in place requires first argument to be '-i'",
            file=sys.stderr)
        exit(1)

    mode = IN_PLACE if len(args) > 1 else PIPE

    if args[0] == "-i":
        args = args[1:]

    for fname in args:
        Edl(fname, mode).fix_color().dump()


if __name__ == '__main__':
    main(sys.argv[1:])

# scenarios
#
# 1. ... | fix.py | ... OR fix.py <ifile >ofile   # pipe mode
#      len(args) == 0
# 2. fix.py file                                  # output to stdout
#      len(args) = 1 and arg[0] ~ "*.edl"
# 3. fix.py -i file1 ...                          # modify files in place
#      len(args) > 1 and arg[0] == "-i"
# else:
#     Error
