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
    v. 0.3.1 (04/24/2022) - move printSupportedLangs to separate file
    v. 0.4.0 (07/10/2022) - switch to PDFKit
    v. 0.4.1 (10/28/2022) - updates for Monterey (MacOSX 12.x)
    v. 0.4.2 (06/17/2025) - updates for Sonoma (MacOSX 14.x),
                            integrate lslangs (-L option), and -V to
                            print out the version

    Copyright (c) 2022, 2025 Sriranga R. Veeraraghavan <ranga@calalum.org>

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
#import <PDFKit/PDFKit.h>

/*
    use UTT, if available
    see: https://stackoverflow.com/questions/70512722
*/

#ifdef HAVE_UTT
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

#import <stdio.h>
#import <stdarg.h>
#import <unistd.h>
#import <string.h>
#import <math.h>

/* globals */

static NSString   *gIndentStr = @"    ";
static const char *gPgmName   = "vocr";
static const char *gStrNone   = "none";

#ifdef VOCR_IMG2TXT
static const NSUInteger gBufSize = 1024;
#endif /* VOCR_IMG2TXT */

#ifndef HAVE_UTT
static NSString   *gUTIPDF    = @"com.adobe.pdf";
static NSString   *gUTIIMG    = @"public.image";
#endif /* HAVE_UTT */

#ifdef vocr_version
static NSString   *gPgmVers   = vocr_version;
#else
static NSString   *gPgmVers   = @"0.1.0;
#endif /* vocr_version */

/*
    command line options:
        -a        - set the ocr [a]lgorithm
                    'fast'     - uses the fast algorithm
                    'accurate' - uses the accurate algorithm
        -f        - force ocr
        -h        - print usage / [h]elp
        -i [mode] - set the [i]ndent mode:
                    'no'  - disables indenting
                    'tab' - indents with tabs (default is to use 4 spaces)
        -l - specify the [l]anguage to use for recognition
        -L - list languages available for recognition
        -p - add a page break / [l]ine feed between pages
        -v - be [v]erbose
        -V - print version
*/

enum
{
    gPgmOptAlgorithm = 'a',
    gPgmOptForce     = 'f',
    gPgmOptHelp      = 'h',
    gPgmOptIndent    = 'i',
    gPgmOptLang      = 'l',
    gPgmOptPageBreak = 'p',
    gPgmOptVerbose   = 'v',
    gPgmOptListLangs = 'L',
    gPgmOptVersion   = 'V',
};

/* enumeration of supported languages */

typedef enum
{
    gLangGerman     = 'd', /* de-DE */
    gLangEnglish    = 'e', /* en-US */
    gLangFrench     = 'f', /* fr-FR */
    gLangItalian    = 'i', /* it-IT */
    gLangJapanese   = 'j', /* ja-JP */
    gLangKorean     = 'k', /* ko-KR */
    gLangPortuguese = 'p', /* pt-BR */
    gLangRussian    = 'r', /* ru-RU */
    gLangSpanish    = 's', /* es-ES */
    gLangThai       = 't', /* th-TH */
    gLangUkrainian  = 'u', /* uk-UA */
    gLangVietnamese = 'v', /* vi-VT */
    gLangCantonese  = 'y', /* yue-Hans and yue-Hant */
    gLangChinese    = 'z', /* zh-Hans and zh-Hant */
} supportedLangs_t;

/* enumeration of supported ocr algorithms */

typedef enum
{
    gAlgorithmAccurate,
    gAlgorithmFast,
    gAlgorithmAll,
} supportedAlgorithms_t;

static const char *gPgmOpts      = "fhpvLVa:i:l:";
static const char *gPgmAlgorithmAccurate = "accurate";
static const char *gPgmAlgorithmFast     = "fast";
static const char *gPgmIndentNo  = "no";
static const char *gPgmIndentTab = "tab";
static BOOL       gQuiet         = YES;

