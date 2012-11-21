#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
$Id: nginxLogReport.py,v 1.9 2010/06/09 06:45:52 raka Exp $


Describe:
This script work for recognition of nginx access log.
Script show the longest requests in nginx log sorted by
time and size of requested file.


Example of usage:
In nginx.conf are for example this setting:
log_format get_request_length '"$request" "$request_time" "$bytes_sent" "$status"';

and put into your virtualhost:
access_log  [path-to-log-dir]/request_time.log  get_request_length;


in cmd line you can type:
python nginxLogReport.py -f [path-to-log-dir]/request_time.log



Changelog:
- $Log: nginxLogReport.py,v $
- Revision 1.9  2010/06/09 06:45:52  raka
- *** empty log message ***
-
- Revision 1.8  2010/06/09 06:44:11  raka
- *** empty log message ***
-
- Revision 1.7  2010/06/09 06:34:04  raka
- *** empty log message ***
-
- Revision 1.6  2010/06/08 09:09:15  raka
- *** empty log message ***
-
- Revision 1.5  2010/06/08 09:03:00  raka
- *** empty log message ***
-
- Revision 1.4  2010/06/04 13:25:04  raka
- *** empty log message ***
-
- Revision 1.3  2010/06/04 13:22:41  raka
- *** empty log message ***
-
- Revision 1.2  2010/06/04 12:51:03  raka
- *** empty log message ***
-
- Revision 1.1  2010/06/04 12:46:07  raka
- *** empty log message ***
-
"""

__title__ = "$RCSfile: nginxLogReport.py,v $"
__version__ = "$Revision: 1.9 $"
__date__ = "$Date: 2010/06/09 06:45:52 $"
__author__= "Radek Kavan"
__email__= "jooke@centrum.cz"
__website__= "internet.billboard.cz"


try:
    import sys
    import time
    from optparse import OptionParser
    import os
except ImportError, e:
    print "Can't import (%s)" % (e)
    sys.exit(1)

try:
    import aplotter
except ImportError, e:
    print "Can't import (%s)" % (e)
    print "Install please aplotter"
    print "http://www.algorithm.co.il/sitecode/aplotter.zip"
    sys.exit(1)



class SummarizeLogFiles:

  def __init__(self, limitOfItems, fileToAnalyze):
    self.limitOfItems = limitOfItems
    self.fileToAnalyze = fileToAnalyze
    self.nginxRequestTimeList = []


  def dictifyLogLine(self, line):
    splitLine = line.split(' ')
    print line
    print splitLine
    sys.exit(0)
    return {'request': splitLine[1].split("?")[0],
            'time': splitLine[3],
            'size': splitLine[5],
            'status': splitLine[7]
            }


  def generateLogReport(self):
    reportDictByStatus = {}
    reportDictBySize = {}
    reportDictByRequest = {}

    try:
      nginxLogFile = open(self.fileToAnalyze, 'r')
    except IOError, (errno, strerror):
      print "I can't open file: %s" % (self.fileToAnalyze)
      print "I/O error(%s): %s" % (errno, strerror)
      print "ending..."
      sys.exit(1)

    radek = 1
    try:
      for line in nginxLogFile:
        lineDict = self.dictifyLogLine(line)
        radek += 1
        nginxRequest = lineDict['request']


        try:
          nginxRequestTime = float(lineDict['time'])
          nginxRequestSize = int(lineDict['size'])
          nginxRequestStatus = int(lineDict['status'])
        except ValueError:
            continue

        self.nginxRequestTimeList.append(nginxRequestTime)

        try:
            if reportDictByStatus[nginxRequestStatus] < nginxRequestTime:
                reportDictByStatus[nginxRequestStatus] = nginxRequestTime
        except KeyError:
            reportDictByStatus[nginxRequestStatus] = nginxRequestTime

        try:
            if reportDictBySize[nginxRequestSize] < nginxRequestTime:
                reportDictBySize[nginxRequestSize] = nginxRequestTime
        except:
            reportDictBySize[nginxRequestSize] = nginxRequestTime

        try:
            if reportDictByRequest[nginxRequest] < nginxRequestTime:
                reportDictByRequest[nginxRequest] = nginxRequestTime
        except:
            reportDictByRequest[nginxRequest] = nginxRequestTime


    except:
      print "Wrong file format: %s, line number: %s" % (self.fileToAnalyze, radek)
      print "You must use: log_format '\"$request\" \"$request_time\" \"$bytes_sent\" \"$status\"';"
      print "ending..."
      sys.exit()


    nginxLogFile.close()

    requestTimeByStatus = sorted(reportDictByStatus.items(), key=lambda (k,v): (v,k), reverse=True)
    requestTimeBySize = sorted(reportDictBySize.items(), key=lambda (k,v): (v,k), reverse=True)
    requestTimeByRequest = sorted(reportDictByRequest.items(), key=lambda (k,v): (v,k), reverse=True)

    return requestTimeByStatus, requestTimeBySize, requestTimeByRequest


  def printStatement(self, itemFromLog, valueFromLog):
    # barvicky
    fRed = chr(27) + '[31m'
    fGreen = chr(27) + '[32m'
    fYellow = chr(27) + '[33m'
    print fGreen + "\nSorted by %s:" % (itemFromLog)
    print "-" * 70
    print fRed + "%-50s%s" % (itemFromLog.upper(), "REQUEST TIME")
    print "-" * 70
    i = 0
    for key, value in valueFromLog:
      if i == self.limitOfItems:
        break
      i += 1
      print fYellow + "%-50s%s" % (key, value)
    print "=" * 70



  def showResult(self):
    requestTimeByStatus, requestTimeBySize, requestTimeByRequest = self.generateLogReport()
    fBold = chr(27) + '[1m'
    cEnd = chr(27) + '[0m'
    fUnderline = chr(27) + '[4m'
    print fBold + fUnderline + "Result is limited for %s items" % (self.limitOfItems) + cEnd
    self.printStatement("status", requestTimeByStatus)
    self.printStatement("size", requestTimeBySize)
    self.printStatement("request", requestTimeByRequest)


  def printChart(self,xLimit=50):
      cEnd = chr(27) + '[0m'
      fGreen = chr(27) + '[32m'
      fYellow = chr(27) + '[33m'
      print fGreen + "\n\nChart sorted by the longest requests. Limited for %s requests" % (xLimit) + cEnd
      print "-" * 70
      print fYellow
      sortedRequestTimes = sorted(self.nginxRequestTimeList, reverse=True)
      valuesForChart = sortedRequestTimes[0:xLimit]
      aplotter.plot(valuesForChart, plot_slope=False,output=str)



def main():


  usage = "usage: %prog [options] args \n"
  parser = OptionParser(usage, version=__version__)

  parser.add_option(
  "-d", "--description",
  dest="description",
  action="store_true",
  default = False,
  help = "Detail info")


  parser.add_option(
  "-f", "--file",
  dest="file",
  action="store",
  type="string",
  default = False,
  help = "Specify which file to analyze")


  parser.add_option(
  "-l", "--limit",
  dest="limit",
  action="store",
  type="int",
  default = 10,
  help = "Items limit (default 10)")

  parser.add_option(
  "-c", "--chart-limit",
  dest="chart",
  action="store",
  type="int",
  default = 50,
  help = "Items (the slowest requests) limit for drawing chart (default 50)")

  (options, args) = parser.parse_args()

  if options.description:
    print __doc__
    sys.exit(0)
  if not options.file:
    print "You must specify file for analyze...\nTry help! [-h | --help]"
    sys.exit(1)
  if not os.path.isfile(options.file):
    print "Your file doesn't exists"
    sys.exit(1)



  startScript =  time.strftime("%s")
  summarizeLogFiles = SummarizeLogFiles(limitOfItems = options.limit,
                                        fileToAnalyze = options.file)
  summarizeLogFiles.showResult()
  summarizeLogFiles.printChart(xLimit=options.chart)
  stopScript =  int(time.strftime("%s")) - int()

  dobaBehu= int(time.strftime("%s"))  - int(startScript)
  dobaBehuVHodinach= dobaBehu / 3600
  dobaBehuVMinutach= dobaBehu % 3600 / 60
  dobaBehuVSekundach= dobaBehu % 3600 % 60
  cEnd = chr(27) + '[0m'
  fBlue = chr(27) + '[34m'
  print fBlue + ("%s : %i HRS, %i MIN, %i SEC " %  ('\nTotal time of run:',
                                                dobaBehuVHodinach,
                                                dobaBehuVMinutach,
                                                dobaBehuVSekundach)) + cEnd




if __name__ == "__main__":
  main()
  sys.exit()
