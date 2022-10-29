/*
    listSupportedLangs.m - list languages supported for text recognition
                           using Apple's Vision framework

    History:

    v. 0.1.0 (04/25/2022) - Initial version
    v. 0.2.0 (10/29/2022) - Updates for MacOSX 12 (Monterey)

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

/* globals */


static void listSupportedLangs(void);

/* private functions */


/*
    listSupportedLangs - list the languages supported by
                         VNRecognizeTextRequest

    see: https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3152642-recognitionlanguages?language=objc
*/

static void listSupportedLangs(void)
{
    NSArray<NSString *> *langs;
    NSUInteger i = 0, numLangs = 0;

    /* fast, v1 */

#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
    langs = [VNRecognizeTextRequest
        supportedRecognitionLanguagesForTextRecognitionLevel:
            VNRequestTextRecognitionLevelFast
                                                    revision:
            VNRecognizeTextRequestRevision1
                                                       error: nil];
#else
    VNRecognizeTextRequest *vnr = [[VNRecognizeTextRequest alloc] init];
    [vnr setRecognitionLevel: VNRequestTextRecognitionLevelFast];
    [vnr setRevision: VNRecognizeTextRequestRevision1];
    langs = [vnr
             supportedRecognitionLanguagesAndReturnError: nil];
#endif

    if (langs != nil)
    {
        fprintf(stderr,"Fast, v1:     ");
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
#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
        langs = [VNRecognizeTextRequest
            supportedRecognitionLanguagesForTextRecognitionLevel:
                VNRequestTextRecognitionLevelFast
                                                        revision:
                VNRecognizeTextRequestRevision2
                                                           error: nil];
#else
    [vnr setRecognitionLevel: VNRequestTextRecognitionLevelFast];
    [vnr setRevision: VNRecognizeTextRequestRevision2];
    langs = [vnr
             supportedRecognitionLanguagesAndReturnError: nil];
#endif
        if (langs != nil)
        {
            fprintf(stderr,"Fast, v2:     ");
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

#if (MAC_OS_X_VERSION_MIN_REQUIRED < 120000)
    langs = [VNRecognizeTextRequest
        supportedRecognitionLanguagesForTextRecognitionLevel:
            VNRequestTextRecognitionLevelAccurate
                                                    revision:
            VNRecognizeTextRequestRevision1
                                                       error: nil];
#else
    [vnr setRecognitionLevel: VNRequestTextRecognitionLevelAccurate];
    [vnr setRevision: VNRecognizeTextRequestRevision1];
    langs = [vnr
             supportedRecognitionLanguagesAndReturnError: nil];
#endif

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

/* main */

int main(void)
{

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
        fprintf(stderr,"ERROR: MacOSX 10.15 or newer is required\n");
        return 1;
    }

    listSupportedLangs();

    return 0;

    } /* @autoreleasepool */
}

