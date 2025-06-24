README
------

vocr v0.3.2

Homepage:

    https://github.com/srirangav/vocr

About:

    vocr is a MacOSX command line program that can perform optical
    character recognition (OCR) on images and PDF files.  It outputs
    any text found in the input files to stdout.  vocr relies on,
    and derives its names from, the Vision framework (v for [V]ision).

Usage:

    vocr [-v] [-f] [-p] [-a [accurate|fast]] [-i [no|tab]] [-l [lang]] [files]
    vocr [-v] [-L] [-a [accurate|fast]]

    If -v is specified, vocr runs in [v]erbose mode and outputs
    errors and informational messages.

    If -f is specified, vocr will perform ocr on each page in a
    PDF.  By default, if a PDF already contains a text representation
    of a given page, vocr will output that text.

    If -p is specified, when OCR'ing a PDF, a page break (^L) will
    be inserted at the end of each page.

    if -a is specified with the 'fast' option, vocr will use the
    'fast' ocr algorithm, which may be useful for non-English
    languages, such as German.  If -a is specified with the 'accurate'
    option, vocr will use the 'accurate' ocr algorithm. By default,
    the 'accurate' algorithm is used.  The 'accurate' algorithm is also
    always used if the recognition language is specified as Chinese,
    Cantonese, Korean, Japanese, Russian, Ukrainian, Thai, or
    Vietnamese.

    If -i is specified with the 'no' option, vocr will not attempt
    to indent any text that is OCR'ed.  If -i is specified with the
    'tab' option, vocr will indent using tabs instead of spaces (by
    default vocr indents using spaces).

    If -l is specified, on MacOSX 11.x (BigSur) and newer, vocr
    will ask the Vision framework to recognize the text in the
    specified language.  The supported language options for MacOSX
    11.x and newer are:

        'de' - German
        'en' - English
        'fr' - French
        'it' - Italian
        'pt' - Portuguese
        'es' - Spanish
        'zh' - Chinese

    For MacOSX 13.x (Ventura) and newer, the following additional
    languages are supported:

        'yu' - Cantonese
        'kr' - Korean
        'jp' - Japanese
        'ru' - Russian
        'ua' - Ukrainian
        'th' - Thai
        'vt' - Vietnamese

    If -L is specified, the available languages for recognition
    are listed.  This option may be combined with the -a option
    to just list the languages that are supported by either the
    'fast' or the 'accurate' recognition algorithm.

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

    v. 0.3.2 - updates for Sonoma (MacOSX 14.x), integrate
               lslangs into vocr
    v. 0.3.1 - updates for Monterey (MacOSX 12.x)
    v. 0.3.0 - switch to PDFKit
    v. 0.2.3 - fix manpage formatting
    v. 0.2.2 - move source files into configure.ac
    v. 0.2.1 - update configure with additional compiler options
               related to security
    v. 0.2.0 - print text as soon as it has been recognized,
               default to quiet mode, add support for languages
               other than English
    v. 0.1.0 - initial release

Platforms:

    vocr has been tested on MacOSX 11.x (BigSur), 12.x (Monterey), and
    14.x (Sonoma) on M1 and x86_64. It should also work on MacOSX 10.15+
    (Catalina) x86_64.

License:

    See LICENSE.txt