static const char *gPgmLangGerman     = "de";
static const char *gPgmLangEnglish    = "en";
static const char *gPgmLangFrench     = "fr";
static const char *gPgmLangItalian    = "it";
static const char *gPgmLangPortuguese = "pt";
static const char *gPgmLangSpanish    = "es";
static const char *gPgmLangChinese    = "zh";
static const char *gPgmLangCantonese  = "yu";
static const char *gPgmLangKorean     = "kr";
static const char *gPgmLangJapanese   = "jp";
static const char *gPgmLangRussian    = "ru";
static const char *gPgmLangUkrainian  = "ua";
static const char *gPgmLangThai       = "th";
static const char *gPgmLangVietnamese = "vt";

/* ocr options */

typedef struct
{
    BOOL addPageBreak;
    BOOL indent;
    BOOL indentWithTabs;
    BOOL forceOCR;
    supportedAlgorithms_t algorithm;
    supportedLangs_t lang;
} ocrOpts_t;

/* prototypes */

static void printUsage(void);
static void printVersion(void);

#ifdef VOCR_IMG2TXT

static BOOL ocrFile(const char *file,
                    NSMutableString *text,
                    ocrOpts_t *opts);

static BOOL ocrImage(CGImageRef cgImage,
                     NSMutableString *text,
                     ocrOpts_t *opts);
#else

static BOOL ocrFile(const char *file,
                    ocrOpts_t *opts);

static BOOL ocrImage(CGImageRef cgImage,
                     ocrOpts_t *opts);

#endif /* VOCR_IMG2TXT */

static void listSupportedLangs(supportedAlgorithms_t algorithm);

/* macros */

/*
    printError - print an error message
    printInfo  - print an informational message

    based on: https://stackoverflow.com/a/43707810
*/

#define printError(...) fprintf(stderr, "Error: %s", \
                                 [[NSString stringWithFormat: __VA_ARGS__] \
                                  cStringUsingEncoding: NSUTF8StringEncoding])

#define printInfo(...) if (gQuiet == NO) \
                       { \
                          fprintf(stdout, "Info : %s", \
                                 [[NSString stringWithFormat: __VA_ARGS__] \
                                  cStringUsingEncoding: NSUTF8StringEncoding]); \
                        }

/* private functions */

/* printUsage - print the usage message */

static void printUsage(void)
{
    fprintf(stderr,
            "Usage: %s [-%c] [-%c [%s|%s]] [-%c] [-%c] [-%c [%s|%s]] [-%c [lang]] [files]\n",
            gPgmName,
            gPgmOptVerbose,
            gPgmOptAlgorithm,
            gPgmAlgorithmAccurate,
            gPgmAlgorithmFast,
            gPgmOptForce,
            gPgmOptPageBreak,
            gPgmOptIndent,
            gPgmIndentNo,
            gPgmIndentTab,
            gPgmOptLang);

    fprintf(stderr,
            "       %s [-%c] [-%c [%s|%s]]\n",
            gPgmName,
            gPgmOptListLangs,
            gPgmOptAlgorithm,
            gPgmAlgorithmAccurate,
            gPgmAlgorithmFast);
}

