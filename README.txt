README
------

vocr v0.1.0
By Sriranga Veeraraghavan <ranga@calalum.org>

vocr is a MacOSX command line program that can perform optical
character recognition (OCR) on images and PDF files.  It outputs 
any text found in the input files to stdout.  vocr relies on 
Apple's Vision framework to perform OCR (hence its name v - for
[V]ision - and ocr - for [o]ptical [c]haracter [r]ecognition).

Usage:

    vocr [-i [no|tab]] [-p] [-q] [files] 

    If -i is specified with the 'no' option, vocr will not attempt 
    to indent any text that is OCR'ed.  If -i is specified with the
    'tab' option, vocr will indent using tabs instead of spaces (by 
    default vocr indents using spaces).

    If -p is specified, when OCR'ing a PDF, a page break (^L) will 
    be inserted at the end of each page.

    If -q is specified, vocr runs in [q]uiet mode and only outputs 
    text found in the input files (all errors and informational 
    message are silenced).

Build:

    $ ./configure
    $ make 

Install:

    $ ./configure
    $ make
    $ make install

    By default, vocr is installed in /usr/local/bin.  To install 
    it in a different location, the alternate installation PREFIX 
    can be supplied to make as follows:

        $ make install PREFIX="<prefix>"

    For example, the following will install vocr in /opt/local:

        $ make PREFIX=/opt/local install

    A DESTDIR can also be specified for staging purposes (with or
    without an alternate prefix):

        $ make DESTDIR="<destdir>" [PREFIX="<prefix>"] install

Dependencies:

   vocr relies on Apple's Vision framework, introduced in MacOSX
   10.13 (High Sierra):

   https://developer.apple.com/documentation/vision?language=objc

History:

    v0.1.0 - initial release

Platforms:

    vocr has been tested on MacOSX 11 (BigSur) on M1.

License:

    See LICENSE.txt

