README
------

vocr v0.2.0
By Sriranga Veeraraghavan <ranga@calalum.org>

Homepage:

    https://github.com/srirangav/vocr

About:

vocr is a MacOSX command line program that can perform optical
character recognition (OCR) on images and PDF files.  It outputs
any text found in the input files to stdout.  vocr relies on,
and derives its names from, the Vision framework (v for [V]ision).

Usage:

    vocr [-v] [-f] [-p] [-i [no|tab]] [-l [lang]] [files]

    If -v is specified, vocr runs in [v]erbose mode and outputs
    errors and informational messages.

    If -f is specified, vocr uses the fast algorithm.  This may be
    useful when recognizing text in non-English languages, such as
    German.

    If -p is specified, when OCR'ing a PDF, a page break (^L) will
    be inserted at the end of each page.

    If -i is specified with the 'no' option, vocr will not attempt
    to indent any text that is OCR'ed.  If -i is specified with the
    'tab' option, vocr will indent using tabs instead of spaces (by
    default vocr indents using spaces).

    If -l is specified, on MacOSX 11.x (BigSur) and newer, vocr
    will ask the Vision framework to recognize the text in the
    specified language.  The supported language options are:

        'de' - German
        'en' - English
        'fr' - French
        'it' - Italian
        'pt' - Portuguese
        'es' - Spanish
        'zh' - Chinese

Build:

    $ ./configure
    $ make

Install:

    $ ./configure
    $ make
    $ make install

    By default, vocr is installed in /usr/local/bin.  To install
    it in a different location, the alternate installation prefix
    can be supplied to configure:

        $ ./configure --prefix="<prefix>"

    or, alternately to make:

        $ make install PREFIX="<prefix>"

    For example, the following will install vocr in /opt/local:

        $ make PREFIX=/opt/local install

    A DESTDIR can also be specified for staging purposes (with or
    without an alternate prefix):

        $ make DESTDIR="<destdir>" [PREFIX="<prefix>"] install

Dependencies:

   vocr relies on VNRecognizeTextRequest in Apple's Vision
   framework, which is available on MacOSX 10.15 (Catalina)
   and newer:

   https://developer.apple.com/documentation/vision/vnrecognizetextrequest

History:

    v. 0.2.0 - print text as soon as it has been recognized,
               default to quiet mode, add support for languages
               other than English
    v. 0.1.0 - initial release

Platforms:

    vocr has been tested on MacOSX 11 (BigSur) on M1 and x86_64.  It
    should also work on MacOSX 10.15+ (Catalina) x86_64.

License:

    See LICENSE.txt

