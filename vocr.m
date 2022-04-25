/*
    vocr.m - perform optical character recognition on an image or a PDF
             using Apple's Vision framework

    Inspired by: https://turbozen.com/sourceCode/ocrImage/
                 https://nemecek.be/blog/38/how-to-implement-ocr-with-vision-framework-in-ios-13

    History:

    v. 0.1.0 (04/19/2022) - Initial version
    v. 0.2.0 (04/24/2022) - print text as soon as it has been recognized,
                            default to quiet mode
    v. 0.3.0 (04/25/2022) - add language support

    Copyright (c) 2022 Sriranga R. Veeraraghavan <ranga@calalum.org>

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <AppKit/AppKit.h>
#import <Vision/Vision.h>
#import <stdio.h>
#import <stdarg.h>
#import <unistd.h>
#import <string.h>
#import <math.h>

/* globals */

static NSString   *gUTIPDF    = @"com.adobe.pdf";
static NSString   *gUTIIMG    = @"public.image";
static NSString   *gIndentStr = @"    ";
static const char *gPgmName   = "vocr";
#ifdef VOCR_IMG2TXT
static const NSUInteger
                  gBufSize    = 1024;
#endif /* VOCR_IMG2TXT */

/*
    command line options:
        -h        - print usage / [h]elp
        -i [mode] - set the [i]ndent mode:
                    'no'   disables indenting
                    'tab'  indents with tabs (default is to use 4 spaces)
        -l - specify the [l]anguage that the input is in (TODO)
        -p - add a page break / [l]ine feed between pages
        -v - be [v]erbose
*/

enum
{
    gPgmOptHelp      = 'h',
    gPgmOptIndent    = 'i',
    gPgmOptLang      = 'l',
    gPgmOptPageBreak = 'p',
    gPgmOptVerbose   = 'v',
};

enum
{
    gLangChineseSimplified  = 'c', /* zh-Hans */
    gLangGerman             = 'd', /* de-DE */
    gLangEnglish            = 'e', /* en-US */
    gLangFrench             = 'f', /* fr-FR */
    gLangItalian            = 'i', /* it-IT */
    gLangPortuguese         = 'p', /* pt-BR */
    gLangSpanish            = 's', /* es-ES */
    gLangChineseTraditional = 't'  /* zh-Hant */
};

static const char *gPgmOpts      = "hpvi:l:";
static const char *gPgmIndentNo  = "no";
static const char *gPgmIndentTab = "tab";
static BOOL       gQuiet         = YES;

static const char *gPgmLangGerman             = "de";
static const char *gPgmLangEnglish            = "en";
static const char *gPgmLangFrench             = "fr";
static const char *gPgmLangItalian            = "it";
static const char *gPgmLangPortuguese         = "pt";
static const char *gPgmLangSpanish            = "es";
static const char *gPgmLangChineseSimplified  = "zh";
static const char *gPgmLangChineseTraditional = "zt";

/* ocr options */

typedef struct
{
    BOOL addPageBreak;
    BOOL indent;
    BOOL indentWithTabs;
    int lang;
} ocrOpts_t;

/* prototypes */

static void printUsage(void);
static void printError(const char *format, ...);
static void printInfo(const char *format, ...);
#ifdef VOCR_DEBUG
static void printSupportedLangs(void);
#endif /* VOCR_DEBUG */
static BOOL ocrFile(const char *file,
#ifdef VOCR_IMG2TXT
                    NSMutableString *text,
#endif /* VOCR_IMG2TXT */
                    ocrOpts_t *opts);
static BOOL ocrImage(CGImageRef cgImage,
#ifdef VOCR_IMG2TXT
                     NSMutableString *text,
#endif /* VOCR_IMG2TXT */
                     ocrOpts_t *opts);

/* private functions */

/* printUsage - print the usage message */

