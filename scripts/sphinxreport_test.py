#!/bin/env python
import sys, os, imp, cStringIO, re, types, glob, optparse

USAGE = """python %s [OPTIONS] args

evaluate all Trackers in the python directory.

The script collects all Trackers in the 'python' directory
and evaluates them. The Trackers are evaluated in parallel
and thus allow a much faster data collection than through
sphinx.
"""

import matplotlib
import matplotlib.pyplot as plt

from SphinxReport.Tracker import Tracker
from SphinxReport.Renderer import *

from multiprocessing import Process
# from threading import Thread as Process

if not os.path.exists("conf.py"):
    raise IOError( "could not find conf.py" )

execfile( "conf.py" )

RST_TEMPLATE = """.. _%(label)s:

.. render:: %(tracker)s
   :render: %(renderer)s
   %(options)s

   %(caption)s
"""

def getTrackers( fullpath ):
    """retrieve an instantiated tracker and its associated code.
    
    returns a tuple (code, tracker).
    """
    name, cls = os.path.splitext(fullpath)
    # remove leading '.'
    cls = cls[1:]
    module_name = os.path.basename(name)

    (file, pathname, description) = imp.find_module( name )
    stdout = sys.stdout
    sys.stdout = cStringIO.StringIO()
    try:
        module = imp.load_module(name, file, pathname, description )
    except:
        raise
    finally:
        file.close()
        sys.stdout = stdout

    trackers = []
    for name in dir(module):
        obj = getattr(module, name)
        if (isinstance(obj, (type, types.ClassType)) and
            issubclass(obj, Tracker)):
            trackers.append( (name, obj, module_name) )

    return trackers

def run( name, t, kwargs ):
    
    print "%s: collecting data started" % name     
    t( **kwargs )
    print "%s: collecting data finished" % name     

def main():

    parser = optparse.OptionParser( version = "%prog version: $Id$", usage = USAGE )

    parser.add_option( "-t", "--tracker", dest="tracker", type="string",
                          help="tracker to use [default=%default]" )

    parser.add_option( "-a", "--tracks", dest="tracks", type="string",
                          help="tracks to use [default=%default]" )

    parser.add_option( "-s", "--slices", dest="slices", type="string",
                          help="slices to use [default=%default]" )

    parser.add_option( "-r", "--renderer", dest="renderer", type="string",
                          help="renderer to use [default=%default]" )

    parser.add_option( "-o", "--option", dest="options", type="string", action="append",
                       help="renderer options - supply as key=value pairs (without spaces). [default=%default]" )

    parser.add_option( "-p", "--print", dest="do_print", action="store_true",
                       help = "print an rst text element to create the displayed plots [default=%default]." )

    parser.set_defaults(
        tracker=None,
        tracks=None,
        slices=None,
        options = [],
        renderer = None,
        do_show = True,
        do_print = True,
        label = "GenericLabel",
        caption = "add caption here" )
    
    (options, args) = parser.parse_args()

    if options.renderer:
        try:
            renderer = eval("%s" % options.renderer)
        except NameError:
            raise NameError ("could not find renderer '%s'. Examples are: 'RendererHistogramTable', 'RendererStatsPlot'" % options.renderer )
    else:
        renderer = Renderer

    kwargs = {}
    for x in options.options:
        if "=" in x:
            key,val = [ y.strip() for y in x.split("=") ]
        else:
            key, val = x.strip(), None
        kwargs[key] = val
    
    if options.tracks: kwargs["tracks"] = options.tracks
    if options.slices: kwargs["slices"] = options.slices

    for filename in glob.glob( "python/*.py" ):

        trackers = [ x for x in getTrackers( filename ) if x[0] not in ("Tracker", "TrackerSQL") ] 
        if options.tracker:
            available_trackers = set( [ x[0] for x in trackers ] )
            if options.tracker not in available_trackers:
                raise NameError( "unknown tracker '%s': available trackers are %s" % (options.tracker, ",".join( available_trackers) ) )

            for name, tracker, modulename in trackers:
                if name == options.tracker: break

            r = renderer( tracker() )
            result = r( **kwargs)
            if options.do_print:                        
                options_rst = []
                for key,val in kwargs.items():
                    if val == None:
                        options_rst.append(":%s:" % key )
                    else:
                        options_rst.append(":%s: %s" % (key,val) )

                print "..Template start"
                print
                params = { "tracker" : "%s.%s" % (modulename,name),
                           "renderer" : options.renderer,
                           "label" : options.label,
                           "options": ("\n   ").join(options_rst),
                           "caption" : options.caption }
                print RST_TEMPLATE % params
                print
                print "..Template ends"
            if result: print "\n".join(result)
            if options.do_show: plt.show()

        else:
            processes = []
            for name, tracker, modulename in trackers:
                obj = tracker()
                r = renderer( obj )
                p = Process( target = run, args= ( name,r,kwargs ) )
                processes.append( (name, p) )
                p.start()

            for name, p in processes:
                p.join()

if __name__ == "__main__":
    sys.exit(main())
