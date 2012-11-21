#!/usr/bin/env python
# -*- coding: utf-8 -*-

import psycopg2
import io
import sys
import math
import time
import re
import os

logfile='./logfile'
database="dbname='dev' user='aleks' host='192.168.10.80'"

if len(sys.argv) == 3:
    upto = int(sys.argv[2])
elif len(sys.argv) == 2:
    upto = 99999
    print 'Warning! Trying to delete history for all objects!'
else:
    print 'Error, please enter the date, max objects'
    sys.exit(1)

date = sys.argv[1]
try:
  valid_date = time.strptime(date, '%Y-%m-%d')
except ValueError:
  print('Format date is yyyy-mm-dd!')
  sys.exit(1)

if not os.path.exists(logfile):
    open(logfile, 'w').close()

print "Date: %s, Maximum objects %i" % (date, upto)

try:
    conn=psycopg2.connect(database)
    cur = conn.cursor()
    conn.autocommit = True
except psycopg2.DatabaseError, e:
    print "Database error occured: %s" % e.pgerror
    sys.exit(1)


data_read = io.open(logfile, 'rb')
object_passed = []

#Prepare object list
for obj in data_read.readlines():
    object_passed.append(long(obj))

data_read.close()
data_write = io.open(logfile, 'ab')

#cur.execute("select count(*) from object;")
#object=cur.fetchone()
#chunks = int(object[0]) / chunks
#limit = chunk * chunks
#offset = (chunk - 1) * chunks


cur.execute("SELECT id FROM object ORDER BY id ASC")

i = 0
timeinall = 0
for object in cur.fetchall():
    if i >= upto:
        print 'Maximum objects of %s deleted' % upto
        break

    if long(object[0]) not in object_passed:
        print 'Deleting data object %s' % object[0]
        try:

			#cur.execute("select count(*) as c from coordinates_%s;" % object[0])
            start = time.time()
            cur.execute("select count(*) from pg_tables where schemaname='coordinates' and tablename='coordinates_%s';" % object[0])

            objexists=cur.fetchone()
            if int(objexists[0]) > 0:
                cur.execute("DELETE FROM coordinates_%s WHERE datetime < '%s';" % (object[0],date))
		print "Deleted"
		cur.execute("VACUUM FULL coordinates_%s;" % object[0])
		print "Vacuum done"
                i = i + 1
                print 'Data for object %s delete untill %s' % (object[0], date)
                data_write.write('%s\n' % object[0]);

            print "Elapsed Time: %s" % (time.time() - start)
            timeinall = timeinall + (time.time() - start)
            print "Time ALL %s" % timeinall

            conn.commit()
        except psycopg2.DatabaseError, e:
            print e.pgerror
            conn.commit()

    sys.stdout.flush()
    data_write.flush()

data_write.close()
cur.close()
conn.close()