static void printUsage(void)
{
    fprintf(stderr,
            "Usage: %s [-%c] | [-%c] [-%c] [-%c [%s|%s]] [files]\n",
            gPgmName,
            gPgmOptHelp,
            gPgmOptVerbose,
            gPgmOptPageBreak,
            gPgmOptIndent,
            gPgmIndentNo,
            gPgmIndentTab);
}

/* printError - print an error message */

static void printError(const char *format, ...)
{
    va_list args;

    if (gQuiet == YES)
    {
        return;
    }

    va_start(args, format);
    fprintf(stderr,"ERROR: ");
    vfprintf(stderr, format, args);
    va_end(args);
}

/* printInfo - print an informational message */

static void printInfo(const char *format, ...)
{
    va_list args;

    if (gQuiet == YES)
    {
        return;
    }

    va_start(args, format);
    fprintf(stderr,"INFO:  ");
    vfprintf(stderr, format, args);
    va_end(args);
}

/* ocrImage - try to ocr the specified image */

static BOOL ocrImage(CGImageRef cgImage,
#ifdef VOCR_IMG2TXT
                     NSMutableString *text,
#endif /* VOCR_IMG2TXT */
                     ocrOpts_t *opts)
{
    NSArray *results;
    NSUInteger numResults = 0, j = 0;
    VNImageRequestHandler *requestHandler = nil;
    VNRecognizeTextRequest *request = nil;
    VNRecognizedTextObservation *rawText = nil;
    NSArray<VNRecognizedText *> *recognizedText;
    NSString *tmp1 = nil, *tmp2 = nil;
#ifdef VOCR_IMG2TXT
    NSMutableString *ocrText = nil;
#endif /* VOCR_IMG2TXT */
    NSMutableArray<VNRecognizedTextObservation *> *textPieces;
    unsigned int indentLevel = 0, k = 0;
    double prevStart = 0.0, prevEnd = 0.0;
    double curStart = 0.0, curEnd = 0.0;
    BOOL indent = YES;
    NSString *indentStr = gIndentStr;

#ifdef VOCR_IMG2TXT
    if (text == nil)
    {
        printError("Text buffer is NULL!\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    if (opts != NULL)
    {
        indent = opts->indent;
        if (opts->indentWithTabs)
        {
            indentStr = @"\t";
        }
    }

#ifdef VOCR_IMG2TXT
    ocrText = [[NSMutableString alloc] initWithCapacity: gBufSize];
    if (ocrText == nil)
    {
        printError("Cannot allocate mutable string.\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    textPieces = [NSMutableArray array];
    if (textPieces == nil)
    {
        printError("Cannot allocate mutable array.\n");
        return NO;
    }

    /*
        create a OCR request, based on:

        https://developer.apple.com/documentation/vision/recognizing_text_in_images?language=objc#overview
        https://developer.apple.com/documentation/vision/vnimagerequesthandler?language=objc
        https://developer.apple.com/documentation/vision/vnrecognizetextrequest?language=objc
        https://bendodson.com/weblog/2019/06/11/detecting-text-with-vnrecognizetextrequest-in-ios-13/
        https://chris-mash.medium.com/ios-13-optical-character-recognition-d1bb8b710db1
    */

    requestHandler =
        [[VNImageRequestHandler alloc] initWithCGImage: cgImage
                                               options: @{}];
    if (requestHandler == nil)
    {
        printError("Could not create OCR request handler.\n");
        return NO;
    }

    request = [[VNRecognizeTextRequest alloc] init];
    if (request == nil)
    {
        printError("Could not create OCR request for.\n");
        return NO;
    }

    /*
        enable accurate recognition and language correction
        https://developer.apple.com/documentation/vision/vnrequesttextrecognitionlevel?language=objc
        https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3166773-useslanguagecorrection?language=objc
    */

    [request setRecognitionLevel:
        VNRequestTextRecognitionLevelAccurate];
    [request setUsesLanguageCorrection: YES];

    /*
        use the version 2 algorithm on MacOSX 11+, which supports
        multiple languages:

        https://developer.apple.com/documentation/vision/vnrecognizetextrequestrevision2?language=objc
        https://stackoverflow.com/questions/63813709
    */

    if (@available(macos 11, *))
    {
        [request setRevision: VNRecognizeTextRequestRevision2];
    }
    else
    {
        [request setRevision: VNRecognizeTextRequestRevision1];
    }

    if ([requestHandler performRequests: @[request]
                                  error: NULL] == NO)
    {
        printError("OCR failed.\n");
        return NO;
    }

    results = [request results];
    if (results == nil)
    {
        printInfo("No text found.\n");
        return NO;
    }

    numResults = [results count];
    if (numResults == 0)
    {
        printInfo("No text found.\n");
        return NO;
    }

    /* possibly found some text */

    for (j = 0; j < numResults; j++)
    {

        /* skip any result that isn't a VNRecognizedTextObservation */

        if (results[j] == nil ||
            ![results[j] isKindOfClass:
              [VNRecognizedTextObservation class]])
        {
            continue;
        }

        rawText = (VNRecognizedTextObservation *)results[j];
        recognizedText = [rawText topCandidates:1];
        if (recognizedText == nil)
        {
            continue;
        }

        /* get the top recognition candidate */

        tmp1 = [[recognizedText firstObject] string];
        if (tmp1 == nil)
        {
            continue;
        }

        /*
            eliminate any leading or trailing whitespace:
            https://stackoverflow.com/questions/5689288/
        */

        tmp2 = [tmp1 stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (tmp2 == nil)
        {
            continue;
        }

        /*
           use the botton X position as a proxy for the starting
           and ending position of the current line
        */

        curStart = round(10.0 * rawText.bottomLeft.x);
        curEnd = round(10.0 * rawText.bottomRight.x);

        /* first line */

        if (j == 0)
        {
            prevStart = curStart;
            prevEnd = curEnd;
#ifdef VOCR_IMG2TXT
            [ocrText appendString: tmp2];
#else
            fprintf(stdout,
                    "%s",
                    [tmp2 cStringUsingEncoding: NSUTF8StringEncoding]);
#endif /* VOCR_IMG2TXT */
            continue;
        }

        /*
            if the starting position of the current line is greater
            than that of the previous line and this line ends before
            the prior line, this line is probably not part of the
            same paragraph as the prior line, so add a new line
        */

        if (curStart > prevStart && curEnd < prevEnd)
        {
#ifdef VOCR_IMG2TXT
            [ocrText appendString: @"\n"];
#else
            fprintf(stdout, "\n");
#endif /* VOCR_IMG2TXT */
        }

        /*
            if the starting position of the current line is greater than
            that of the previous line, add a newline and increase the
            the indent level

            if the starting position of the current line is less than of
            the previous line, add a new line and reduce the indent level
        */

        if (curStart > prevStart)
        {
            indentLevel++;
#ifdef VOCR_IMG2TXT
            [ocrText appendString: @"\n"];
#else
            fprintf(stdout, "\n");
#endif /* VOCR_IMG2TXT */
        }
        else if (curStart < prevStart)
        {
            if (indentLevel > 1)
            {
                indentLevel--;
#ifdef VOCR_IMG2TXT
                [ocrText appendString: @"\n"];
#else
                fprintf(stdout, "\n");
#endif /* VOCR_IMG2TXT */
            }
        }

        if (curStart >= prevStart)
        {
            if (indent && indentLevel > 0)
            {
                for (k = 0; k < indentLevel; k++)
                {
#ifdef VOCR_IMG2TXT
                    [ocrText appendString: indentStr];
#else
                    fprintf(stdout,
                            "%s",
                            [indentStr cStringUsingEncoding: NSUTF8StringEncoding]);
#endif /* VOCR_IMG2TXT */
                }
            }
            prevStart = curStart;
        }

        /* add the current line to the OCR'ed text */

#ifdef VOCR_IMG2TXT
        [ocrText appendFormat: @"%@ ", tmp2];
#else
        fprintf(stdout,
                "%s",
                [tmp2 cStringUsingEncoding: NSUTF8StringEncoding]);
#endif /* VOCR_IMG2TXT */

        /*
            if this line ends before the end of the prior line,
            add a new line
        */

        if (curEnd < prevEnd)
        {
#ifdef VOCR_IMG2TXT
            [ocrText appendString: @"\n"];
#else
            fprintf(stdout, "\n");
#endif /* VOCR_IMG2TXT */
        }

        prevEnd = curEnd;
    }

#ifdef VOCR_IMG2TXT
    [text setString: ocrText];
#endif /* VOCR_IMG2TXT */
    return YES;
}

/* ocrFile - try to ocr the specified file */

static BOOL ocrFile(const char *file,
#ifdef VOCR_IMG2TXT
                    NSMutableString *text,
#endif /* VOCR_IMG2TXT */
                    ocrOpts_t *opts)
{
    NSFileManager *fm = nil;
    NSWorkspace *workspace = nil;
    NSString *path = nil;
    NSURL *fURL = nil;
    NSString *type = nil;
    NSError *error = nil;
    NSImage *image = nil;
    NSRect imageRect;
    CGImageRef cgImage;
    NSData *pdfData = nil;
    NSPDFImageRep *pdfImageRep = nil;
    NSInteger pdfPages = 0, i = 0;
#ifdef VOCR_IMG2TXT
    NSMutableString *pdfText = nil;
#endif /* VOCR_IMG2TXT */

    if (file == NULL || file[0] == '\0')
    {
        printError("Filename is NULL!\n");
        return NO;
    }

#ifdef VOCR_IMG2TXT
    if (text == nil)
    {
        printError("Text buffer is NULL!\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    fm = [NSFileManager defaultManager];
    if (fm == nil)
    {
        printError("Cannot get NSFileManager!\n");
        return NO;
    }

    workspace = [NSWorkspace sharedWorkspace];
    if (workspace == nil)
    {
        printError("Cannot get NSWorkspace!\n");
        return NO;
    }

    path = [fm stringWithFileSystemRepresentation: file
                                           length: strlen(file)];
    if (path == nil)
    {
        printError("Cannot get full path for '%s'.\n", file);
        return NO;
    }

    fURL = [NSURL fileURLWithPath: path];
    if (fURL == nil)
    {
        printError("Cannot get create URL for '%s'.\n", file);
        return NO;
    }

    /*
        determine if the file is of a type we support, based on:

        https://stackoverflow.com/questions/12503376
    */

    if (![fURL getResourceValue: &type
                         forKey: NSURLTypeIdentifierKey
                          error: &error])
    {
        printError("Cannot determine file type for '%s'.\n", file);
        return NO;
    }

    /* ocr a PDF */

    if ([workspace type: type conformsToType: gUTIPDF])
    {

#ifdef VOCR_IMG2TXT
        pdfText = [[NSMutableString alloc] initWithCapacity: gBufSize];
        if (pdfText == nil)
        {
            printError("Cannot allocate buffer for PDF text.\n");
            return NO;
        }
#endif /* VOCR_IMG2TXT */

        /*
            convert each page of a PDF to an image and then OCR it,
            based on:
            https://stackoverflow.com/questions/23643961
        */

        /* get the PDF data for the file */

        pdfData = [NSData dataWithContentsOfURL: fURL];
        if (pdfData == nil)
        {
            printError("Not a valid PDF: '%s'.\n", file);
            return NO;
        }

        /* get an image representation of the PDF data */

        pdfImageRep = [NSPDFImageRep imageRepWithData: pdfData];
        if (pdfData == nil)
        {
            printError("Cannot convert PDF to image: '%s'.\n",
                       file);
            return NO;
        }

        /* get the page count and make sure we have at least 1 page */

        pdfPages = [pdfImageRep pageCount];
        if (pdfPages < 1)
        {
            printError("PDF has no pages: '%s'.\n", file);
            return NO;
        }

        /* ocr each page */

        for(i = 0 ; i < pdfPages ; i++) {

            [pdfImageRep setCurrentPage: i];

            /* create an image for the current page */

            /*
                TODO, get the orientation:
                https://stackoverflow.com/questions/6321772

                TODO: create a stacked, searchable PDF:
                https://teabyte.dev/blog/2021-03-29-from-uiimage-to-searchable-pdf-part-3
            */

            image =
                [NSImage imageWithSize: pdfImageRep.size
                               flipped: NO
                        drawingHandler: ^BOOL(NSRect dstRect)
                        {
                            [pdfImageRep drawInRect: dstRect];
                            return YES;
                        }];
            if (image == nil)
            {
                printError("Could not make an image for p.%ld of '%s'.\n",
                           i, file);
                continue;
            }

            /*
                convert the NSImage we have to a CGImage for
                VisionRequestHandler:

                https://stackoverflow.com/questions/2548059/
            */

            imageRect =
                NSMakeRect(0, 0, image.size.width, image.size.height);
            cgImage = [image CGImageForProposedRect: &imageRect
                                            context: NULL
                                              hints: nil];

#ifdef VOCR_IMG2TXT
            if (ocrImage(cgImage, pdfText, opts) != YES)
#else
            if (ocrImage(cgImage, opts) != YES)
#endif /* VOCR_IMG2TXT */
            {
                continue;
            }

            printInfo("OCR'ed p. %ld of '%s'.\n", i+1, file);

#ifdef VOCR_IMG2TXT
            [text appendFormat: @"%@\n", pdfText];
#endif /* VOCR_IMG2TXT */

            if (opts != NULL && opts->addPageBreak)
            {
#ifdef VOCR_IMG2TXT
                [text appendFormat: @"\f"];
#else
                fprintf(stdout, "\f");
#endif /* VOCR_IMG2TXT */
            }
        }

        return YES;
    }

    /* ocr an image */

    if ([workspace type: type conformsToType: gUTIIMG])
    {
        image = [[NSImage alloc] initWithContentsOfURL: fURL];
        if (image == nil)
        {
            printError("Not an valid image: '%s'.\n", file);
            return NO;
        }

        /*
            convert the NSImage we have to a CGImage for
            VisionRequestHandler:

            https://stackoverflow.com/questions/2548059/
        */

        imageRect =
            NSMakeRect(0, 0, image.size.width, image.size.height);
        cgImage = [image CGImageForProposedRect: &imageRect
                                        context: NULL
                                          hints: nil];

#ifdef VOCR_IMG2TXT
        return ocrImage(cgImage, text, opts);
#else
        return ocrImage(cgImage, opts);
#endif /* VOCR_IMG2TXT */
    }

    /* unsupported file type */

    printError("'%s' not a supported image or a PDF.\n", file);

    return NO;
}

#ifdef VOCR_DEBUG
static void printSupportedLangs(void)
{
    NSArray<NSString *> *langs;
    NSUInteger i = 0, numLangs = 0;

    /* fast, v1 */

    langs = [VNRecognizeTextRequest
        supportedRecognitionLanguagesForTextRecognitionLevel:
            VNRequestTextRecognitionLevelFast
                                                    revision:
            VNRecognizeTextRequestRevision1
                                                       error: nil];
    if (langs != nil)
    {
        fprintf(stderr,"Fast, v1: ");
        numLangs = [langs count];
        if (numLangs > 0)
        {
            for (i = 0; i < numLangs; i++)
            {
                fprintf(stderr,
                        "'%s' ",
                        [[langs objectAtIndex: i]
                            cStringUsingEncoding: NSUTF8StringEncoding]);
            }
        }
        else
        {
            fprintf(stderr,"None");
        }
        fprintf(stderr, "\n");
    }

    /* fast, v2 */

    if (@available(macos 11, *))
    {
        langs = [VNRecognizeTextRequest
            supportedRecognitionLanguagesForTextRecognitionLevel:
                VNRequestTextRecognitionLevelFast
                                                        revision:
                VNRecognizeTextRequestRevision2
                                                           error: nil];
        if (langs != nil)
        {
            fprintf(stderr,"Fast, v2: ");
            numLangs = [langs count];
            if (numLangs > 0)
            {
                for (i = 0; i < numLangs; i++)
                {
                    fprintf(stderr,
                            "'%s' ",
                            [[langs objectAtIndex: i]
                                cStringUsingEncoding: NSUTF8StringEncoding]);
                }
            }
            else
            {
                fprintf(stderr,"None");
            }
            fprintf(stderr, "\n");
        }
    }

    /* accurate, v1 */

    langs = [VNRecognizeTextRequest
        supportedRecognitionLanguagesForTextRecognitionLevel:
            VNRequestTextRecognitionLevelAccurate
                                                    revision:
            VNRecognizeTextRequestRevision1
                                                       error: nil];
    if (langs != nil)
    {
        fprintf(stderr,"Accurate, v1: ");
        numLangs = [langs count];
        if (numLangs > 0)
        {
            for (i = 0; i < numLangs; i++)
            {
                fprintf(stderr,
                        "'%s' ",
                        [[langs objectAtIndex: i]
                            cStringUsingEncoding: NSUTF8StringEncoding]);
            }
        }
        else
        {
            fprintf(stderr,"None");
        }
        fprintf(stderr, "\n");
    }

    /* accurate, v2 */

    if (@available(macos 11, *))
    {
        langs = [VNRecognizeTextRequest
            supportedRecognitionLanguagesForTextRecognitionLevel:
                VNRequestTextRecognitionLevelAccurate
                                                        revision:
                VNRecognizeTextRequestRevision2
                                                           error: nil];
        if (langs != nil)
        {
            fprintf(stderr,"Accurate, v2: ");
            numLangs = [langs count];
            if (numLangs > 0)
            {
                for (i = 0; i < numLangs; i++)
                {
                    fprintf(stderr,
                            "'%s' ",
                            [[langs objectAtIndex: i]
                                cStringUsingEncoding: NSUTF8StringEncoding]);
                }
            }
            else
            {
                fprintf(stderr,"None");
            }
            fprintf(stderr, "\n");
        }
    }
}
#endif /* VOCR_DEBUG */

/* main */

int main(int argc, char * const argv[])
{
    int i = 0, err = 0, ch = 0;
    BOOL optHelp = NO;
#ifdef VOCR_IMG2TXT
    NSMutableString *text = nil;
#endif /* VOCR_IMG2TXT */
    ocrOpts_t options;

    /*
        create an autorelease pool:
        https://developer.apple.com/documentation/foundation/nsautoreleasepool
    */

@autoreleasepool
    {

    /*
        check for MacOSX 10.15 or newer, because we need
        VNRecognizeTextRequest, which was first available
        on MacOSX 10.15:

        https://developer.apple.com/documentation/vision/vnrecognizetextrequest
     */

    if (@available(macOS 10.15, *))
    {
    }
    else
    {
        printError("%s requires MacOSX 10.15 or newer\n", gPgmName);
        return 1;
    }

    if (argc <= 1)
    {
        printUsage();
        return 1;
    }

    options.addPageBreak = NO;
    options.indent = YES;
    options.indentWithTabs = NO;
    options.lang = gLangEnglish;

    while ((ch = getopt(argc, argv, gPgmOpts)) != -1)
    {
        switch(ch)
        {
            case gPgmOptHelp:
                optHelp = YES;
                break;
            case gPgmOptPageBreak:
                options.addPageBreak = YES;
                break;
            case gPgmOptIndent:
                if (strcmp(optarg, gPgmIndentNo) == 0)
                {
                    options.indent = NO;
                    options.indentWithTabs = NO;
                }
                else if (strcmp(optarg, gPgmIndentTab) == 0)
                {
                    options.indent = YES;
                    options.indentWithTabs = YES;
                }
                else
                {
                    printError("Unsupported indent type: '%s'\n", optarg);
                    err++;
                }
                break;
            case gPgmOptLang:
                if (@available(macos 11, *))
                {
                    if (strcmp(optarg, gPgmLangGerman) == 0)
                    {
                        options.lang = gLangGerman;
                    }
                    else if (strcmp(optarg, gPgmLangEnglish) == 0)
                    {
                        options.lang = gLangEnglish;
                    }
                    else if (strcmp(optarg, gPgmLangFrench) == 0)
                    {
                        options.lang = gLangFrench;
                    }
                    else if (strcmp(optarg, gPgmLangItalian) == 0)
                    {
                        options.lang = gLangItalian;
                    }
                    else if (strcmp(optarg, gPgmLangPortuguese) == 0)
                    {
                        options.lang = gLangPortuguese;
                    }
                    else if (strcmp(optarg, gPgmLangSpanish) == 0)
                    {
                        options.lang = gLangSpanish;
                    }
                    else if (strcmp(optarg, gPgmLangChineseSimplified) == 0)
                    {
                        options.lang = gLangChineseSimplified;
                    }
                    else if (strcmp(optarg, gPgmLangChineseTraditional) == 0)
                    {
                        options.lang = gLangChineseTraditional;
                    }
                    else
                    {
                        printError("Unsupported language: '%s'\n", optarg);
                        err++;
                    }
                }
                else
                {
                    /* before 11.x, only english is supported */

                    if (strcmp(optarg, gPgmLangEnglish) == 0)
                    {
                        options.lang = gLangEnglish;
                    }
                    else
                    {
                        printError("Unsupported language: '%s'\n", optarg);
                        err++;
                    }
                }
                break;
            case gPgmOptVerbose:
                gQuiet = NO;
                break;
            default:
                printError("Unknown option: '%c'\n", ch);
                err++;
                break;
        }

        if (optHelp || err > 0)
        {
            printUsage();
            break;
        }
    }

    if (err > 0)
    {
        return err;
    }

    if (optHelp)
    {
#ifdef VOCR_DEBUG
        printSupportedLangs();
#endif /* VOCR_DEBUG */
        return 0;
    }

    argc -= optind;
    argv += optind;

    if (argc <= 0)
    {
        printError("No files specified.\n");
        printUsage();
        return 1;
    }

#ifdef VOCR_IMG2TXT
    text = [[NSMutableString alloc] initWithCapacity: gBufSize];
    if (text == nil)
    {
        printError("Cannot allocate buffer for text.\n");
        return 1;
    }
#endif /* VOCR_IMG2TXT */

    for (i = 0; i < argc; i++)
    {
        if (argv[i] == NULL)
        {
            err++;
            printError("Filename is NULL!\n");
            continue;
        }

#ifdef VOCR_IMG2TXT
        if (ocrFile(argv[i], text, &options) != YES)
#else
        if (ocrFile(argv[i], &options) != YES)
#endif /* VOCR_IMG2TXT */
        {
            err++;
            printError("Could not OCR '%s'.\n", argv[i]);
            continue;
        }

#ifdef VOCR_IMG2TXT
        fprintf(stdout,
                "%s\n",
                [text cStringUsingEncoding: NSUTF8StringEncoding]);
#endif /* VOCR_IMG2TXT */
    }

    return err;

    } /* @autoreleasepool */
}

