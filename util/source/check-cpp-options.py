#!/usr/bin/env python

import os
import re
import sys

from optparse import OptionParser

# Naming convention checker
def check_name(cpp_option,cpp_blocks):
  opt = cpp_option.split("_")
  ret = True
  for i in range(len(opt)):
    ret = (opt[i] in cpp_blocks[i])
    if ( not ret ):
      break
  return ret

# Parse command-line arguments
my_help = "Usage: %prog [-v|--verbose]"""
parser = OptionParser(usage=my_help, version="%prog for Abinit 6")
parser.add_option("-v", "--verbose", action="store_true",
  dest="verbose", default=False,
  help="Report developer options")
(opts, args) = parser.parse_args()
chk_verbose = opts.verbose

# Init script
my_name = os.path.basename(sys.argv[0])

# Init regular expressions
re_m4file  = re.compile("\.m4$")
re_hdrfile  = re.compile("\.h$")
re_f90file = re.compile("\.F90$")
re_acdef  = re.compile("AC_DEFINE\\(")
re_cppdef  = re.compile("^([ ]?)+#([ ]?)+define [0-9A-Z_]*")
re_cppline = re.compile("^#")
re_cppcont = re.compile("\\$")
re_cppskip = re.compile("^#(include|define|undef|if 0|if 1|endif|error)")
re_cppdev  = re.compile("DEV_")

# Init CPP options
cpp_blocks = [["HAVE"],["CONFIG"],["H"]]
cpp_explicit = [
  "HAVE_TEST_TIME_PARTITIONING",
  "i386"]
cpp_ignored = [
  "HAVE_CONFIG_H"]
cpp_keywords = ("#","endif","ifdef","ifndef","elif","if","else","defined","==[ ]*[0-9]*","\\|\\|","&&","\\(","\\)","!")

# Extract CPP options from the build system
cpp_buildsys = list()
for root,dirs,files in os.walk("config/m4"):
  for src in files:
    if ( re_m4file.search(src) ):
      for line in file(os.path.join(root,src),"r").readlines():
        if ( re_acdef.search(line) ):
          tmp_def = re.sub(".*AC_DEFINE\\([\\[]?([^\\],]*).*","\\1",line).strip()
          if ( not tmp_def in cpp_buildsys ):
            cpp_buildsys.append(tmp_def)
for line in file("configure.ac","r").readlines():
  if ( re_acdef.search(line) ):
    tmp_def = re.sub(".*AC_DEFINE\\([\\[]?([^\\],]*).*","\\1",line).strip()
    if ( not tmp_def in cpp_buildsys ):
      cpp_buildsys.append(tmp_def)
cpp_buildsys.sort()

# Create CPP naming blocks
for opt in cpp_buildsys:
  tmp = opt.split("_")
  for i in range(len(tmp)):
    if ( i >= len(cpp_blocks) ):
      cpp_blocks.append(list())
    if ( not tmp[i] in cpp_blocks[i] ):
      cpp_blocks[i].append(tmp[i])

# Extract CPP options from the includes
cpp_includes = list()
for root,dirs,files in os.walk("src/incs"):
  for src in files:
    if ( re_hdrfile.search(src) ):
      for line in file(os.path.join(root,src),"r").readlines():
        if ( re_cppdef.search(line) ):
          tmp_def = re.sub("^[# ]*define[ ]*([0-9A-Z_]*).*","\\1",line).strip()
          if ( not tmp_def in cpp_includes ):
            cpp_includes.append(tmp_def)
cpp_includes.sort()

# Merge CPP information
cpp_allowed = cpp_explicit + cpp_buildsys
cpp_allowed.sort()

# Explore the source files
cpp_source = dict()
for root,dirs,files in os.walk("src"):

  files.sort()
  for src in files:
    if ( re_f90file.search(src) ):
      f90_buffer = file(os.path.join(root,src),"r").readlines()
      cpp_load = False
      for i in range(len(f90_buffer)):
        line = f90_buffer[i]

        # Record CPP lines
        if ( re_cppline.search(line) ):
          if ( cpp_load ):
            sys.stderr.write("%s: %s:%d: Error: unterminated CPP directive\n" % \
              (my_name,src,i+1))
            sys.exit(1)
          cpp_load = True
          cpp_buffer = ""

        # Process CPP lines
        if ( cpp_load ):
          cpp_buffer += line
          if ( not re_cppcont.search(line) ):
            if ( not re_cppskip.search(line) ):

              # Extract CPP options
              for kwd in cpp_keywords:
                cpp_buffer = re.sub(kwd,"",cpp_buffer)
              cpp_buffer = re.sub("[\n\t ]+"," ",cpp_buffer)
              cpp_buffer = cpp_buffer.strip()
              cpp_buffer = cpp_buffer.split()

              # Register CPP options
              for opt in cpp_buffer:
                if ( not opt in cpp_ignored ):
                  if ( not opt in cpp_source ):
                    cpp_source[opt] = list()
                  cpp_source[opt].append("%s/%s:%d" % (root,src,i+1))

            # Reset 
            cpp_load = False

# Process CPP option information
cpp_keys = cpp_source.keys()
cpp_keys.sort()
cpp_devel = [opt for opt in cpp_keys \
  if ( opt in cpp_explicit or re_cppdev.match(opt) )]
cpp_undefined = [opt for opt in cpp_keys \
  if not ( (opt in cpp_allowed) or (opt in cpp_devel) )]

cpp_misnamed = [opt for opt in cpp_keys \
  if not ( check_name(opt,cpp_blocks) or (opt in cpp_undefined) or
    (opt in cpp_devel) ) ]
cpp_misnamed += [opt for opt in cpp_includes \
  if ( opt in cpp_source and not check_name(opt,cpp_blocks) )]
cpp_misnamed.sort()

# Display forbidden CPP options
if ( (chk_verbose and (len(cpp_devel) > 0)) or (len(cpp_undefined) > 0) ):
  sys.stderr.write("%s: reporting preprocessing option discrepancies\n\n" % \
    (os.path.basename(sys.argv[0])))
  sys.stderr.write("X: N=Wrong Naming / U=Undefined\n\n")

if ( chk_verbose and (len(cpp_devel) > 0) ):
  sys.stderr.write("%s  %-24s  %-44s\n" % ("X","Developer option","Location"))
  sys.stderr.write("%s  %-24s  %-44s\n" % ("-","-" *24,"-" * 48))
  for opt in cpp_devel:
    if ( len(cpp_source[opt]) <= 50 ):
      for src in cpp_source[opt]:
        sys.stderr.write("*  %-24s  %-48s\n" % (opt,src))
    else:
      sys.stderr.write("*  %-24s  Not shown (referenced %d times)\n" % \
        (opt,len(cpp_source[opt])))
  sys.stderr.write("\n")

if ( (len(cpp_undefined) + len(cpp_misnamed)) == 0 ):
  sys.exit(0)
else:
  sys.stderr.write("%s  %-24s  %-44s\n" % ("X","Forbidden option","Location"))
  sys.stderr.write("%s  %-24s  %-44s\n" % ("-","-" *24,"-" * 48))
  for opt in cpp_undefined:
    if ( len(cpp_source[opt]) <= 50 ):
      for src in cpp_source[opt]:
        sys.stderr.write("U  %-24s  %-48s\n" % (opt,src))
    else:
      sys.stderr.write("U  %-24s  Not shown (referenced %d times)\n" % \
        (opt,len(cpp_source[opt])))
  for opt in cpp_misnamed:
    sys.stderr.write("N  %-24s  N/A\n" % (opt))
  sys.stderr.write("\n")
  sys.exit(1)