static void printVersion(void)
{
        fprintf(stderr, "%s %s\n",
                gPgmName,
                [gPgmVers cStringUsingEncoding: NSUTF8StringEncoding]);
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
    NSMutableArray<VNRecognizedTextObservation *> *textPieces;
    unsigned int indentLevel = 0, k = 0;
    double prevStart = 0.0, prevEnd = 0.0;
    double curStart = 0.0, curEnd = 0.0;
    BOOL indent = YES, fast = NO, langCorrect = YES;
    NSString *indentStr = gIndentStr;
    NSArray<NSString *> *langs = nil;
#ifdef VOCR_IMG2TXT
    NSMutableString *ocrText = nil;
#endif /* VOCR_IMG2TXT */

#ifdef VOCR_IMG2TXT
    if (text == nil)
    {
        printError(@"Text buffer is NULL!\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    if (opts != NULL)
    {

        /* is fast mode requested? */

        if (opts->algorithm == gAlgorithmFast)
        {
            fast = YES;
        }

        /* desired indent */

        indent = opts->indent;
        if (opts->indentWithTabs)
        {
            indentStr = @"\t";
        }

        /*
            on BigSur (10.16) and newer, try to set the
            recognition language
        */

        if (@available(macos 10.16, *))
        {
            switch(opts->lang)
            {
                case gLangGerman:

                    langs = [NSArray arrayWithObjects: @"de-DE", nil];
                    break;

                case gLangEnglish:

                    langs = nil;
                    break;

                case gLangFrench:

                    langs = [NSArray arrayWithObjects: @"fr-FR", nil];
                    break;

                case gLangItalian:

                    langs = [NSArray arrayWithObjects: @"it-IT", nil];
                    break;

                case gLangPortuguese:

                    langs = [NSArray arrayWithObjects: @"pt-BR", nil];
                    break;

                case gLangSpanish:

                    langs = [NSArray arrayWithObjects: @"es-ES", nil];
                    break;

                /*
                    fast mode not supported for Korean, Japanese, Russian,
                    Ukrainian, Thai, Vietnamese, Cantonese, or Chinese
                */

                case gLangKorean:

                    langs = [NSArray arrayWithObjects: @"ko-KR", nil];
                    fast = NO;
                    break;

                case gLangJapanese:

                    langs = [NSArray arrayWithObjects: @"ja-JP", nil];
                    fast = NO;
                    break;

                case gLangRussian:

                    langs = [NSArray arrayWithObjects: @"ru-RU", nil];
                    fast = NO;
                    break;

                case gLangUkrainian:

                    langs = [NSArray arrayWithObjects: @"uk-UA", nil];
                    fast = NO;
                    break;

                case gLangThai:

                    langs = [NSArray arrayWithObjects: @"th-TH", nil];
                    fast = NO;
                    break;

                case gLangVietnamese:

                    langs = [NSArray arrayWithObjects: @"vi-VT", nil];
                    fast = NO;
                    break;

                case gLangCantonese:

                    langs = [NSArray arrayWithObjects: @"yue-Hans",
                                                       @"yue-Hant",
                                                       @"en-US",
                                                       nil];

                    /*
                        disable language correction and fast mode
                        for Chinese/Cantonese, see:
                        https://developer.apple.com/documentation/vision/recognizing_text_in_images
                    */

                    langCorrect = NO;
                    fast = NO;
                    break;

                case gLangChinese:

                    langs = [NSArray arrayWithObjects: @"zh-Hans",
                                                       @"zh-Hant",
                                                       @"en-US",
                                                       nil];

                    /*
                        disable language correction, fast mode
                        for Chinese/Cantonese, see:
                        https://developer.apple.com/documentation/vision/recognizing_text_in_images
                    */

                    langCorrect = NO;
                    fast = NO;
                    break;

                default:

                    langs = nil;
                    break;

            }
        }
    }

#ifdef VOCR_IMG2TXT
    ocrText = [[NSMutableString alloc] initWithCapacity: gBufSize];
    if (ocrText == nil)
    {
        printError(@"Cannot allocate mutable string.\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    textPieces = [NSMutableArray array];
    if (textPieces == nil)
    {
        printError(@"Cannot allocate mutable array.\n");
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
        printError(@"Could not create OCR request handler.\n");
        return NO;
    }

    request = [[VNRecognizeTextRequest alloc] init];
    if (request == nil)
    {
        printError(@"Could not create OCR request for.\n");
        return NO;
    }

    /*
        enable fast/accurate recognition and language correction
        https://developer.apple.com/documentation/vision/vnrequesttextrecognitionlevel?language=objc
        https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3166773-useslanguagecorrection?language=objc
    */

    if (fast)
    {
        [request setRecognitionLevel:
            VNRequestTextRecognitionLevelFast];
    }
    else
    {
        [request setRecognitionLevel:
            VNRequestTextRecognitionLevelAccurate];
    }

    [request setUsesLanguageCorrection: langCorrect];

    /*
        use the version 3 algorithm on MacOSX 13+ (Ventura and newer)
        and the version 2 algorithm on MacOSX 11 and 12 (BigSur and
        Monterey), which support multiple languages.  If an alternate
        language is requested set that as well.  See:

        https://developer.apple.com/documentation/vision/vnrecognizetextrequestrevision2?language=objc
        https://stackoverflow.com/questions/63813709
    */

    if (@available(macos 13, *))
    {
        [request setRevision: VNRecognizeTextRequestRevision3];
        if (langs != nil)
        {
            [request setRecognitionLanguages: langs];
        }
    }
    else if (@available(macos 11, *))
    {
        [request setRevision: VNRecognizeTextRequestRevision2];
        if (langs != nil)
        {
            [request setRecognitionLanguages: langs];
        }
    }
    else
    {
        [request setRevision: VNRecognizeTextRequestRevision1];
    }

    if ([requestHandler performRequests: @[request]
                                  error: NULL] == NO)
    {
        printError(@"OCR failed.\n");
        return NO;
    }

    results = [request results];
    if (results == nil)
    {
        printInfo(@"No text found.\n");
        return NO;
    }

    numResults = [results count];
    if (numResults == 0)
    {
        printInfo(@"No text found.\n");
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
    NSString *type = nil, *pageText = nil;
    NSError *error = nil;
    NSImage *image = nil;
    NSRect imageRect;
    CGImageRef cgImage;
    NSData *pdfData = nil;
    NSPDFImageRep *pdfImageRep = nil;
    PDFDocument *pdfDoc = nil;
    PDFPage *pdfPage = nil;
    NSUInteger pdfPages = 0, i = 0;
#ifdef VOCR_IMG2TXT
    NSMutableString *pdfText = nil;
#endif /* VOCR_IMG2TXT */
#ifdef HAVE_UTT
     UTType *utt = nil;
#endif

    if (file == NULL || file[0] == '\0')
    {
        printError(@"Filename is NULL!\n");
        return NO;
    }

#ifdef VOCR_IMG2TXT
    if (text == nil)
    {
        printError(@"Text buffer is NULL!\n");
        return NO;
    }
#endif /* VOCR_IMG2TXT */

    fm = [NSFileManager defaultManager];
    if (fm == nil)
    {
        printError(@"Cannot get NSFileManager!\n");
        return NO;
    }

    workspace = [NSWorkspace sharedWorkspace];
    if (workspace == nil)
    {
        printError(@"Cannot get NSWorkspace!\n");
        return NO;
    }

    path = [fm stringWithFileSystemRepresentation: file
                                           length: strlen(file)];
    if (path == nil)
    {
        printError(@"Cannot get full path for '%s'.\n", file);
        return NO;
    }

    fURL = [NSURL fileURLWithPath: path];
    if (fURL == nil)
    {
        printError(@"Cannot get create URL for '%s'.\n", file);
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
        printError(@"Cannot determine file type for '%s'.\n", file);
        return NO;
    }

    /* ocr a PDF */
#ifdef HAVE_UTT
    utt = [UTType typeWithIdentifier: type];
    if ([utt conformsToType: UTTypePDF])
#else
    if ([workspace type: type conformsToType: gUTIPDF])
#endif
    {

#ifdef VOCR_IMG2TXT
        pdfText = [[NSMutableString alloc] initWithCapacity: gBufSize];
        if (pdfText == nil)
        {
            printError(@"Cannot allocate buffer for PDF text.\n");
            return NO;
        }
#endif /* VOCR_IMG2TXT */

        /*
            convert each page of a PDF to an image and then OCR it,
            based on:
            https://stackoverflow.com/questions/23643961
        */

        /* get the PDF data for the file */

        pdfDoc = [[PDFDocument alloc] initWithURL: fURL];
        if (pdfDoc == nil)
        {
            printError(@"Not a valid PDF: '%s'.\n", file);
            return NO;
        }

        /* get the page count and make sure we have at least 1 page */

        pdfPages = [pdfDoc pageCount];
        if (pdfPages < 1)
        {
            printError(@"PDF has no pages: '%s'.\n", file);
            return NO;
        }

        /* ocr each page */

        for(i = 0 ; i < pdfPages ; i++)
        {

            pdfPage = [pdfDoc pageAtIndex: i];
            if (pdfPage == NULL)
            {
                printError(@"Could not get p.%ld of '%s'.\n",
                           i+1, file);
                continue;
            }

            /* if ocr isn't being forced, see if we can just use
               the existing text representation for this page */

            if (opts->forceOCR == NO)
            {
                pageText = [[pdfPage string] stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (pageText != nil && [pageText length] > 0)
                {
                    fprintf(stdout,
                            "%s\n",
                            [pageText cStringUsingEncoding: NSUTF8StringEncoding]);
                    continue;
                }
            }

            pdfData = [pdfPage dataRepresentation];
            if (pdfData == NULL)
            {
                printError(@"Could not get contents of p.%ld of '%s'.\n",
                           i+1, file);
            }

            pdfImageRep = [NSPDFImageRep imageRepWithData: pdfData];
            if (pdfData == nil)
            {
                printError(@"Cannot convert PDF to image: '%s'.\n",
                           file);
                return NO;
            }

            [pdfImageRep setCurrentPage: 0];

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
                printError(@"Could not make an image for p.%ld of '%s'.\n",
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

            printInfo(@"OCR'ed p. %ld of '%s'.\n", i+1, file);

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

#ifdef HAVE_UTT
    utt = [UTType typeWithIdentifier: type];
    if ([utt conformsToType: UTTypeImage])
#else
    if ([workspace type: type conformsToType: gUTIIMG])
#endif
    {
        image = [[NSImage alloc] initWithContentsOfURL: fURL];
        if (image == nil)
        {
            printError(@"Not an valid image: '%s'.\n", file);
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

    printError(@"'%s' not a supported image or a PDF.\n", file);

    return NO;
}

/*
    listSupportedLangs - list the languages supported by
                         VNRecognizeTextRequest

    see: https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3152642-recognitionlanguages?language=objc
*/

static void listSupportedLangs(supportedAlgorithms_t algorithm)
{
    NSArray<NSString *> *langs;
    NSUInteger i = 0, numLangs = 0;
#if (MAC_OS_X_VERSION_MIN_REQUIRED >= 120000)
    VNRecognizeTextRequest *vnr = nil;
#endif

    if (algorithm == gAlgorithmAll ||
        algorithm == gAlgorithmFast)
    {

        /* fast, v1 */

#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
        langs = [VNRecognizeTextRequest
            supportedRecognitionLanguagesForTextRecognitionLevel:
                VNRequestTextRecognitionLevelFast
                                                        revision:
                VNRecognizeTextRequestRevision1
                                                           error: nil];
#else
        vnr = [[VNRecognizeTextRequest alloc] init];
        [vnr setRecognitionLevel: VNRequestTextRecognitionLevelFast];
        [vnr setRevision: VNRecognizeTextRequestRevision1];
        langs = [vnr
                 supportedRecognitionLanguagesAndReturnError: nil];
#endif

        if (langs != nil)
        {
            fprintf(stdout, "%-8s v1: ", gPgmAlgorithmFast);
            numLangs = [langs count];
            if (numLangs > 0)
            {
                for (i = 0; i < numLangs; i++)
                {
                    fprintf(stdout,
                            "'%s' ",
                            [[langs objectAtIndex: i]
                                cStringUsingEncoding: NSUTF8StringEncoding]);
                }
            }
            else
            {
                fprintf(stdout, "%s", gStrNone);
            }
            fprintf(stdout, "\n");
        }

        /* fast, v2 */

        if (@available(macos 11, *))
        {
#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
            langs = [VNRecognizeTextRequest
                supportedRecognitionLanguagesForTextRecognitionLevel:
                    VNRequestTextRecognitionLevelFast
                                                            revision:
                    VNRecognizeTextRequestRevision2
                                                               error: nil];
#else
            [vnr setRevision: VNRecognizeTextRequestRevision2];
            langs = [vnr
                     supportedRecognitionLanguagesAndReturnError: nil];
#endif
            if (langs != nil)
            {
            fprintf(stdout, "%-8s v2: ", gPgmAlgorithmFast);
                numLangs = [langs count];
                if (numLangs > 0)
                {
                    for (i = 0; i < numLangs; i++)
                    {
                        fprintf(stdout,
                                "'%s' ",
                                [[langs objectAtIndex: i]
                                    cStringUsingEncoding: NSUTF8StringEncoding]);
                    }
                }
                else
                {
                    fprintf(stdout, "%s", gStrNone);
                }
                fprintf(stdout, "\n");
            }
        }

        /* fast, v3 */

        if (@available(macos 13, *))
        {
            [vnr setRevision: VNRecognizeTextRequestRevision3];
            langs = [vnr
                     supportedRecognitionLanguagesAndReturnError: nil];
            if (langs != nil)
            {
            fprintf(stdout, "%-8s v3: ", gPgmAlgorithmFast);
                numLangs = [langs count];
                if (numLangs > 0)
                {
                    for (i = 0; i < numLangs; i++)
                    {
                        fprintf(stdout,
                                "'%s' ",
                                [[langs objectAtIndex: i]
                                    cStringUsingEncoding: NSUTF8StringEncoding]);
                    }
                }
                else
                {
                    fprintf(stdout, "%s", gStrNone);
                }
                fprintf(stdout, "\n");
            }
        }

    }

    if (algorithm == gAlgorithmAll ||
        algorithm == gAlgorithmAccurate)
    {
        /* accurate, v1 */

#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
        langs = [VNRecognizeTextRequest
            supportedRecognitionLanguagesForTextRecognitionLevel:
                VNRequestTextRecognitionLevelAccurate
                                                        revision:
                VNRecognizeTextRequestRevision1
                                                           error: nil];
#else
        if (vnr == nil)
        {
            vnr = [[VNRecognizeTextRequest alloc] init];
        }
        [vnr setRecognitionLevel: VNRequestTextRecognitionLevelAccurate];
        [vnr setRevision: VNRecognizeTextRequestRevision1];
        langs = [vnr
                 supportedRecognitionLanguagesAndReturnError: nil];
#endif

        if (langs != nil)
        {
            fprintf(stdout, "%-8s v1: ", gPgmAlgorithmAccurate);
            numLangs = [langs count];
            if (numLangs > 0)
            {
                for (i = 0; i < numLangs; i++)
                {
                    fprintf(stdout,
                            "'%s' ",
                            [[langs objectAtIndex: i]
                                cStringUsingEncoding: NSUTF8StringEncoding]);
                }
            }
            else
            {
                fprintf(stdout, "%s", gStrNone);
            }
            fprintf(stdout, "\n");
        }

        /* accurate, v2 */

        if (@available(macos 11, *))
        {
#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
            langs = [VNRecognizeTextRequest
                supportedRecognitionLanguagesForTextRecognitionLevel:
                    VNRequestTextRecognitionLevelAccurate
                                                            revision:
                    VNRecognizeTextRequestRevision2
                                                               error: nil];
#else
            [vnr setRevision: VNRecognizeTextRequestRevision2];
            langs = [vnr
                     supportedRecognitionLanguagesAndReturnError: nil];
#endif
            if (langs != nil)
            {
                fprintf(stdout, "%-8s v2: ", gPgmAlgorithmAccurate);
                numLangs = [langs count];
                if (numLangs > 0)
                {
                    for (i = 0; i < numLangs; i++)
                    {
                        fprintf(stdout,
                                "'%s' ",
                                [[langs objectAtIndex: i]
                                    cStringUsingEncoding: NSUTF8StringEncoding]);
                    }
                }
                else
                {
                    fprintf(stdout, "%s", gStrNone);
                }
                fprintf(stdout, "\n");
            }
        }

        /* accurate, v3 */

        if (@available(macos 13, *))
        {
            [vnr setRevision: VNRecognizeTextRequestRevision3];
            langs = [vnr
                     supportedRecognitionLanguagesAndReturnError: nil];

            if (langs != nil)
            {
                fprintf(stdout, "%-8s v3: ", gPgmAlgorithmAccurate);
                numLangs = [langs count];
                if (numLangs > 0)
                {
                    for (i = 0; i < numLangs; i++)
                    {
                        fprintf(stdout,
                                "'%s' ",
                                [[langs objectAtIndex: i]
                                    cStringUsingEncoding: NSUTF8StringEncoding]);
                    }
                }
                else
                {
                    fprintf(stdout, "%s", gStrNone);
                }
                fprintf(stdout, "\n");
            }
        }
    }
}

/* main */

int main(int argc, char * const argv[])
{
    int i = 0, err = 0, ch = 0;
    BOOL optHelp = NO;
    BOOL optListLangs = NO;
    BOOL optVersion = NO;
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
        printError(@"%s requires MacOSX 10.15 or newer\n", gPgmName);
        return 1;
    }

    if (argc <= 1)
    {
        printUsage();
        return 1;
    }

    options.algorithm = gAlgorithmAll;
    options.addPageBreak = NO;
    options.indent = YES;
    options.indentWithTabs = NO;
    options.lang = gLangEnglish;
    options.forceOCR = NO;

    while ((ch = getopt(argc, argv, gPgmOpts)) != -1)
    {
        switch(ch)
        {
            case gPgmOptHelp:
                optHelp = YES;
                break;
            case gPgmOptVersion:
                optVersion = YES;
                break;
            case gPgmOptAlgorithm:
                if (strcmp(optarg, gPgmAlgorithmAccurate) == 0)
                {
                    options.algorithm = gAlgorithmAccurate;
                }
                else if (strcmp(optarg, gPgmAlgorithmFast) == 0)
                {
                    options.algorithm = gAlgorithmFast;
                }
                else
                {
                    printError(@"Unsupported algorithm: '%s'\n", optarg);
                    err++;
                }
                break;
            case gPgmOptForce:
                options.forceOCR = YES;
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
                    printError(@"Unsupported indent type: '%s'\n", optarg);
                    err++;
                }
                break;
            case gPgmOptListLangs:
                optListLangs = YES;
                break;
            case gPgmOptLang:
                if (@available(macos 13, *))
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
                    else if (strcmp(optarg, gPgmLangChinese) == 0)
                    {
                        options.lang = gLangChinese;
                    }
                    else if (strcmp(optarg, gPgmLangCantonese) == 0)
                    {
                        options.lang = gLangCantonese;
                    }
                    else if (strcmp(optarg, gPgmLangKorean) == 0)
                    {
                        options.lang = gLangKorean;
                    }
                    else if (strcmp(optarg, gPgmLangJapanese) == 0)
                    {
                        options.lang = gLangJapanese;
                    }
                    else if (strcmp(optarg, gPgmLangRussian) == 0)
                    {
                        options.lang = gLangRussian;
                    }
                    else if (strcmp(optarg, gPgmLangUkrainian) == 0)
                    {
                        options.lang = gLangUkrainian;
                    }
                    else if (strcmp(optarg, gPgmLangThai) == 0)
                    {
                        options.lang = gLangThai;
                    }
                    else if (strcmp(optarg, gPgmLangVietnamese) == 0)
                    {
                        options.lang = gLangVietnamese;
                    }
                    else
                    {
                        printError(@"Unsupported language: '%s'\n", optarg);
                        err++;
                    }
                }
                else if (@available(macos 11, *))
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
                    else if (strcmp(optarg, gPgmLangChinese) == 0)
                    {
                        options.lang = gLangChinese;
                    }
                    else
                    {
                        printError(@"Unsupported language: '%s'\n", optarg);
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
                        printError(@"Unsupported language: '%s'\n", optarg);
                        err++;
                    }
                }
                break;
            case gPgmOptVerbose:
                gQuiet = NO;
                break;
            default:
                if (ch != '?')
                {
                    printError(@"Unknown option: '%c'\n", ch);
                }
                err++;
                break;
        }

        if (optHelp == YES || err > 0)
        {
            printUsage();
            break;
        }

        if (optVersion == YES)
        {
            break;
        }

    }

    if (err > 0)
    {
        return err;
    }

    if (optHelp == YES)
    {
        return 0;
    }

    if (optVersion == YES)
    {
        printVersion();
        return 0;
    }

    if (optListLangs == YES)
    {
        listSupportedLangs(options.algorithm);
        return 0;
    }

    argc -= optind;
    argv += optind;

    if (argc <= 0)
    {
        printError(@"No files specified.\n");
        printUsage();
        return 1;
    }

#ifdef VOCR_IMG2TXT
    text = [[NSMutableString alloc] initWithCapacity: gBufSize];
    if (text == nil)
    {
        printError(@"Cannot allocate buffer for text.\n");
        return 1;
    }
#endif /* VOCR_IMG2TXT */

    for (i = 0; i < argc; i++)
    {
        if (argv[i] == NULL || argv[i][0] == '\0')
        {
            err++;
            printError(@"Filename is NULL!\n");
            continue;
        }

#ifdef VOCR_IMG2TXT
        if (ocrFile(argv[i], text, &options) != YES)
#else
        if (ocrFile(argv[i], &options) != YES)
#endif /* VOCR_IMG2TXT */
        {
            err++;
            printError(@"Could not OCR '%s'.\n", argv[i]);
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
