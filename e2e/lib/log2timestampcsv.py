#!/usr/bin/env python3

#   Copyright (c) 2023 The Nephio Authors.
#
#   Licensed under the Apache License, Version 2.0 (the "License"); you may
#   not use this file except in compliance with the License. You may obtain
#   a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#   License for the specific language governing permissions and limitations
#   under the License.
#

import sys
import re
import datetime
import argparse

DEFAULT_SLOW_DELAY = 120

def get_log_lines(file_name):
  if file_name != None:
    try:
      log_file = open(file_name)
    except:
      print("could not open file " + file_name)
      return(None)
  else:
    log_file = sys.stdin

  try:
    log_lines = log_file.readlines()
    return log_lines
  except:
    print("could not read file " + file_name)
    return(None)

def split_in_two(in_string, delimiter):
  in_string_split = in_string.split(delimiter)

  if len(in_string_split) > 2:
    two_element_split =  []
    two_element_split.append(in_string_split[0])
    two_element_split.append(''.join(in_string_split[1:]))
    return two_element_split
  else:
    return in_string_split

def parse_log_lines(log_lines):
  csv_lines = []

  for log_line in log_lines:
    log_line = log_line.strip().replace("\x1b", "")

    if re.search("\\[0m \\[0m[0-9][0-9]:[0-9][0-9]:[0-9][0-9] - [A-Z]*: ", log_line):
      log_line_split = split_in_two(log_line, "):[0m [0m")
      timestamped_line = ''.join(log_line_split[1:])

      csv_elements = []

      first_split = split_in_two(timestamped_line, " - ")
      csv_elements.append(first_split[0])

      second_split = split_in_two(first_split[1], ": ")
      csv_elements.extend(second_split)

      csv_lines.append(csv_elements)

  return csv_lines

def operation_time(last_timestamp, this_timestamp):
  lh,lm,ls = last_timestamp.split(':')
  last_datetime = datetime.timedelta(hours=int(lh),minutes=int(lm),seconds=int(ls)).total_seconds()

  th,tm,ts = this_timestamp.split(':')
  this_datetime = datetime.timedelta(hours=int(th),minutes=int(tm),seconds=int(ts)).total_seconds()

  time_difference = this_datetime - last_datetime
  if time_difference < 0:
    time_difference = time_difference + 86400

  return time_difference

def add_timestamp_check(csv_lines, slow_delay):
  last_timestamp = csv_lines[0][0]

  current_lineno = 1
  csv_lines[0].append(0)
  csv_lines[0].append("no")

  while current_lineno < len(csv_lines):
    delay = operation_time(csv_lines[current_lineno-1][0], csv_lines[current_lineno][0])
    csv_lines[current_lineno].append(int(delay))

    if delay < slow_delay:
      csv_lines[current_lineno].append("no")
    else:
      csv_lines[current_lineno].append("yes")

    current_lineno += 1

  return csv_lines

def print_csv_lines(csv_lines):
  for csv_line in csv_lines:
    print(csv_line[0] + ',' + csv_line[1] + ",\"" + csv_line[2] + "\"," + str(csv_line[3]) + "," + csv_line[4])

  return csv_lines

parser = argparse.ArgumentParser(
  'log2timestampcsv',
  'Parses timestamp entries from a Nephio end to end test log'
)
parser.add_argument(
  "-f",
  "--file-name",
  help="the name of the file containing the e2e test log, program uses standard input if omitted",
  required=False
)
parser.add_argument(
  "-d",
  "--delay-slow",
  help="The difference in seconds between log entries, any entry matching or greater than this value is considered slow, defaults to " + str(DEFAULT_SLOW_DELAY) + " seconds",
  default=DEFAULT_SLOW_DELAY,
  required=False
)

args = parser.parse_args()

log_lines = get_log_lines(args.file_name)

if log_lines is None:
  exit(1)

csv_lines = parse_log_lines(log_lines)
csv_lines = add_timestamp_check(csv_lines, args.delay_slow)

print_csv_lines(csv_lines)
