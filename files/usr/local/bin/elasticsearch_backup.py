#!/usr/bin/python

##### LICENSE

# Copyright (c) Skyscrapers (iLibris bvba) 2014 - http://skyscrape.rs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import time
import requests
import json
import sys
import getopt
import datetime
from time import mktime
from datetime import timedelta

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hn:a:",["name=","age="])
    except getopt.GetoptError:
        print 'elasticsearch_backup.py -n <name> -a <max backup age>'
        sys.exit(2)

    if opts:
        for opt, arg in opts:
            if opt == '-h':
                print 'elasticsearch_backup.py -n <name> -a <max backup age>'
                sys.exit()
            elif opt in ("-n", "--name"):
                name = arg
            elif opt in ("-a", "--age"):
                age = int(arg)
    else:
        print 'elasticsearch_backup.py -n <name> -a <max backup age>'
        sys.exit(2)

    delete_old_snapshots(name,age)
    create_snapshot(name)


def delete_old_snapshots(name, age):
    keep_backup_date = datetime.datetime.now() - timedelta(days=age)
    keep_miliseconds = 1000*mktime(keep_backup_date.timetuple())

    snapshots = get_snapshots(name)

    for snapshot in snapshots['snapshots']:
        if snapshot['end_time_in_millis'] < keep_miliseconds:
            try:
                r = requests.delete("http://localhost:9200/_snapshot/" + name + "/" + snapshot['snapshot'])
            except requests.Timeout, e:
                print 'Time-out on delete of snapshot'
                exit(2)
            if r.status_code != 200:
                print 'HTTP response is not 200 when trying to delete a snapshot'
                try:
                    response = r.json()
                    print response['error']
                except ValueError:
                    print 'No JSON response'
                exit(2)

def get_snapshots(name):
    try:
        r = requests.get("http://localhost:9200/_snapshot/" + name + "/_all")
    except requests.Timeout, e:
        print 'Time-out when querying for snapshots'
        exit(2)
    if r.status_code != 200:
        print 'HTTP response is not 200 when requesting snapshots'
        try:
            response = r.json()
            print response['error']
        except ValueError:
            print 'No JSON response'
        exit(2)

    response = r.json()
    return response

def create_snapshot(name):
    snapshot_id = time.strftime("%y_%m_%d_%H_%M_%S")
    try:
        r = requests.put("http://localhost:9200/_snapshot/" + name +"/" + snapshot_id + "?wait_for_completion=true", timeout=300)
    except requests.Timeout, e:
        print 'Took longer than 5 minutes to get a response when trying to add a snapshot'
        exit(2)

    if r.status_code != 200:
        print 'HTTP response is not 200 when adding a snapshot'
        try:
            response = r.json()
            print response['error']
        except ValueError:
            print 'No JSON response'
        exit(2)

    response = r.json()

    if response['snapshot']['state'] != 'SUCCESS':
        print 'Return state is not success'
        exit(2)

if __name__ == "__main__":
   main(sys.argv[1:])
