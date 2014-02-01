'''
I made this script because I forgot to harvest some data from SQS which then
was deleted.

The only data that I had was dictionaries that were printed into a screen session.

I saved the output of the screen session with

CTRL-A : hardcopy -h screen_output.txt

And then ran this script to get the data I wanted.

Here is a hacky way to get those dictionaries out of logs.

And put this in your ~/.screenrc file (future self):

defscrollback 50000


'''
import json
import sys

def try_lines(lines):
  code = ''.join(l.rstrip('\n') for l in lines)
  try:
    return eval(code)
  except:
     pass

def harvest_from_lines(lines, number_of_lines):
    '''Try getting objects out data that are number_of_lines long'''
    to_return = []
    for i in range(len(lines) - number_of_lines + 1):
        code = ''.join(l.rstrip('\n') for l in lines[i: i + number_of_lines])
        try:
            val = eval(code)
            # To test if it's a json serializable thing, like our precious dictionaries.
            json.dumps(val)
            to_return.append(val)
        except:
            pass

    return to_return

if __name__ == '__main__':
    (input, output) = sys.argv[1:]

    data = open(input).readlines()
    len_1 = harvest_from_lines(data, 1)
    len_2 = harvest_from_lines(data, 2)
    with open(output, 'wt') as f:
        json.dump(len_1 + len_2, f)
